#!/usr/bin/env python3
"""
test_esp32.py — End-to-end test of serial_host.py against the ESP32 dummy.

Tests two layers:
  1. Protocol unit tests — verify every command type (W, R, SMEM_W, SRAM_W,
     SMEM_CRC, SRAM_CRC) with known values and check responses.
  2. Scenario integration tests — run run_golden.py on each CSV scenario,
     then drive the full serial_host.py flow against the ESP32 and check
     PASS / FAIL.

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
import struct
import sys
import zlib

_here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _here)

from serial_host import DMASerialHost, _load_hex32, _crc32_words, run_golden, _find_arty_port

# Test runner
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


def _check(name, got, expected):
    if got == expected:
        _ok(name)
    else:
        _fail(name, "got %r  expected %r" % (got, expected))


# Protocol unit tests
def test_protocol(host):
    """Exercise each command type with known values."""
    print("\n[Protocol unit tests]")

    # W / R round-trip on a couple of CSR offsets
    host.csr_write(0x00, 0xDEADBEEF)
    val = host.csr_read(0x00)
    _check("W/R baseaddr round-trip", val, 0xDEADBEEF)

    host.csr_write(0x04, 0x00000004)
    _check("W/R ringlen round-trip", host.csr_read(0x04), 0x00000004)

    # STATUS (0x14) always returns done (ring_empty=1, busy=0)
    status = host.csr_read(0x14)
    ring_empty = bool((status >> 1) & 1)
    busy       = bool((status >> 0) & 1)
    _check("STATUS ring_empty=1", ring_empty, True)
    _check("STATUS busy=0",       busy,       False)

    # IRQ_STATUS (0x18) should be 0 (no errors)
    _check("IRQ_STATUS is 0", host.csr_read(0x18), 0)

    # SMEM_W: write a known word and verify via CRC
    host.smem_write(0x00, 0x12345678)
    host.smem_write(0x04, 0xAABBCCDD)

    # SRAM_W round-trip via CRC check below
    host.sram_write(0x00, 0xCAFEBABE)
    host.sram_write(0x04, 0x0BADF00D)

    # Build expected CRC for a 1024-word smem with words[0]=0x12345678, [1]=0xAABBCCDD
    smem_expected = [0] * 1024
    smem_expected[0] = 0x12345678
    smem_expected[1] = 0xAABBCCDD
    exp_smem_crc = _crc32_words(smem_expected)
    got_smem_crc = host.smem_crc()
    _check("SMEM_CRC after two writes", got_smem_crc, exp_smem_crc)

    sram_expected = [0] * 1024
    sram_expected[0] = 0xCAFEBABE
    sram_expected[1] = 0x0BADF00D
    exp_sram_crc = _crc32_words(sram_expected)
    got_sram_crc = host.sram_crc()
    _check("SRAM_CRC after two writes", got_sram_crc, exp_sram_crc)


# Scenario integration test
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

    try:
        # Pre-write memories
        host.send_initial_smem(smem_path)
        host.verify_smem_crc(smem_path)
        _ok(name + " smem preload + CRC")

        host.send_initial_sram(sram_path)
        host.verify_sram_crc(sram_path)
        _ok(name + " sram preload + CRC")

        # CSR stimulus
        host.send_stim(stim_path)

        # Wait for DMA done (ESP32 dummy always reports done immediately)
        host.wait_done(poll_interval=0.05, timeout=5.0)
        _ok(name + " wait_done")

        # IRQ check
        host.check_irq()
        _ok(name + " check_irq")

    except Exception as e:
        _fail(name, str(e))


# Main
def main():
    parser = argparse.ArgumentParser(
        description="Test serial_host.py against the ESP32 dummy firmware"
    )
    parser.add_argument("--port",     help="Serial port for the ESP32 (auto-detected if omitted)")
    parser.add_argument("--baud",     type=int, default=115200)
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
    host = DMASerialHost(port, baud=args.baud, timeout=3.0)

    try:
        # Unit tests first
        test_protocol(host)

        # Scenario integration tests
        os.makedirs(args.out_dir, exist_ok=True)
        if args.scenario:
            test_scenario(host, args.scenario, args.out_dir)
        else:
            csvs = sorted(glob.glob("scenarios/*.csv"))
            # Skip error scenarios — ESP32 dummy has no DMA engine, so error
            # IRQ checks would not make sense here. They are covered by --dry-run-all.
            normal = [c for c in csvs if not os.path.basename(c).startswith("error_")]
            for csv_path in normal:
                test_scenario(host, csv_path, args.out_dir)

    finally:
        host.close()

    print("\n=== Results: %d passed, %d failed ===" % (_passed, _failed))
    sys.exit(0 if _failed == 0 else 1)


if __name__ == "__main__":
    main()
