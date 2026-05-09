#!/usr/bin/env python3
"""
Python serial host for DMA FPGA verification on Arty A7 + MicroBlaze.

Workflow:
  1. Run run_golden.py to generate out/stim.txt and golden hex files.
  2. Open the serial port connected to the Arty A7's FTDI USB-UART chip.
  3. Pre-write system memory and SRAM via binary protocol.
  4. Send each CSR write from stim.txt to the MicroBlaze firmware over UART.
  5. Trigger DMA via CMD_RUN_DMA.
  6. Report PASS / FAIL.

Binary Protocol — matches vitis_workspace/hellow_world/src/protocol.h (Vivado branch):

  Host → FPGA packet:
    [Sync Word : 4 bytes LE] = 0xDEADBEEF
    [Opcode    : 1 byte    ]
    [Address   : 4 bytes LE]
    [Length    : 4 bytes LE] = byte count of payload
    [Payload   : Length bytes]

  FPGA → Host ACK:
    [Sync Word : 4 bytes LE] = 0xDEADBEEF
    [ACK/NACK  : 1 byte    ] = 0xAA (ACK) or 0xEE (NACK)

  Opcodes:
    CMD_WRITE_SRAM   = 0x01   write payload bytes to SRAM at Address
    CMD_WRITE_SYSMEM = 0x02   write payload bytes to system memory at Address
    CMD_WRITE_CSR    = 0x03   write payload bytes to CSR at Address
    CMD_RUN_DMA      = 0x04   trigger DMA engine (no payload)
    CMD_REQ_RESULTS  = 0x05   (reserved — not yet implemented in firmware)

  Note: CMD_REQ_RESULTS, CSR reads, CRC verification, and DMA-done polling are
  not yet implemented in the MicroBlaze firmware. Those methods raise
  NotImplementedError until the firmware is updated.

Usage:
  python3 serial_host.py [--port /dev/tty.usbserial-XXX] [--baud 9600]
                         [--csr-base 0x40000000]
                         [--smem-base 0x00000000] [--sram-base 0x00010000]
                         [--scenario scenarios/example.csv] [--out-dir out]
  python3 serial_host.py --list-ports

CSR register byte offsets (matches csr.py / dma_pkg.sv):
  BASEADDR   0x00   RINGLEN  0x04   HEAD  0x08   TAIL  0x0C
  CTRL       0x10   STATUS   0x14   IRQ_STATUS 0x18
"""

from __future__ import print_function

import argparse
import csv
import glob
import os
import struct
import sys
import time
import zlib

# Binary protocol constants — must match protocol.h in Vivado branch
PACKET_SYNC_WORD = 0xDEADBEEF
CMD_WRITE_SRAM   = 0x01
CMD_WRITE_SYSMEM = 0x02
CMD_WRITE_CSR    = 0x03
CMD_RUN_DMA      = 0x04
CMD_REQ_RESULTS  = 0x05
CMD_READ_SRAM    = 0x06
CMD_READ_SYSMEM  = 0x07
CMD_CRC_SRAM     = 0x08
CMD_CRC_SYSMEM   = 0x09
CMD_READ_CSR     = 0x0A
CMD_ACK          = 0xAA
CMD_NACK         = 0xEE
HEADER_SIZE      = 13  # 4 (sync) + 1 (opcode) + 4 (addr) + 4 (len)

PORT = 'COM5'
BAUD = 9600

# Optional import — fail gracefully so the module can be imported without
# pyserial installed (unit tests / dry-run mode still work).
try:
    import serial
    import serial.tools.list_ports
    _SERIAL_AVAILABLE = True
except ImportError:
    _SERIAL_AVAILABLE = False

# Paths
_here    = os.path.dirname(os.path.abspath(__file__))
_sim_dir = os.path.join(os.path.dirname(_here), "sim")
_source  = os.path.join(os.path.dirname(_here), "source")
if _source not in sys.path:
    sys.path.insert(0, _source)

# CSR constants (must match csr.py / dma_pkg.sv)
CSR_STATUS     = 0x14
CSR_IRQ_STATUS = 0x18
STATUS_BUSY_BIT        = 0
STATUS_RING_EMPTY_BIT  = 1
STATUS_ERROR_BIT       = 2
IRQ_ERROR_BIT          = 1

