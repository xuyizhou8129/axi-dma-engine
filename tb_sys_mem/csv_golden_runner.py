#!/usr/bin/env python3
# Read the CSV scenario file and run the sys_mem software model.
# Write stim.txt (loaded by the SV testbench) and golden_rd.hex (expected rdata beats).

from __future__ import print_function

import csv
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_source = os.path.join(_here, "source")
if _source not in sys.path:
    sys.path.insert(0, _source)

from sys_mem_model import SysMemModel


def _parse_row(row):
    if not row or not row[0]:
        return None
    op = row[0].strip().lower()
    if (not op) or op.startswith("#") or op == "op":
        return None
    args = [c.strip() for c in row[1:4]]
    return op, args


def run_scenario(rows):
    stim_lines = []
    golden_rd = []
    model = SysMemModel(mem_words=256)

    for row in rows:
        p = _parse_row(row)
        if p is None:
            continue

        op, args = p

        if op == "wr":
            byte_addr = int(args[0], 16) & 0xFFFFFFFF
            data = int(args[1], 16) & 0xFFFFFFFF
            model.write(byte_addr, data)
            stim_lines.append("wr %08x %08x" % (byte_addr, data))

        elif op == "rd":
            byte_addr = int(args[0], 16) & 0xFFFFFFFF
            arlen = int(args[1], 16) & 0xFF
            beats = model.read_burst(byte_addr, arlen)
            golden_rd.extend(beats)
            stim_lines.append("rd %08x %02x" % (byte_addr, arlen))

        else:
            raise ValueError("unknown op: %s" % op)

    return stim_lines, golden_rd


def write_hex(path, words, hex_digits):
    fmt = "%%0%dx\n" % hex_digits
    with open(path, "w") as f:
        for w in words:
            f.write(fmt % w)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 csv_golden_runner.py scenarios/example.csv [out_dir]",
              file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "out")
    os.makedirs(out_dir, exist_ok=True)

    with open(csv_path, "r") as f:
        rows = list(csv.reader(f))

    stim_lines, golden_rd = run_scenario(rows)

    stim_path = os.path.join(out_dir, "stim.txt")
    with open(stim_path, "w") as f:
        f.write("# generated from %s\n" % csv_path)
        for line in stim_lines:
            f.write(line + "\n")

    write_hex(os.path.join(out_dir, "golden_rd.hex"), golden_rd, 8)

    with open(os.path.join(out_dir, "summary.txt"), "w") as f:
        f.write("stim_lines=%d\n" % len(stim_lines))
        f.write("golden_rd=%d\n" % len(golden_rd))

    print("Wrote:", stim_path)
    print("Golden: rd_beats=%d" % len(golden_rd))


if __name__ == "__main__":
    main()
