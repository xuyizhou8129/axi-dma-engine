import argparse
import json
import serial
import struct
import subprocess
import time
import sys
import os
import zlib

# ── Output formatting ────────────────────────────────────────────────────────
_USE_COLOR = sys.stdout.isatty()

def _c(code, s):   return ("\033[%sm%s\033[0m" % (code, s)) if _USE_COLOR else s
def _bold(s):      return _c("1",    s)
def _green(s):     return _c("1;32", s)
def _red(s):       return _c("1;31", s)
def _yellow(s):    return _c("33",   s)
def _cyan(s):      return _c("36",   s)
def _dim(s):       return _c("2",    s)

_W = 56
def _sep(ch="━"): print(ch * _W)


# ── Live visualization (subprocess + JSON-line IPC) ──────────────────────────
class Viz:
    """Spawn viz.py as a subprocess and pipe JSON events to it."""
    def __init__(self, enabled, viz_path):
        self.enabled = enabled
        self.proc = None
        if not enabled:
            return
        try:
            self.proc = subprocess.Popen(
                [sys.executable, viz_path],
                stdin=subprocess.PIPE, text=True, bufsize=1,
            )
        except Exception as e:
            print(_red(f"  viz: failed to spawn ({e}), continuing without visualization"))
            self.enabled = False

    def send(self, event):
        if not self.enabled or not self.proc or self.proc.stdin is None:
            return
        try:
            self.proc.stdin.write(json.dumps(event) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError):
            self.enabled = False

    def close(self):
        if self.proc and self.proc.stdin is not None:
            try:
                self.proc.stdin.close()
            except Exception:
                pass


# Firmware Protocol Definitions matches protocol.h
PACKET_SYNC_WORD  = 0xDEADBEEF
CMD_WRITE_SRAM    = 0x01
CMD_WRITE_SYSMEM  = 0x02
CMD_WRITE_CSR     = 0x03
CMD_RUN_DMA       = 0x04
CMD_REQ_RESULTS   = 0x05
CMD_READ_SRAM     = 0x06
CMD_READ_SYSMEM   = 0x07
CMD_CRC_SRAM      = 0x08
CMD_CRC_SYSMEM    = 0x09
CMD_READ_CSR      = 0x0A

CMD_ACK           = 0xAA
CMD_NACK          = 0xEE

PORT = 'COM5'
BAUD = 9600
CSR_BASE = 0x80000000

# CSR offsets (from csr_spec.md)
CSR_OFF_BASEADDR   = 0x00
CSR_OFF_RINGLEN    = 0x04
CSR_OFF_HEAD       = 0x08
CSR_OFF_TAIL       = 0x0C
CSR_OFF_CTRL       = 0x10
CSR_OFF_STATUS     = 0x14
CSR_OFF_IRQ_STATUS = 0x18


def csr_read(ser, offset):
    """Read a CSR register over UART (direct MMIO, not via shim)."""
    return read_memory(ser, CMD_READ_CSR, CSR_BASE + offset)


def dump_csr_status(ser, label="CSR snapshot"):
    """Print STATUS / IRQ_STATUS / HEAD / TAIL so the user can see error bits."""
    status     = csr_read(ser, CSR_OFF_STATUS)
    irq_status = csr_read(ser, CSR_OFF_IRQ_STATUS)
    head       = csr_read(ser, CSR_OFF_HEAD)
    tail       = csr_read(ser, CSR_OFF_TAIL)
    print(_dim(f"\n--- {label} ---"))
    if status is None:
        print(_red("  CSR read failed."))
        return
    busy  = (status >> 0) & 1
    empty = (status >> 1) & 1
    err   = (status >> 2) & 1
    irq_e = (irq_status >> 0) & 1 if irq_status is not None else '?'
    irq_x = (irq_status >> 1) & 1 if irq_status is not None else '?'
    print(_dim(f"  STATUS     = {hex(status)}  BUSY={busy} EMPTY={empty} ERROR={err}"))
    print(_dim(f"  IRQ_STATUS = {hex(irq_status)}  EMPTY={irq_e} ERROR={irq_x}"))
    print(_dim(f"  HEAD       = {head}"))
    print(_dim(f"  TAIL       = {tail}"))


def wait_for_ack(ser):
    """Scan for SYNC word then return True if ACK, False on NACK or timeout."""
    sync_val = 0
    while True:
        b = ser.read(1)
        if not b:
            print("Timeout waiting for ACK")
            return False
        sync_val = ((sync_val >> 8) | (b[0] << 24)) & 0xFFFFFFFF
        if sync_val == PACKET_SYNC_WORD:
            ack = ser.read(1)[0]
            if ack == CMD_ACK:
                return True
            print(f"Received NACK: {hex(ack)}")
            return False


