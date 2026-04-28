#!/usr/bin/env python3
"""
System-level golden driver for the DMA engine.

Constructs the full Python model (SystemMemory, SRAM, CSR, RingManager,
DescriptorFetcher, AXI4MasterGolden, SRAMController) from source/, runs through
a scenario CSV, and emits golden artifacts consumed by tb_top.sv.

CSV row format  (op, arg1, arg2, arg3, arg4):
  smem,<word_idx>,<hex_data>                  preload system-memory word (decimal index)
  sram,<word_idx>,<hex_data>                  preload SRAM/BRAM word    (decimal index)
  csr_baseaddr,<hex_addr>                     configure REG_BASEADDR
  csr_ringlen,<decimal_len>                   configure REG_RINGLEN
  desc,<src>,<dst>,<len>,<flags>             enqueue descriptor (SRC/DST/LEN/FLAGS per docs/descriptor_struct.md)
  enable                                      assert CTRL.ENABLE and start the model event loop
  csr_irq_clear,<hex_mask>                    write IRQ_CLEAR (W1C); bit[1] clears the sticky DMA error
                                              and resumes ring fetches (mirrors HW error_clear pulse)

Artifacts written to out_dir/:
  initial_smem.hex   system memory image loaded by model_sys_mem at sim start
  golden_smem.hex    expected system memory after all DMA transfers complete
  initial_sram.hex   SRAM image (for reference / future BRAM backdoor check)
  golden_sram.hex    expected SRAM after all DMA transfers complete
  golden_descs.hex   packed 128-bit descriptors fetched (32 hex digits per line, LSB-first)
  stim.txt           CSR write commands for tb_top.sv  (csr_write <byte_offset> <hex_data>)
  summary.txt        statistics

Descriptor layout (docs/descriptor_struct.md):
  w0=SRC_ADDR, w1=DST_ADDR, w2=LEN, w3=FLAGS; DIR=FLAGS[0]. DIR=1 => system mem -> SRAM.
  The golden builds two 65-bit DM words like rtl/data_mover.sv, then narrows to 41 bits
  like rtl/movement_top.sv for dm_axi and dm_sram separately.
  Event loop drains those paths in DIR order: DIR=1 AXI then SRAM; DIR=0 SRAM then AXI
  so MID FIFO always has data before an AXI/SRAM write leg.

Usage:
  python3 run_golden.py scenarios/example.csv [out_dir]
"""

from __future__ import print_function

import csv
import os
import sys

_here   = os.path.dirname(os.path.abspath(__file__))
_source = os.path.join(os.path.dirname(_here), "source")
if _source not in sys.path:
    sys.path.insert(0, _source)

from fifo_queue       import FIFOQueue
from memory           import SystemMemory
from sram             import SRAM, BRAM_SIZE
from csr              import CSR
from descriptor       import Descriptor
from descriptor_fetcher import DescriptorFetcher
from axi_4_master     import AXI4MasterGolden
from sram_controller  import SRAMController
from ringManager      import RingManager

# -------------------------------------------------------------------------
# Sizing constants (match dma_pkg.sv defaults)
# -------------------------------------------------------------------------
SMEM_WORDS = 1024
FIFO_DEPTH = 64
DM_DEPTH   = 16
MID_DEPTH  = 128     # large enough for both AXI and SRAM to push into MID

# Instruction bit layout  (same as axi_4_master / sram_controller)
_LEN_LSB = 32
_RW_BIT  = 40


def _parse_row(row):
    """Return (op_str, args_list) or None for blank / comment rows."""
    if not row or not row[0]:
        return None
    raw = row[0].strip()
    if not raw or raw.startswith("#") or raw.lower() == "op":
        return None
    return raw.lower(), [c.strip() for c in row[1:]]


def _build_65(addr, len32, rw):
    """65-bit DM word before movement_top narrow: {rw, len32, addr}."""
    return (addr & 0xFFFFFFFF) | ((len32 & 0xFFFFFFFF) << 32) | ((rw & 1) << 64)


def _narrow65_to_41(w65):
    """Match rtl/movement_top.sv: 65 -> 41 using len[7:0] from len32."""
    return (
        (w65 & 0xFFFFFFFF)
        | (((w65 >> 32) & 0xFF) << _LEN_LSB)
        | (((w65 >> 64) & 1) << _RW_BIT)
    )


def _desc_to_instr_pair(desc):
    """
    Build (instr_axi_41, instr_sram_41) from descriptor (docs/descriptor_struct.md),
    matching rtl/data_mover.sv + movement_top narrow.
    """
    src = desc.w0 & 0xFFFFFFFF
    dst = desc.w1 & 0xFFFFFFFF
    len32 = desc.w2 & 0xFFFFFFFF
    dir_bit = desc.w3 & 1
    if dir_bit:
        # System memory -> SRAM
        axi65 = _build_65(src, len32, 0)
        sram65 = _build_65(dst, len32, 1)
    else:
        # SRAM -> system memory
        axi65 = _build_65(dst, len32, 1)
        sram65 = _build_65(src, len32, 0)
    return _narrow65_to_41(axi65), _narrow65_to_41(sram65)


