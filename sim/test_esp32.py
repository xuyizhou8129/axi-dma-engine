#!/usr/bin/env python3
"""
test_esp32.py — End-to-end test of serial_host.py against the ESP32 dummy.

Tests two layers:
  1. Protocol unit tests — verify every supported command type (csr_write,
     smem_write, sram_write, run_dma) gets an ACK with no exception.
  2. Scenario integration tests — run run_golden.py on each CSV scenario,
     then drive the full serial_host.py flow against the ESP32 and check
     PASS / FAIL.

Note: csr_read, smem_crc, sram_crc, wait_done, and check_irq are not
implemented in the binary protocol yet (firmware TODO). Those are skipped here.

Usage:
  python3 test_esp32.py --port /dev/tty.usbserial-XXXX
  python3 test_esp32.py --port /dev/tty.usbserial-XXXX --scenario scenarios/example.csv
  python3 test_esp32.py --list-ports

The ESP32 must be flashed with esp32_dummy/esp32_dummy.ino and connected via USB.
"""

from __future__ import print_function

import argparse
import glob
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _here)

from serial_host import DMASerialHost, run_golden, _find_arty_port

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
_passed = 0
_failed = 0


def _ok(name):
    global _passed
    _passed += 1
    print("  PASS  %s" % name)


def _fail(name, reason):
    global _failed
    _failed += 1
    print("  FAIL  %s — %s" % (name, reason))


def _try(name, fn):
    """Run fn(); PASS if no exception, FAIL with exception message."""
    try:
        fn()
        _ok(name)
    except Exception as e:
        _fail(name, str(e))


# ---------------------------------------------------------------------------
# Protocol unit tests
# ---------------------------------------------------------------------------

def test_protocol(host):
    """Exercise each supported command type and verify it ACKs cleanly."""
    print("\n[Protocol unit tests]")

    _try("csr_write BASEADDR",  lambda: host.csr_write(0x00, 0xDEADBEEF))
    _try("csr_write RINGLEN",   lambda: host.csr_write(0x04, 0x00000004))
    _try("csr_write TAIL",      lambda: host.csr_write(0x0C, 0x00000004))
    _try("csr_write CTRL",      lambda: host.csr_write(0x10, 0x00000001))

    _try("smem_write word 0",   lambda: host.smem_write(0x00, 0x12345678))
    _try("smem_write word 1",   lambda: host.smem_write(0x04, 0xAABBCCDD))

    _try("sram_write word 0",   lambda: host.sram_write(0x00, 0xCAFEBABE))
    _try("sram_write word 1",   lambda: host.sram_write(0x04, 0x0BADF00D))

    _try("run_dma",             lambda: host.run_dma())


# ---------------------------------------------------------------------------
# Scenario integration test
# ---------------------------------------------------------------------------

def test_scenario(host, scenario_csv, out_dir):
    """Run one CSV scenario end-to-end through serial_host.py against the ESP32."""
    name = os.path.basename(scenario_csv)
    print("\n[Scenario: %s]" % name)

    # Generate golden artifacts
    try:
        run_golden(scenario_csv, out_dir)
    except Exception as e:
        _fail(name + " golden", str(e))
        return

    smem_path = os.path.join(out_dir, "initial_smem.hex")
    sram_path = os.path.join(out_dir, "initial_sram.hex")
    stim_path = os.path.join(out_dir, "stim.txt")

    _try(name + " smem preload", lambda: host.send_initial_smem(smem_path))
    _try(name + " sram preload", lambda: host.send_initial_sram(sram_path))
    _try(name + " csr stim",     lambda: host.send_stim(stim_path))
    _try(name + " run_dma",      lambda: host.run_dma())


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Test serial_host.py against the ESP32 dummy firmware (binary protocol)"
    )
    parser.add_argument("--port",     help="Serial port for the ESP32 (auto-detected if omitted)")
    parser.add_argument("--baud",     type=int, default=9600)
    parser.add_argument("--csr-base", type=lambda x: int(x, 0), default=0x40000000, dest="csr_base")
    parser.add_argument("--smem-base",type=lambda x: int(x, 0), default=0x00000000, dest="smem_base")
    parser.add_argument("--sram-base",type=lambda x: int(x, 0), default=0x00010000, dest="sram_base")
    parser.add_argument("--scenario", help="Run a single scenario CSV (default: all scenarios/*.csv)")
    parser.add_argument("--out-dir",  default="out", dest="out_dir")
    parser.add_argument("--list-ports", action="store_true", dest="list_ports")
    args = parser.parse_args()

    os.chdir(_here)

    if args.list_ports:
        try:
            import serial.tools.list_ports
            for p in serial.tools.list_ports.comports():
                print(p.device, "—", p.description)
        except ImportError:
            print("pyserial not installed — run: pip install pyserial")
        return

    port = args.port or _find_arty_port()
    if not port:
        print("ERROR: No serial port found. Pass --port or check USB connection.")
        sys.exit(1)

    print("Connecting to ESP32 on %s at %d baud ..." % (port, args.baud))
    host = DMASerialHost(port, baud=args.baud, timeout=3.0,
                         csr_base_addr=args.csr_base,
                         smem_base_addr=args.smem_base,
                         sram_base_addr=args.sram_base)

    try:
        test_protocol(host)

        os.makedirs(args.out_dir, exist_ok=True)
        if args.scenario:
            test_scenario(host, args.scenario, args.out_dir)
        else:
            csvs = sorted(glob.glob("scenarios/*.csv"))
            # Skip error scenarios — ESP32 has no DMA engine so error behavior
            # is not meaningful here. Those are covered by --dry-run-all.
            normal = [c for c in csvs if not os.path.basename(c).startswith("error_")]
            for csv_path in normal:
                test_scenario(host, csv_path, args.out_dir)

    finally:
        host.close()

    print("\n=== Results: %d passed, %d failed ===" % (_passed, _failed))
    sys.exit(0 if _failed == 0 else 1)


if __name__ == "__main__":
    main()