def build_packet(opcode, address, payload=bytes()):
    header = struct.pack('<IBII', PACKET_SYNC_WORD, opcode, address, len(payload))
    return header + payload


def read_memory(ser, opcode, addr):
    ser.write(build_packet(opcode, addr))
    if wait_for_ack(ser):
        data = ser.read(4)
        if len(data) == 4:
            return struct.unpack('<I', data)[0]
        print("  -> FAILED: short read on data bytes")
    return None


def request_crc(ser, opcode, addr, byte_len):
    payload = struct.pack('<I', byte_len)
    ser.write(build_packet(opcode, addr, payload))
    if wait_for_ack(ser):
        crc_bytes = ser.read(4)
        if len(crc_bytes) == 4:
            return struct.unpack('<I', crc_bytes)[0]
        print("  -> FAILED: short read on CRC bytes")
    return None


def compute_crc32(words):
    """CRC32-IEEE (zlib) of a list of u32s packed little-endian — matches firmware."""
    data = struct.pack('<' + 'I' * len(words), *words)
    return zlib.crc32(data) & 0xFFFFFFFF


def parse_stimulus(filename, ser, csr_base_addr=0x80000000):
    """Send all directives from stim.txt and build a model of what was loaded.
    Returns a list of transfer dicts (one per enqueued descriptor):
        [{src_addr, dst_addr, len_words, dir, expected_words}, ...]
    Walks the descriptor ring from index 0 to TAIL-1.
    """
    sysmem_image  = {}   # byte_addr -> u32
    sram_image    = {}
    csr_writes    = {}   # offset -> value (last write wins)

    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()

            if parts[0] == 'csr_write':
                offset = int(parts[1], 16)
                value  = int(parts[2], 16)
                addr   = csr_base_addr + offset
                csr_writes[offset] = value

                payload = struct.pack('<I', value)
                print(_dim(f"Sending CSR Write: Addr {hex(addr)}, Val {hex(value)}"))
                ser.write(build_packet(CMD_WRITE_CSR, addr, payload))
                if not wait_for_ack(ser):
                    print(_red("  -> FAILED")); sys.exit(1)
                print(_dim("  -> ACK'd"))

            elif parts[0] in ('sysmem_write', 'sram_write'):
                addr  = int(parts[1], 16)
                value = int(parts[2], 16)
                if parts[0] == 'sysmem_write':
                    sysmem_image[addr] = value
                    opcode = CMD_WRITE_SYSMEM
                else:
                    sram_image[addr] = value
                    opcode = CMD_WRITE_SRAM

                payload = struct.pack('<I', value)
                print(_dim(f"Sending {parts[0]}: Addr {hex(addr)}, Val {hex(value)}"))
                ser.write(build_packet(opcode, addr, payload))
                if not wait_for_ack(ser):
                    print(_red("  -> FAILED")); sys.exit(1)
                print(_dim("  -> ACK'd"))

            elif parts[0] in ('sysmem_read', 'sram_read'):
                addr = int(parts[1], 16)
                opcode = CMD_READ_SYSMEM if parts[0] == 'sysmem_read' else CMD_READ_SRAM
                print(_dim(f"Sending {parts[0]}: Addr {hex(addr)}"))
                val = read_memory(ser, opcode, addr)
                if val is None:
                    print(_red("  -> FAILED ACK")); sys.exit(1)
                print(_dim(f"  -> SUCCESS: Read Value = {hex(val)}"))

    # --- Walk the ring (BASEADDR ... BASEADDR + TAIL*16) for each descriptor ---
    # Descriptor layout (descriptor_struct.md):
    #   +0x00 SRC_ADDR, +0x04 DST_ADDR, +0x08 LEN (low 8b = beat count), +0x0C FLAGS (bit0=DIR)
    ring_baseaddr = csr_writes.get(CSR_OFF_BASEADDR, 0)
    tail          = csr_writes.get(CSR_OFF_TAIL, 0)

    transfers = []
    for i in range(tail):
        desc_off   = ring_baseaddr + i * 16
        desc_src   = sysmem_image.get(desc_off + 0x00, 0)
        desc_dst   = sysmem_image.get(desc_off + 0x04, 0)
        desc_len   = sysmem_image.get(desc_off + 0x08, 0) & 0xFF
        desc_flags = sysmem_image.get(desc_off + 0x0C, 0)
        desc_dir   = desc_flags & 1

        src_image      = sysmem_image if desc_dir == 1 else sram_image
        expected_words = [src_image.get(desc_src + j * 4, 0) for j in range(desc_len)]

        transfers.append({
            'src_addr':       desc_src,
            'dst_addr':       desc_dst,
            'len_words':      desc_len,
            'dir':            desc_dir,
            'expected_words': expected_words,
        })
    return transfers