def _drain_axi_dm(axi_golden, instr_axi, max_steps=512):
    """Drain AXI master's DM queue (df_in empty during this phase)."""
    steps = 0
    while not axi_golden.idle:
        if not axi_golden.process_one():
            break
        steps += 1
        if steps > max_steps:
            raise RuntimeError("AXI golden DM path stalled (instr=%#011x)" % instr_axi)


def _drain_sram_dm(sram_ctrl, instr_sram, max_steps=512):
    """Drain SRAM controller's DM queue."""
    steps = 0
    while not sram_ctrl.idle:
        if not sram_ctrl.process_one():
            break
        steps += 1
        if steps > max_steps:
            raise RuntimeError("SRAM controller DM path stalled (instr=%#011x)" % instr_sram)


# -------------------------------------------------------------------------
# Main model runner
# -------------------------------------------------------------------------

def run_scenario(rows, smem_words=SMEM_WORDS, sram_words=BRAM_SIZE):
    """
    Execute a scenario, return
      (stim_lines, initial_smem, final_smem, initial_sram, final_sram, descs_fetched)
    where each mem list is a list of 32-bit ints and descs_fetched is a list of
    packed 128-bit ints.

    CSV ops are processed in order. The HW event loop runs after `enable` and
    again after every `csr_irq_clear` so error_clear writes can resume work
    that the previous loop had to abandon (mirrors RTL gating of fetch_req_valid
    by ring_mgr.int_status_error).
    """
    # --- Build shared model objects ---
    sysmem = SystemMemory(smem_words)
    sram   = SRAM(sram_words)
    csr    = CSR()

    df_in   = FIFOQueue("df_in",   FIFO_DEPTH)
    df_out  = FIFOQueue("df_out",  FIFO_DEPTH)
    dm_axi  = FIFOQueue("dm_axi",  DM_DEPTH)
    dm_sram = FIFOQueue("dm_sram", DM_DEPTH)
    mid     = FIFOQueue("mid",     MID_DEPTH)

    axi_golden = AXI4MasterGolden(sysmem, df_in, df_out, dm_axi, mid)
    sram_ctrl  = SRAMController(sram.mem, dm_sram, mid)
    df         = DescriptorFetcher(df_in, df_out)
    ring       = RingManager(sysmem, csr, df, axi_golden)

    stim_lines = []
    descs_fetched = []
    initial_smem = None
    initial_sram = None

    def _snapshot_initial():
        # Captured the first time the engine is enabled, matching what the TB
        # backdoors into memory at sim start.
        nonlocal initial_smem, initial_sram
        if initial_smem is None:
            initial_smem = list(sysmem.mem)
            initial_sram = list(sram.mem)

    def _drain_engine():
        """
        Run until the ring is empty *or* the sticky error blocks all fetches.
        Mirrors ring_manager.sv: head advances on issue (so bad descriptors still
        consume their slot), DF drops bad descriptors instead of forwarding them
        to the data mover, and DM/AXI/SRAM keep draining the in-flight pipeline.
        """
        if not csr.is_enabled():
            return
        for _ in range(MAX_ITERS):
            if ring.is_empty():
                break
            if ring.has_error():
                # int_status_error gates fetch_req_valid in HW.
                break

            # 1. Descriptor Fetcher + AXI fetch path
            desc = ring.fetch_next_descriptor()
            if desc is None:
                break
            descs_fetched.append(desc.pack())

            # 2. DF bounds check (rtl/descriptor_fetcher.sv s_normal/s_error).
            if not df.is_descriptor_valid(desc):
                # Drop descriptor: never reaches the data mover. Pulse df_error
                # which (a) latches sticky CSR error/IRQ_STATUS bits and
                # (b) sets ring_mgr.int_status_error → blocks new issues.
                # Head still advances because in HW it advanced at issue time.
                ring.signal_df_error()
                ring.complete()
                continue

            # 3. data_mover produces two DM instructions (AXI path vs SRAM path)
            instr_axi, instr_sram = _desc_to_instr_pair(desc)
            dm_axi.enqueue(instr_axi)
            dm_sram.enqueue(instr_sram)

            # 4. Drain DM paths in MID-safe order.
            # DIR=1: AXI read → MID → SRAM write.  DIR=0: SRAM read → MID → AXI write.
            dir_bit = desc.w3 & 1
            if dir_bit:
                _drain_axi_dm(axi_golden, instr_axi)
                _drain_sram_dm(sram_ctrl, instr_sram)
            else:
                _drain_sram_dm(sram_ctrl, instr_sram)
                _drain_axi_dm(axi_golden, instr_axi)

            # 5. Advance head (mirrors as_done → ring_manager head increment)
            ring.complete()
        else:
            raise RuntimeError("run_scenario: exceeded MAX_ITERS without draining ring")

    MAX_ITERS = 1000

    # --- Process CSV rows; run the engine when SW kicks/resumes it ---
    for row in rows:
        parsed = _parse_row(row)
        if parsed is None:
            continue
        op, args = parsed

        if op == "smem":
            wi   = int(args[0], 10)
            data = int(args[1], 16) & 0xFFFFFFFF
            if wi >= smem_words:
                raise ValueError("smem word index %d out of range (size=%d)" % (wi, smem_words))
            sysmem.mem[wi] = data

        elif op == "sram":
            wi   = int(args[0], 10)
            data = int(args[1], 16) & 0xFFFFFFFF
            if wi >= sram_words:
                raise ValueError("sram word index %d out of range (size=%d)" % (wi, sram_words))
            sram.mem[wi] = data

        elif op == "csr_baseaddr":
            addr = int(args[0], 16) & 0xFFFFFFFF
            csr.write(csr.REG_BASEADDR, addr)
            stim_lines.append("csr_write %02x %08x" % (csr.REG_BASEADDR, addr))

        elif op == "csr_ringlen":
            rlen = int(args[0], 0)
            csr.write(csr.REG_RINGLEN, rlen)
            stim_lines.append("csr_write %02x %08x" % (csr.REG_RINGLEN, rlen))

        elif op == "desc":
            w0 = int(args[0], 16) & 0xFFFFFFFF
            w1 = int(args[1], 16) & 0xFFFFFFFF
            w2 = int(args[2], 16) & 0xFFFFFFFF
            w3 = int(args[3], 16) & 0xFFFFFFFF
            desc = Descriptor(w0, w1, w2, w3)
            ring.enqueue(desc)
            # Emit the updated tail so the TB can mirror it via AXI-Lite
            tail = csr.read(csr.REG_TAIL)
            stim_lines.append("csr_write %02x %08x" % (csr.REG_TAIL, tail))

        elif op == "enable":
            ctrl = csr.read(csr.REG_CTRL) | (1 << CSR.ENABLE_BIT) | (1 << CSR.IRQ_EN_BIT)
            csr.write(csr.REG_CTRL, ctrl)
            stim_lines.append("csr_write %02x %08x" % (csr.REG_CTRL, ctrl))
            _snapshot_initial()
            _drain_engine()

        elif op == "csr_irq_clear":
            mask = int(args[0], 16) & 0xFFFFFFFF
            csr.write(csr.REG_IRQ_CLEAR, mask)
            stim_lines.append("csr_write %02x %08x" % (csr.REG_IRQ_CLEAR, mask))
            # Resume any work that was blocked by the sticky error.
            _drain_engine()

        else:
            raise ValueError("unknown CSV op: %r" % op)

    # If the scenario never enabled the engine, snapshots are still meaningful.
    if initial_smem is None:
        initial_smem = list(sysmem.mem)
        initial_sram = list(sram.mem)

    return (
        stim_lines,
        initial_smem,
        list(sysmem.mem),
        initial_sram,
        list(sram.mem),
        descs_fetched,
    )