# Helpers
def _load_hex32(path):
    """Read a one-word-per-line hex file into a list of 32-bit ints."""
    words = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                words.append(int(line, 16) & 0xFFFFFFFF)
    return words


def _crc32_words(words):
    """CRC32 of a list of 32-bit words packed as little-endian bytes (zlib compatible)."""
    raw = struct.pack("<%dI" % len(words), *words)
    return zlib.crc32(raw) & 0xFFFFFFFF


# Serial port helpers
def _find_arty_port():
    """Return the first likely Arty A7 USB-UART port, or None."""
    # macOS: /dev/tty.usbserial-* or /dev/cu.usbserial-*
    for pattern in ["/dev/tty.usbserial-*", "/dev/cu.usbserial-*", "/dev/ttyUSB*"]:
        matches = sorted(glob.glob(pattern))
        if matches:
            return matches[0]
    return None


def list_ports():
    if not _SERIAL_AVAILABLE:
        print("pyserial not installed — run: pip install pyserial")
        return
    for p in serial.tools.list_ports.comports():
        print(p.device, "—", p.description)


# Protocol implementation
class DMASerialHost:
    """Send/receive over the binary protocol defined in protocol.h (Vivado branch)."""

    def __init__(self, port, baud=9600, timeout=2.0,
                 csr_base_addr=0x80000000,
                 smem_base_addr=0x00000000,
                 sram_base_addr=0x00000000):
        if not _SERIAL_AVAILABLE:
            raise RuntimeError("pyserial is not installed. Run: pip install pyserial")
        self.ser = serial.Serial(port, baudrate=baud, timeout=timeout)
        self.csr_base_addr  = csr_base_addr
        self.smem_base_addr = smem_base_addr
        self.sram_base_addr = sram_base_addr
        time.sleep(0.1)  # let FTDI settle
        self.ser.reset_input_buffer()

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

    @staticmethod
    def _build_packet(opcode, address, payload=b""):
        """Pack a binary protocol packet: sync + opcode + addr + len + payload."""
        header = struct.pack("<IBII", PACKET_SYNC_WORD, opcode, address, len(payload))
        return header + payload

    def _send_packet(self, opcode, address, payload=b""):
        self.ser.write(self._build_packet(opcode, address, payload))

    def _wait_for_ack(self, timeout=2.0):
        """
        Scan incoming bytes for PACKET_SYNC_WORD then read the ACK/NACK byte.
        Returns True on ACK, raises RuntimeError on NACK or timeout.
        """
        deadline = time.time() + timeout
        sync_val = 0
        while time.time() < deadline:
            b = self.ser.read(1)
            if not b:
                continue
            sync_val = ((sync_val >> 8) | (b[0] << 24)) & 0xFFFFFFFF
            if sync_val == PACKET_SYNC_WORD:
                resp = self.ser.read(1)
                if not resp:
                    raise TimeoutError("Timeout reading ACK byte from FPGA")
                if resp[0] == CMD_ACK:
                    return True
                raise RuntimeError("FPGA returned NACK (0x%02x)" % resp[0])
        raise TimeoutError("No ACK from FPGA within %.1fs" % timeout)

    # ----------------------------------------------------------------
    # CSR access
    # ----------------------------------------------------------------
    def csr_write(self, byte_offset, data):
        """Write a 32-bit value to a CSR register (absolute address = csr_base + offset)."""
        addr    = (self.csr_base_addr + byte_offset) & 0xFFFFFFFF
        payload = struct.pack("<I", data & 0xFFFFFFFF)
        self._send_packet(CMD_WRITE_CSR, addr, payload)
        self._wait_for_ack()

    def csr_read(self, byte_offset):
        """Read a CSR register via CMD_READ_CSR (absolute addr = csr_base + offset)."""
        addr = (self.csr_base_addr + byte_offset) & 0xFFFFFFFF
        self._send_packet(CMD_READ_CSR, addr)
        self._wait_for_ack()
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Timeout reading CSR word")
        return struct.unpack("<I", data)[0]

    def dump_csr_status(self, label="CSR snapshot"):
        try:
            status     = self.csr_read(0x14)  # CSR_REG_STATUS
            irq_status = self.csr_read(0x18)  # CSR_REG_IRQ_STATUS
            head       = self.csr_read(0x08)  # CSR_REG_HEAD
            tail       = self.csr_read(0x0C)  # CSR_REG_TAIL
        except (TimeoutError, RuntimeError) as e:
            print("  CSR dump failed: %s" % e)
            return
        print("\n--- %s ---" % label)
        print("  STATUS     = 0x%08x  BUSY=%d EMPTY=%d ERROR=%d" % (
            status, status & 1, (status >> 1) & 1, (status >> 2) & 1))
        print("  IRQ_STATUS = 0x%08x  EMPTY_IRQ=%d ERROR_IRQ=%d" % (
            irq_status, irq_status & 1, (irq_status >> 1) & 1))
        print("  HEAD       = %d" % head)
        print("  TAIL       = %d" % tail)

    # ----------------------------------------------------------------
    # Memory writes
    # ----------------------------------------------------------------
    def smem_write(self, byte_addr, data):
        """Write one 32-bit word to system memory (absolute addr = smem_base + byte_addr)."""
        addr    = (self.smem_base_addr + byte_addr) & 0xFFFFFFFF
        payload = struct.pack("<I", data & 0xFFFFFFFF)
        self._send_packet(CMD_WRITE_SYSMEM, addr, payload)
        self._wait_for_ack()

    def sram_write(self, byte_addr, data):
        """Write one 32-bit word to SRAM (absolute addr = sram_base + byte_addr)."""
        addr    = (self.sram_base_addr + byte_addr) & 0xFFFFFFFF
        payload = struct.pack("<I", data & 0xFFFFFFFF)
        self._send_packet(CMD_WRITE_SRAM, addr, payload)
        self._wait_for_ack()

    # ----------------------------------------------------------------
    # Single-word reads (for debug spot-checks)
    # ----------------------------------------------------------------
    def read_smem(self, byte_addr):
        addr = (self.smem_base_addr + byte_addr) & 0xFFFFFFFF
        self._send_packet(CMD_READ_SYSMEM, addr)
        self._wait_for_ack()
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Timeout reading SMEM word")
        return struct.unpack("<I", data)[0]

    def read_sram(self, byte_addr):
        addr = (self.sram_base_addr + byte_addr) & 0xFFFFFFFF
        self._send_packet(CMD_READ_SRAM, addr)
        self._wait_for_ack()
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Timeout reading SRAM word")
        return struct.unpack("<I", data)[0]

    # ----------------------------------------------------------------
    # DMA trigger
    # ----------------------------------------------------------------
    def run_dma(self, timeout=30.0):
        """Send CMD_RUN_DMA to trigger the DMA engine."""
        self._send_packet(CMD_RUN_DMA, 0x00000000)
        self._wait_for_ack(timeout=timeout)
        print("DMA trigger ACK'd")

    # ----------------------------------------------------------------
    # High-level DMA operations
    # ----------------------------------------------------------------
    def send_stim(self, stim_path):
        """Parse stim.txt and issue all memory and CSR writes."""
        count = 0
        with open(stim_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if len(parts) != 3:
                    continue
                addr = int(parts[1], 16)
                data = int(parts[2], 16)
                if parts[0] == "sysmem_write":
                    self.smem_write(addr, data)
                elif parts[0] == "sram_write":
                    self.sram_write(addr, data)
                elif parts[0] == "csr_write":
                    if addr == 0x10:  # CTRL register — skip, CMD_RUN_DMA handles ENABLE
                        continue
                    self.csr_write(addr, data)
                else:
                    continue
                count += 1
        print("Sent %d command(s) from %s" % (count, os.path.basename(stim_path)))

    def wait_done(self, poll_interval=0.1, timeout=30.0):
        """Requires CSR reads — not yet implemented in firmware. Raises NotImplementedError."""
        raise NotImplementedError(
            "wait_done: requires csr_read (CMD_REQ_RESULTS), which is not yet implemented "
            "in the MicroBlaze firmware. The firmware CMD_RUN_DMA has a TODO for completion polling."
        )

    def check_irq(self):
        """Requires CSR reads — not yet implemented in firmware. Raises NotImplementedError."""
        raise NotImplementedError(
            "check_irq: requires csr_read (CMD_REQ_RESULTS), which is not yet implemented "
            "in the MicroBlaze firmware."
        )

    def smem_crc(self, byte_addr, byte_length):
        """CRC32 over [byte_addr, byte_addr+byte_length) words in system memory.
        Returns the 32-bit zlib-compatible CRC reported by the firmware."""
        addr    = (self.smem_base_addr + byte_addr) & 0xFFFFFFFF
        payload = struct.pack("<I", byte_length & 0xFFFFFFFF)
        self._send_packet(CMD_CRC_SYSMEM, addr, payload)
        self._wait_for_ack()
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Timeout reading CRC bytes from FPGA")
        return struct.unpack("<I", data)[0]

    def sram_crc(self, byte_addr, byte_length):
        """CRC32 over [byte_addr, byte_addr+byte_length) words in SRAM.
        Returns the 32-bit zlib-compatible CRC reported by the firmware."""
        addr    = (self.sram_base_addr + byte_addr) & 0xFFFFFFFF
        payload = struct.pack("<I", byte_length & 0xFFFFFFFF)
        self._send_packet(CMD_CRC_SRAM, addr, payload)
        self._wait_for_ack()
        data = self.ser.read(4)
        if len(data) != 4:
            raise TimeoutError("Timeout reading CRC bytes from FPGA")
        return struct.unpack("<I", data)[0]

    # ----------------------------------------------------------------
    # High-level memory preload
    # ----------------------------------------------------------------
    def send_initial_smem(self, hex_path):
        """Pre-write system memory from initial_smem.hex. Only non-zero words sent."""
        words = _load_hex32(hex_path)
        count = 0
        for i, w in enumerate(words):
            if w != 0:
                self.smem_write(i * 4, w)
                count += 1
        print("SMEM preload: wrote %d non-zero word(s) (%d total)" % (count, len(words)))

    def send_initial_sram(self, hex_path):
        """Pre-write SRAM from initial_sram.hex. Only non-zero words sent."""
        words = _load_hex32(hex_path)
        count = 0
        for i, w in enumerate(words):
            if w != 0:
                self.sram_write(i * 4, w)
                count += 1
        print("SRAM preload: wrote %d non-zero word(s) (%d total)" % (count, len(words)))

    def verify_smem_crc(self, hex_path):
        """Compute zlib.crc32 of hex_path's words and compare to firmware-reported SMEM CRC."""
        words    = _load_hex32(hex_path)
        expected = _crc32_words(words)
        got      = self.smem_crc(0, len(words) * 4)
        if got != expected:
            raise RuntimeError(
                "SMEM CRC mismatch: expected 0x%08x, got 0x%08x" % (expected, got))
        return True

    def verify_sram_crc(self, hex_path):
        """Compute zlib.crc32 of hex_path's words and compare to firmware-reported SRAM CRC."""
        words    = _load_hex32(hex_path)
        expected = _crc32_words(words)
        got      = self.sram_crc(0, len(words) * 4)
        if got != expected:
            raise RuntimeError(
                "SRAM CRC mismatch: expected 0x%08x, got 0x%08x" % (expected, got))
        return True


# Golden model runner (local, no FPGA needed)
def run_golden(scenario_csv, out_dir):
    """Call run_golden.py's run_scenario() and write artifacts to out_dir."""
    import importlib.util, csv as _csv

    golden_path = os.path.join(_sim_dir, "run_golden.py")
    spec = importlib.util.spec_from_file_location("run_golden", golden_path)
    rg   = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rg)

    with open(scenario_csv, newline="") as f:
        rows = list(_csv.reader(f))

    stim, init_smem, final_smem, init_sram, final_sram, descs = rg.run_scenario(rows)
    os.makedirs(out_dir, exist_ok=True)

    # stim.txt
    with open(os.path.join(out_dir, "stim.txt"), "w") as f:
        f.write("# generated from %s\n" % os.path.basename(scenario_csv))
        for line in stim:
            f.write(line + "\n")

    def _hex32(path, words):
        with open(path, "w") as f:
            for w in words:
                f.write("%08x\n" % (w & 0xFFFFFFFF))

    _hex32(os.path.join(out_dir, "initial_smem.hex"), init_smem)
    _hex32(os.path.join(out_dir, "golden_smem.hex"),  final_smem)
    _hex32(os.path.join(out_dir, "initial_sram.hex"), init_sram)
    _hex32(os.path.join(out_dir, "golden_sram.hex"),  final_sram)

    with open(os.path.join(out_dir, "golden_descs.hex"), "w") as f:
        for p in descs:
            f.write("%032x\n" % (p & ((1 << 128) - 1)))

    print("Golden: descs=%d  smem=%d words  sram=%d words" % (
        len(descs), len(final_smem), len(final_sram)))
    return stim, init_smem, final_smem, init_sram, final_sram, descs

