#!/usr/bin/env python3
"""
Python serial host for DMA FPGA verification on Arty A7.

Workflow:
  1. Run run_golden.py to generate out/stim.txt and golden hex files.
  2. Open the serial port connected to the Arty A7's FTDI USB-UART chip.
  3. Send each CSR write from stim.txt to the MicroBlaze firmware over UART.
  4. Poll CSR_STATUS until the DMA ring reports empty and not busy.
  5. Read back CSR_IRQ_STATUS to check for errors.
  6. Report PASS / FAIL.

Protocol (ASCII, newline-terminated) — MicroBlaze firmware must match:
  Host  → FPGA:  "W XXXXXXXX YYYYYYYY\\n"      write 32-bit DATA to CSR byte offset
  Host  → FPGA:  "R XXXXXXXX\\n"               read 32-bit word at CSR byte offset
  Host  → FPGA:  "SMEM_W XXXXXXXX YYYYYYYY\\n" write word to system memory at byte addr
  Host  → FPGA:  "SRAM_W XXXXXXXX YYYYYYYY\\n" write word to SRAM at byte addr
  Host  → FPGA:  "SMEM_CRC\\n"                 request CRC32 of all system memory words
  Host  → FPGA:  "SRAM_CRC\\n"                 request CRC32 of all SRAM words
  FPGA  → Host:  "OK\\n"                        ack for any write
  FPGA  → Host:  "DATA YYYYYYYY\\n"             response for R (hex, no 0x)
  FPGA  → Host:  "CRC YYYYYYYY\\n"              response for *_CRC (hex, no 0x)

CRC32 definition (Python zlib.crc32 compatible, little-endian word packing):
  input = concatenation of all 32-bit words packed as little-endian bytes
  crc   = zlib.crc32(input) & 0xFFFFFFFF

Usage:
  python3 serial_host.py [--port /dev/tty.usbserial-XXX] [--baud 115200]
                         [--scenario scenarios/example.csv] [--out-dir out]
                         [--timeout 30] [--poll-interval 0.1]
  python3 serial_host.py --list-ports

CSR register byte offsets (matches csr.py / dma_pkg.sv):
  BASEADDR   0x00   RINGLEN  0x04   HEAD  0x08   TAIL  0x0C
  CTRL       0x10   STATUS   0x14   IRQ_STATUS 0x18

STATUS bits:  [0] busy  [1] ring_empty  [2] error
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

# Optional import — fail gracefully so the module can be imported without
# pyserial installed (unit tests / dry-run mode still work).
try:
    import serial
    import serial.tools.list_ports
    _SERIAL_AVAILABLE = True
except ImportError:
    _SERIAL_AVAILABLE = False

# Paths
_here   = os.path.dirname(os.path.abspath(__file__))
_source = os.path.join(os.path.dirname(_here), "source")
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
    """Send/receive over the ASCII protocol described in the module docstring."""

    def __init__(self, port, baud=115200, timeout=2.0):
        if not _SERIAL_AVAILABLE:
            raise RuntimeError("pyserial is not installed. Run: pip install pyserial")
        self.ser = serial.Serial(port, baudrate=baud, timeout=timeout)
        time.sleep(0.1)  # let FTDI settle
        self.ser.reset_input_buffer()

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

    def _send(self, line):
        self.ser.write((line + "\n").encode())

    def _recv_line(self, timeout=2.0):
        """Read one newline-terminated response line."""
        deadline = time.time() + timeout
        buf = b""
        while time.time() < deadline:
            ch = self.ser.read(1)
            if ch:
                buf += ch
                if ch == b"\n":
                    return buf.decode(errors="replace").strip()
        raise TimeoutError("No response from FPGA within %.1fs" % timeout)

    def csr_write(self, byte_offset, data):
        """Send W command and wait for OK."""
        self._send("W %08x %08x" % (byte_offset & 0xFFFFFFFF, data & 0xFFFFFFFF))
        resp = self._recv_line()
        if resp.upper() != "OK":
            raise RuntimeError("csr_write 0x%02x: unexpected response %r" % (byte_offset, resp))

    def csr_read(self, byte_offset):
        """Send R command and return the 32-bit value."""
        self._send("R %08x" % (byte_offset & 0xFFFFFFFF))
        resp = self._recv_line()
        # Expect "DATA YYYYYYYY"
        parts = resp.upper().split()
        if len(parts) != 2 or parts[0] != "DATA":
            raise RuntimeError("csr_read 0x%02x: unexpected response %r" % (byte_offset, resp))
        return int(parts[1], 16)

    # High-level DMA operations
    def send_stim(self, stim_path):
        """Parse stim.txt and issue all CSR writes."""
        count = 0
        with open(stim_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if parts[0] == "csr_write" and len(parts) == 3:
                    addr = int(parts[1], 16)
                    data = int(parts[2], 16)
                    self.csr_write(addr, data)
                    count += 1
        print("Sent %d CSR write(s) from %s" % (count, os.path.basename(stim_path)))

    def wait_done(self, poll_interval=0.1, timeout=30.0):
        """Poll CSR_STATUS until ring_empty=1 and busy=0, or timeout."""
        deadline = time.time() + timeout
        polls = 0
        while time.time() < deadline:
            status = self.csr_read(CSR_STATUS)
            ring_empty = bool((status >> STATUS_RING_EMPTY_BIT) & 1)
            busy       = bool((status >> STATUS_BUSY_BIT) & 1)
            error      = bool((status >> STATUS_ERROR_BIT) & 1)
            polls += 1
            if error:
                raise RuntimeError("DMA reported error (STATUS=0x%08x)" % status)
            if ring_empty and not busy:
                print("DMA complete after %d status poll(s)" % polls)
                return status
            time.sleep(poll_interval)
        raise TimeoutError("DMA did not complete within %.0fs" % timeout)

    def check_irq(self):
        """Read IRQ_STATUS and fail if error IRQ is set."""
        irq = self.csr_read(CSR_IRQ_STATUS)
        if (irq >> IRQ_ERROR_BIT) & 1:
            raise RuntimeError("IRQ_ERROR is set (IRQ_STATUS=0x%08x)" % irq)
        return irq

    # Memory pre-write protocol (new commands for MicroBlaze firmware)
    def smem_write(self, byte_addr, data):
        """Write one 32-bit word to system memory at byte_addr."""
        self._send("SMEM_W %08x %08x" % (byte_addr & 0xFFFFFFFF, data & 0xFFFFFFFF))
        resp = self._recv_line()
        if resp.upper() != "OK":
            raise RuntimeError("smem_write 0x%08x: unexpected response %r" % (byte_addr, resp))

    def sram_write(self, byte_addr, data):
        """Write one 32-bit word to SRAM at byte_addr."""
        self._send("SRAM_W %08x %08x" % (byte_addr & 0xFFFFFFFF, data & 0xFFFFFFFF))
        resp = self._recv_line()
        if resp.upper() != "OK":
            raise RuntimeError("sram_write 0x%08x: unexpected response %r" % (byte_addr, resp))

    def smem_crc(self):
        """Request CRC32 of all system memory from FPGA. Returns 32-bit int."""
        self._send("SMEM_CRC")
        resp = self._recv_line()
        parts = resp.upper().split()
        if len(parts) != 2 or parts[0] != "CRC":
            raise RuntimeError("smem_crc: unexpected response %r" % resp)
        return int(parts[1], 16)

    def sram_crc(self):
        """Request CRC32 of all SRAM from FPGA. Returns 32-bit int."""
        self._send("SRAM_CRC")
        resp = self._recv_line()
        parts = resp.upper().split()
        if len(parts) != 2 or parts[0] != "CRC":
            raise RuntimeError("sram_crc: unexpected response %r" % resp)
        return int(parts[1], 16)


    # High-level memory preload + CRC verification
    def send_initial_smem(self, hex_path):
        """
        Pre-write system memory from initial_smem.hex before starting the DMA.
        Only writes non-zero words to save time (hardware resets to 0).
        """
        words = _load_hex32(hex_path)
        count = 0
        for i, w in enumerate(words):
            if w != 0:
                self.smem_write(i * 4, w)
                count += 1
        print("SMEM preload: wrote %d non-zero word(s) (%d total)" % (count, len(words)))

    def send_initial_sram(self, hex_path):
        """
        Pre-write SRAM from initial_sram.hex before starting the DMA.
        Only writes non-zero words to save time (hardware resets to 0).
        """
        words = _load_hex32(hex_path)
        count = 0
        for i, w in enumerate(words):
            if w != 0:
                self.sram_write(i * 4, w)
                count += 1
        print("SRAM preload: wrote %d non-zero word(s) (%d total)" % (count, len(words)))

    def verify_smem_crc(self, hex_path):
        """
        Ask FPGA for its system memory CRC32 and compare against local hex file.
        Raises RuntimeError on mismatch.
        """
        words    = _load_hex32(hex_path)
        expected = _crc32_words(words)
        got      = self.smem_crc()
        if got != expected:
            raise RuntimeError(
                "SMEM CRC mismatch: got 0x%08x  expected 0x%08x" % (got, expected)
            )
        print("SMEM CRC OK (0x%08x)" % expected)

    def verify_sram_crc(self, hex_path):
        """
        Ask FPGA for its SRAM CRC32 and compare against local hex file.
        Raises RuntimeError on mismatch.
        """
        words    = _load_hex32(hex_path)
        expected = _crc32_words(words)
        got      = self.sram_crc()
        if got != expected:
            raise RuntimeError(
                "SRAM CRC mismatch: got 0x%08x  expected 0x%08x" % (got, expected)
            )
        print("SRAM CRC OK (0x%08x)" % expected)


# Golden model runner (local, no FPGA needed)
def run_golden(scenario_csv, out_dir):
    """Call run_golden.py's run_scenario() and write artifacts to out_dir."""
    import importlib.util, csv as _csv

    golden_path = os.path.join(_here, "run_golden.py")
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

    golden_path = os.path.join(_here, "run_golden.py")
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
            src  = int(args[0], 16)
            dst  = int(args[1], 16)
            length = int(args[2], 16) & 0xFF   # LEN[7:0] = beat count
            flags  = int(args[3], 16)
            desc_rows.append((src, dst, length, flags))

    for i, (src, dst, length, flags) in enumerate(desc_rows):
        dir_bit = flags & 1
        if dir_bit:
            # DIR=1: system memory → SRAM
            for beat in range(length):
                sw = (src >> 2) + beat
                dw = (dst >> 2) + beat
                got = final_sram[dw] if dw < len(final_sram) else None
                exp = init_smem[sw]  if sw < len(init_smem)  else None
                if got != exp:
                    print("DESC[%d] SRAM[%d]: got 0x%08x  exp 0x%08x" % (i, dw, got or 0, exp or 0))
                    errors += 1
        else:
            # DIR=0: SRAM → system memory.
            # Compare against final_sram — a prior descriptor may have written
            # to SRAM before this one reads it (chained scenario).
            for beat in range(length):
                sw = (src >> 2) + beat
                dw = (dst >> 2) + beat
                got = final_smem[dw]  if dw < len(final_smem)  else None
                exp = final_sram[sw]  if sw < len(final_sram)  else None
                if got != exp:
                    print("DESC[%d] SMEM[%d]: got 0x%08x  exp 0x%08x" % (i, dw, got or 0, exp or 0))
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
    parser = argparse.ArgumentParser(
        description="Serial host for DMA FPGA verification (Arty A7 + MicroBlaze)"
    )
    parser.add_argument("--port",          help="Serial port (e.g. /dev/tty.usbserial-XXX). Auto-detected if omitted.")
    parser.add_argument("--baud",          type=int, default=115200)
    parser.add_argument("--scenario",      default="scenarios/example.csv", help="Scenario CSV to run")
    parser.add_argument("--out-dir",       default="out", dest="out_dir")
    parser.add_argument("--timeout",       type=float, default=30.0, help="Seconds to wait for DMA completion")
    parser.add_argument("--poll-interval", type=float, default=0.1,  dest="poll_interval")
    parser.add_argument("--list-ports",    action="store_true", dest="list_ports", help="List available serial ports and exit")
    parser.add_argument("--dry-run",       action="store_true", dest="dry_run",    help="Run golden model only, no FPGA")
    parser.add_argument("--dry-run-all",   action="store_true", dest="dry_run_all",help="Dry-run all scenarios/*.csv")
    args = parser.parse_args()

    os.chdir(_here)  # run from sim/ so relative paths work

    if args.list_ports:
        list_ports()
        return

    if args.dry_run_all:
        passed, failed = dry_run_all("scenarios", args.out_dir)
        sys.exit(0 if failed == 0 else 1)

    if args.dry_run:
        ok = dry_run(args.scenario, args.out_dir)
        sys.exit(0 if ok else 1)

    # --- FPGA path ---
    stim_path = os.path.join(args.out_dir, "stim.txt")
    if not os.path.exists(stim_path):
        print("Generating golden artifacts for %s ..." % args.scenario)
        run_golden(args.scenario, args.out_dir)

    port = args.port or _find_arty_port()
    if not port:
        print("ERROR: No serial port found. Connect the Arty A7 or pass --port.")
        sys.exit(1)
    print("Opening %s at %d baud ..." % (port, args.baud))

    smem_path = os.path.join(args.out_dir, "initial_smem.hex")
    sram_path = os.path.join(args.out_dir, "initial_sram.hex")

    host = DMASerialHost(port, baud=args.baud)
    try:
        # 1. Pre-write initial memory contents (descriptor ring + data)
        host.send_initial_smem(smem_path)
        host.verify_smem_crc(smem_path)

        # 2. Pre-write initial SRAM contents
        host.send_initial_sram(sram_path)
        host.verify_sram_crc(sram_path)

        # 3. Send CSR writes (baseaddr, ringlen, tail, ctrl.enable)
        host.send_stim(stim_path)

        # 4. Wait for DMA to drain the ring
        host.wait_done(poll_interval=args.poll_interval, timeout=args.timeout)

        # 5. Check no error IRQ fired
        host.check_irq()
        print("*** PASS ***")
    except (RuntimeError, TimeoutError) as e:
        print("*** FAIL: %s ***" % e)
        sys.exit(1)
    finally:
        host.close()


if __name__ == "__main__":
    main()