# -------------------------------------------------------------------------
# Output helpers
# -------------------------------------------------------------------------

def _write_hex32(path, words):
    """Write one 32-bit word per line in hex."""
    with open(path, "w") as f:
        for w in words:
            f.write("%08x\n" % (w & 0xFFFFFFFF))


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    out_dir  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "out")
    os.makedirs(out_dir, exist_ok=True)

    with open(csv_path, newline="") as f:
        rows = list(csv.reader(f))

    stim, init_smem, final_smem, init_sram, final_sram, descs = run_scenario(rows)

    # stim.txt — CSR writes for the SV testbench
    stim_path = os.path.join(out_dir, "stim.txt")
    with open(stim_path, "w") as f:
        f.write("# generated from %s\n" % os.path.basename(csv_path))
        for line in stim:
            f.write(line + "\n")

    # Memory images
    _write_hex32(os.path.join(out_dir, "initial_smem.hex"), init_smem)
    _write_hex32(os.path.join(out_dir, "golden_smem.hex"),  final_smem)
    _write_hex32(os.path.join(out_dir, "initial_sram.hex"), init_sram)
    _write_hex32(os.path.join(out_dir, "golden_sram.hex"),  final_sram)

    # Descriptors fetched (128-bit, 32 hex digits each)
    with open(os.path.join(out_dir, "golden_descs.hex"), "w") as f:
        for p in descs:
            f.write("%032x\n" % (p & ((1 << 128) - 1)))

    # Summary
    with open(os.path.join(out_dir, "summary.txt"), "w") as f:
        f.write("descriptors_fetched=%d\n" % len(descs))
        f.write("stim_lines=%d\n" % len(stim))

    print("Wrote:  %s" % stim_path)
    print("Golden: descs=%d  smem=%d words  sram=%d words" % (
        len(descs), len(final_smem), len(final_sram)))


if __name__ == "__main__":
    main()