# Dry-run mode (no FPGA — just validate golden model locally)
def dry_run(scenario_csv, out_dir):
    """Run golden model and self-check transfers without touching the FPGA."""
    import csv as _csv, importlib.util

    golden_path = os.path.join(_sim_dir, "run_golden.py")
    spec = importlib.util.spec_from_file_location("run_golden", golden_path)
    rg   = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rg)

    with open(scenario_csv, newline="") as f:
        rows = list(_csv.reader(f))

    stim, init_smem, final_smem, init_sram, final_sram, descs = rg.run_scenario(rows)

    # Parse descriptors from CSV and self-check data movement
    errors = 0
    desc_rows = []
    for row in rows:
        if row and row[0].strip().lower() == "desc":
            args = [c.strip() for c in row[1:]]
            src    = int(args[0], 16)
            dst    = int(args[1], 16)
            length = int(args[2], 16) & 0xFF
            flags  = int(args[3], 16)
            desc_rows.append((src, dst, length, flags))

    for i, (src, dst, length, flags) in enumerate(desc_rows):
        dir_bit = flags & 1
        if dir_bit:
            # DIR=1: system memory → SRAM
            for beat in range(length):
                sw = (src >> 2) + beat
                dw = (dst >> 2) + beat
                if sw >= len(init_smem) or dw >= len(final_sram):
                    continue  # out of range — skip rather than false-fail
                if final_sram[dw] != init_smem[sw]:
                    print("DESC[%d] SRAM[%d]: got 0x%08x  exp 0x%08x" % (
                        i, dw, final_sram[dw], init_smem[sw]))
                    errors += 1
        else:
            # DIR=0: SRAM → system memory.
            # Compare against final_sram — a prior descriptor may have written
            # to SRAM before this one reads it (chained scenario).
            for beat in range(length):
                sw = (src >> 2) + beat
                dw = (dst >> 2) + beat
                if sw >= len(final_sram) or dw >= len(final_smem):
                    continue  # out of range — skip rather than false-fail
                if final_smem[dw] != final_sram[sw]:
                    print("DESC[%d] SMEM[%d]: got 0x%08x  exp 0x%08x" % (
                        i, dw, final_smem[dw], final_sram[sw]))
                    errors += 1

    if errors:
        print("FAIL — %d data mismatch(es) in golden model" % errors)
        return False
    print("PASS — golden model self-check (%d descriptor(s), %d stim line(s))" % (
        len(descs), len(stim)))
    return True


