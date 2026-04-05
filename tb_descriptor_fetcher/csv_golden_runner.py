#!/usr/bin/env python3
#Read the csv file and run the descriptor fetcher software model
#Write the final contents of all the fifos to a hex file
#Write a txt file that the testbench sv file can read to load the stimulus
#Dont delete the header comments

from __future__ import print_function

import csv
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_source = os.path.join(_here, "source")
if _source not in sys.path:
    sys.path.insert(0, _source)

from descriptor_fetcher import pack_handle


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
    golden_df_in = []
    golden_dm_in = []

    for row in rows:
        p = _parse_row(row)
        if p is None:
            continue

        op, args = p
        a1 = args[0]

        if op == "rm":
            addr = int(a1, 16) & 0xFFFFFFFF
            h = pack_handle(addr, 4)
            stim_lines.append("rm %08x" % addr)
            golden_df_in.append(h)
        elif op == "cb":
            desc = int(a1, 16) & ((1 << 128) - 1)
            stim_lines.append("cb %032x" % desc)
            golden_dm_in.append(desc)
        else:
            raise ValueError("unknown op: %s" % op)

    return stim_lines, golden_df_in, golden_dm_in


def write_hex(path, words, hex_digits):
    fmt = "%%0%dx\n" % hex_digits
    with open(path, "w") as f:
        for w in words:
            f.write(fmt % w)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 csv_golden_runner.py scenarios/example.csv [out_dir]", file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "out")
    os.makedirs(out_dir, exist_ok=True)

    with open(csv_path, "r") as f:
        rows = list(csv.reader(f))

    stim_lines, golden_df_in, golden_dm_in = run_scenario(rows)

    stim_path = os.path.join(out_dir, "stim.txt")
    with open(stim_path, "w") as f:
        f.write("# generated from %s\n" % csv_path)
        for line in stim_lines:
            f.write(line + "\n")

    write_hex(os.path.join(out_dir, "golden_df_in.hex"), golden_df_in, 10)
    write_hex(os.path.join(out_dir, "golden_dm_in.hex"), golden_dm_in, 32)

    with open(os.path.join(out_dir, "summary.txt"), "w") as f:
        f.write("stim_lines=%d\n" % len(stim_lines))
        f.write("golden_df_in=%d\n" % len(golden_df_in))
        f.write("golden_dm_in=%d\n" % len(golden_dm_in))

    print("Wrote:", stim_path)
    print("Golden: df_in=%d dm_in=%d" % (len(golden_df_in), len(golden_dm_in)))


if __name__ == "__main__":
    main()