def verify_one_transfer(ser, idx, params, viz=None):
    """Verify a single descriptor's transfer. Returns True on PASS."""
    src_addr       = params['src_addr']
    dst_addr       = params['dst_addr']
    len_words      = params['len_words']
    direction      = params['dir']
    expected_words = params['expected_words']

    if len_words == 0:
        print(_yellow(f"  [SKIP] Desc {idx}: LEN=0"))
        return True

    expected_crc = compute_crc32(expected_words)
    byte_len     = len_words * 4

    if direction == 1:
        dst_crc_op, src_crc_op = CMD_CRC_SRAM,   CMD_CRC_SYSMEM
        dst_read_op            = CMD_READ_SRAM
        dst_label              = f"SRAM[{hex(dst_addr)}]"
        src_label              = f"SYSMEM[{hex(src_addr)}]"
        dst_region, src_region = "sram", "smem"
        src_read_op            = CMD_READ_SYSMEM
    else:
        dst_crc_op, src_crc_op = CMD_CRC_SYSMEM, CMD_CRC_SRAM
        dst_read_op            = CMD_READ_SYSMEM
        dst_label              = f"SYSMEM[{hex(dst_addr)}]"
        src_label              = f"SRAM[{hex(src_addr)}]"
        dst_region, src_region = "smem", "sram"
        src_read_op            = CMD_READ_SRAM

    print(f"\n  {_bold(_cyan(f'[Desc {idx}]'))} {src_label} -> {dst_label}, {len_words} word(s), "
          f"DIR={direction}, expected_crc={hex(expected_crc)}")

    # ── Visualization: announce expected cells, then per-cell reads ──────────
    if viz and viz.enabled:
        viz.send({"type": "header",
                  "label": f"Desc {idx}  ·  {src_label} -> {dst_label}  ·  {len_words} word(s)"})
        exp_dst = [[dst_addr + j * 4, expected_words[j]] for j in range(len_words)]
        exp_src = [[src_addr + j * 4, expected_words[j]] for j in range(len_words)]
        viz.send({"type": "expected", "region": dst_region, "cells": exp_dst})
        viz.send({"type": "expected", "region": src_region, "cells": exp_src})
        # Read each dst cell, then each src cell, emitting actual events.
        for j in range(len_words):
            a = dst_addr + j * 4
            v = read_memory(ser, dst_read_op, a)
            viz.send({"type": "actual", "region": dst_region, "addr": a,
                      "value": v if v is not None else 0})
        for j in range(len_words):
            a = src_addr + j * 4
            v = read_memory(ser, src_read_op, a)
            viz.send({"type": "actual", "region": src_region, "addr": a,
                      "value": v if v is not None else 0})

    ok = True
    PASS = _green("[PASS]")
    FAIL = _red("[FAIL]")

    val = read_memory(ser, dst_read_op, dst_addr)
    if val is None:
        print(f"    {FAIL} {dst_label}: read failed");                           ok = False
    elif val == expected_words[0]:
        print(f"    {PASS} {dst_label} = {hex(val)}")
    else:
        print(f"    {FAIL} {dst_label} = {hex(val)}, expected {hex(expected_words[0])}"); ok = False

    fw_crc_dst = request_crc(ser, dst_crc_op, dst_addr, byte_len)
    dst_crc_ok = (fw_crc_dst is not None) and (fw_crc_dst == expected_crc)
    if fw_crc_dst is None:
        print(f"    {FAIL} dst CRC: request failed"); ok = False
    elif fw_crc_dst == expected_crc:
        print(f"    {PASS} dst CRC = {hex(fw_crc_dst)}")
    else:
        print(f"    {FAIL} dst CRC = {hex(fw_crc_dst)}, expected {hex(expected_crc)}"); ok = False

    fw_crc_src = request_crc(ser, src_crc_op, src_addr, byte_len)
    src_crc_ok = (fw_crc_src is not None) and (fw_crc_src == expected_crc)
    if fw_crc_src is None:
        print(f"    {FAIL} src CRC: request failed"); ok = False
    elif fw_crc_src == expected_crc:
        print(f"    {PASS} src CRC = {hex(fw_crc_src)} (source intact)")
    else:
        print(f"    {FAIL} src CRC = {hex(fw_crc_src)}, expected {hex(expected_crc)}"); ok = False

    # ── Visualization: sweep green (or red) for each cell ────────────────────
    if viz and viz.enabled:
        dst_evt = "match" if dst_crc_ok else "fail"
        src_evt = "match" if src_crc_ok else "fail"
        for j in range(len_words):
            viz.send({"type": dst_evt, "region": dst_region, "addr": dst_addr + j * 4})
        for j in range(len_words):
            viz.send({"type": src_evt, "region": src_region, "addr": src_addr + j * 4})

    return ok