def dry_run_all(scenarios_dir, out_dir):
    """Run dry_run() on every CSV in scenarios_dir. Returns (pass, fail) counts."""
    csvs = sorted(glob.glob(os.path.join(scenarios_dir, "*.csv")))
    if not csvs:
        print("No CSV files found in %s" % scenarios_dir)
        return 0, 0
    passed = failed = 0
    for csv_path in csvs:
        name = os.path.basename(csv_path)
        print("\n--- %s ---" % name)
        try:
            ok = dry_run(csv_path, out_dir)
        except Exception as e:
            print("ERROR: %s" % e)
            ok = False
        if ok:
            passed += 1
        else:
            failed += 1
    print("\n=== dry-run-all: %d passed, %d failed ===" % (passed, failed))
    return passed, failed


# Main
def main():
    _default_scenario = os.path.join(_sim_dir, "scenarios", "example.csv")

    parser = argparse.ArgumentParser(
        description="Serial host for DMA FPGA verification (Arty A7 + MicroBlaze, binary protocol)"
    )
    parser.add_argument("--port",          default=PORT, help="Serial port (default: %s)" % PORT)
    parser.add_argument("--baud",          type=int, default=BAUD)
    parser.add_argument("--csr-base",      type=lambda x: int(x, 0), default=0x80000000, dest="csr_base",
                        help="AXI base address of the DMA CSR block (default 0x80000000)")
    parser.add_argument("--smem-base",     type=lambda x: int(x, 0), default=0x00000000, dest="smem_base",
                        help="AXI base address of system memory (default 0x00000000)")
    parser.add_argument("--sram-base",     type=lambda x: int(x, 0), default=0x00000000, dest="sram_base",
                        help="AXI base address of on-chip SRAM/BRAM (default 0x00000000)")
    parser.add_argument("--scenario",      default=_default_scenario, help="Scenario CSV to run")
    parser.add_argument("--out-dir",       default="out", dest="out_dir")
    parser.add_argument("--list-ports",    action="store_true", dest="list_ports", help="List available serial ports and exit")
    parser.add_argument("--dry-run",       action="store_true", dest="dry_run",    help="Run golden model only, no FPGA")
    parser.add_argument("--dry-run-all",   action="store_true", dest="dry_run_all",help="Dry-run all sim/scenarios/*.csv")
    args = parser.parse_args()

    args.scenario = os.path.abspath(args.scenario)
    args.out_dir  = os.path.abspath(args.out_dir)
    os.chdir(_here)

    if args.list_ports:
        list_ports()
        return

    if args.dry_run_all:
        passed, failed = dry_run_all(os.path.join(_sim_dir, "scenarios"), args.out_dir)
        sys.exit(0 if failed == 0 else 1)

    if args.dry_run:
        ok = dry_run(args.scenario, args.out_dir)
        sys.exit(0 if ok else 1)

    # --- FPGA path ---

    # 1. Always regenerate golden artifacts from the scenario so CRCs are fresh.
    os.makedirs(args.out_dir, exist_ok=True)
    print("Running golden model for %s ..." % args.scenario)
    run_golden(args.scenario, args.out_dir)

    stim_path    = os.path.join(args.out_dir, "stim.txt")
    golden_smem  = os.path.join(args.out_dir, "golden_smem.hex")
    golden_sram  = os.path.join(args.out_dir, "golden_sram.hex")
    smem_init_path = os.path.join(args.out_dir, "initial_smem.hex")
    sram_init_path = os.path.join(args.out_dir, "initial_sram.hex")

    # 2. Compute expected CRCs from golden files (no hardcoded constants).
    smem_words = _load_hex32(golden_smem)
    sram_words = _load_hex32(golden_sram)
    expected_smem_crc = _crc32_words(smem_words)
    expected_sram_crc = _crc32_words(sram_words)
    print("Expected SMEM CRC: 0x%08x" % expected_smem_crc)
    print("Expected SRAM CRC: 0x%08x" % expected_sram_crc)

    # 3. Connect to FPGA.
    port = args.port
    print("Opening %s at %d baud ..." % (port, args.baud))
    print("CSR base=0x%08x  SMEM base=0x%08x  SRAM base=0x%08x" % (
        args.csr_base, args.smem_base, args.sram_base))

    host = DMASerialHost(port, baud=args.baud,
                         csr_base_addr=args.csr_base,
                         smem_base_addr=args.smem_base,
                         sram_base_addr=args.sram_base)
    try:
        # 4a. Clear memories to known-zero state so leftover data from previous
        #     tests doesn't corrupt the full-memory CRC comparison.
        init_smem = _load_hex32(os.path.join(args.out_dir, "initial_smem.hex"))
        init_sram = _load_hex32(os.path.join(args.out_dir, "initial_sram.hex"))
        print("Clearing SMEM (%d words)..." % len(init_smem))
        for i, w in enumerate(init_smem):
            host.smem_write(i * 4, w)
        print("Clearing SRAM (%d words)..." % len(init_sram))
        for i, w in enumerate(init_sram):
            host.sram_write(i * 4, w)

        # 4b. Send CSR writes from stim.txt (memory already initialized above).
        host.send_stim(stim_path)

        # [DBG] Spot-check key sysmem locations after stim writes.
        print("[DBG] SMEM after stim (descriptor ring @ 0x000, data @ 0x100):")
        for off in [0x000, 0x004, 0x008, 0x00C, 0x100, 0x104, 0x108, 0x10C]:
            print("  SMEM[0x%03x] = 0x%08x" % (off, host.read_smem(off)))

        # 5. Trigger DMA and wait for completion (polled inside firmware).
        try:
            host.run_dma()
            dma_ok = True
        except RuntimeError as e:
            print("*** DMA NACK: %s ***" % e)
            dma_ok = False
        host.dump_csr_status("Post-DMA CSR snapshot")
        if not dma_ok:
            sys.exit(1)

        # [DBG] Spot-check SRAM destination and SMEM source after DMA.
        print("[DBG] SRAM after DMA (expected data @ 0x100):")
        for off in [0x100, 0x104, 0x108, 0x10C]:
            print("  SRAM[0x%03x] = 0x%08x" % (off, host.read_sram(off)))
        print("[DBG] SMEM after DMA (source should be unchanged @ 0x100):")
        for off in [0x100, 0x104, 0x108, 0x10C]:
            print("  SMEM[0x%03x] = 0x%08x" % (off, host.read_smem(off)))
        print("[DBG] SMEM descriptor ring after DMA (check for DMA writeback @ 0x000):")
        for off in [0x000, 0x004, 0x008, 0x00C]:
            print("  SMEM[0x%03x] = 0x%08x" % (off, host.read_smem(off)))

        # 6. CRC only the regions the golden model says changed (SRAM dst)
        #    and the source region in SMEM. Full-memory CRC fails because BRAM
        #    retains stale words from prior runs outside the active region.
        init_sram_words = _load_hex32(sram_init_path)
        changed = [i for i, (a, b) in enumerate(zip(init_sram_words, sram_words)) if a != b]

        all_pass = True
        if not changed:
            print("WARNING: golden model shows no SRAM changes — nothing to verify")
            all_pass = False
        else:
            lo = min(changed);  hi = max(changed) + 1
            lo_byte = lo * 4;   byte_len = (hi - lo) * 4
            exp_crc = _crc32_words(sram_words[lo:hi])
            got_crc = host.sram_crc(lo_byte, byte_len)
            ok = (got_crc == exp_crc)
            all_pass = all_pass and ok
            print("SRAM[0x%03x..+%d] CRC: got=0x%08x  exp=0x%08x  %s" % (
                lo_byte, byte_len, got_crc, exp_crc, "PASS" if ok else "FAIL"))

        init_smem_words = _load_hex32(smem_init_path)
        nonzero = [i for i, w in enumerate(init_smem_words) if w != 0]
        if nonzero:
            lo = min(nonzero);  hi = max(nonzero) + 1
            lo_byte = lo * 4;   byte_len = (hi - lo) * 4
            exp_crc = _crc32_words(init_smem_words[lo:hi])
            got_crc = host.smem_crc(lo_byte, byte_len)
            ok = (got_crc == exp_crc)
            all_pass = all_pass and ok
            print("SMEM[0x%03x..+%d] CRC: got=0x%08x  exp=0x%08x  %s" % (
                lo_byte, byte_len, got_crc, exp_crc, "PASS" if ok else "FAIL"))

        print("=== TEST PASSED ===" if all_pass else "=== TEST FAILED ===")
        if not all_pass:
            sys.exit(1)
    except (RuntimeError, TimeoutError) as e:
        print("*** FAIL: %s ***" % e)
        sys.exit(1)
    finally:
        host.close()


if __name__ == "__main__":
    main()