def verify_dma_result(ser, transfers, viz=None):
    """Verify each descriptor's transfer in order. Returns True only if all PASS."""
    print()
    print("  " + _bold(_cyan("DMA Verification")))
    _sep()
    print(f"  Descriptors enqueued: {len(transfers)}")

    if not transfers:
        print(_yellow("  [SKIP] No descriptors to verify (TAIL=0)."))
        return False

    all_pass = True
    for idx, params in enumerate(transfers):
        if not verify_one_transfer(ser, idx, params, viz=viz):
            all_pass = False

    print()
    _sep()
    if all_pass:
        print("  " + _bold(_green("✓  DMA TEST PASSED")))
    else:
        print("  " + _bold(_red("✗  DMA TEST FAILED")))
    _sep()
    print()
    return all_pass


def main():
    _default_stim = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stim.txt')

    _default_viz = os.path.join(os.path.dirname(os.path.abspath(__file__)), "viz.py")

    parser = argparse.ArgumentParser(description="Host runner for DMA FPGA validation")
    parser.add_argument("--port",     default=PORT,           help="Serial port (default: %s)" % PORT)
    parser.add_argument("--baud",     type=int, default=BAUD, help="Baud rate (default: %d)" % BAUD)
    parser.add_argument("--stim",     default=_default_stim,  help="Path to stim.txt (default: firmware/stim.txt)")
    parser.add_argument("--no-color", action="store_true",    help="Disable ANSI colour output")
    parser.add_argument("--viz",      action="store_true",    help="Live Rich visualization during verify (requires `pip install rich`)")
    parser.add_argument("--viz-path", default=_default_viz,   help="Path to viz.py (default: firmware/viz.py)")
    args = parser.parse_args()

    global _USE_COLOR
    if args.no_color:
        _USE_COLOR = False

    # ── --viz setup ──────────────────────────────────────────────────────────
    # Rich's Live takes over the terminal (alt-screen). Redirect host_runner's
    # own stdout/stderr to a log file so we don't fight viz for the screen.
    # If `rich` isn't installed, fall back gracefully without redirecting.
    if args.viz:
        import importlib.util
        if importlib.util.find_spec("rich") is None:
            print(_red("--viz needs the `rich` package. Install with:  pip install rich"))
            print(_dim("    Continuing without visualization..."))
            args.viz = False
        else:
            log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "host_runner.log")
            print(_cyan("⏵ Live visualization starting..."))
            print(_dim(f"    Logs will be written to: {log_path}"))
            print(_dim("    Press Ctrl+C in the visualization window to exit"))
            sys.stdout.flush()
            time.sleep(0.6)
            try:
                _log_fp = open(log_path, "w", buffering=1)
                sys.stdout = _log_fp
                sys.stderr = _log_fp
            except OSError:
                args.viz = False
            _USE_COLOR = False

    viz = Viz(enabled=args.viz, viz_path=args.viz_path)
    if viz.enabled:
        viz.send({"type": "header", "label": f"AXI DMA — {os.path.basename(args.stim)}"})

    print()
    print("  " + _bold(_cyan("AXI DMA Engine  ·  Host Runner")))
    _sep()
    print(f"  Port  {args.port}  @  {args.baud} baud")
    print(f"  Stim  {os.path.relpath(args.stim)}")
    print()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=2)
        print(_green("  ✓  Connected to FPGA"))
    except Exception as e:
        print(_red(f"  ✗  Error opening port: {e}"))
        return

    time.sleep(1)
    boot_msg = ser.read_all().decode(errors='ignore')
    if boot_msg.strip():
        print(_dim(boot_msg.rstrip()))

    stim_path = os.path.abspath(args.stim)
    print()
    print("  " + _bold(_cyan(f"Parsing and sending {os.path.basename(stim_path)}")))
    _sep()
    transfers = parse_stimulus(stim_path, ser)

    print()
    print("  " + _bold(_cyan("Sending RUN DMA Command")))
    _sep()
    ser.write(build_packet(CMD_RUN_DMA, 0x00000000))
    dma_ok = wait_for_ack(ser)
    if dma_ok:
        print(_green("  ✓  DMA Trigger ACK'd"))
    else:
        print(_red("  ✗  DMA failed (NACK or timeout)"))

    # Always read CSR after RUN_DMA so the user can see error bits even on NACK.
    dump_csr_status(ser, "Post-DMA CSR snapshot")

    if dma_ok:
        verify_dma_result(ser, transfers, viz=viz)
    ser.close()
    viz.close()
    sys.exit(0 if dma_ok else 1)


if __name__ == '__main__':
    main()
