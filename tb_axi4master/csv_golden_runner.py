#!/usr/bin/env python3
"""
Read scenario CSV, run AXI4MasterGolden, emit SV-friendly artifacts.

  out/stim.txt          — stimulus for tb_axi_4_master.sv
  out/initial_mem.hex   — memory after all CSV rows applied (before DUT runs)
  out/golden_mem.hex    — memory after golden drains all transactions
  out/golden_df_out.hex — one 32-digit hex line per descriptor (128 bits)
  out/golden_mid.hex    — expected MID words produced by DM read ops (in order)

Usage:
  python3 csv_golden_runner.py scenarios/example.csv [out_dir]
"""

from __future__ import print_function

import csv
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_source = os.path.join(_here, "source")
if _source not in sys.path:
    sys.path.insert(0, _source)

from fifo_queue import FIFOQueue
from memory import SystemMemory
from axi_4_master import AXI4MasterGolden, pack_handle, pack_instruction


def _parse_row(row):
    if not row or not row[0]:
        return None
    raw = row[0].strip()
    if not raw or raw.startswith("#"):
        return None
    op = raw.lower()
    if op == "op":
        return None
    return op, [c.strip() for c in row[1:4]]


def run_scenario(rows, mem_size=256):
    mem = SystemMemory(size=mem_size)
    df_in = FIFOQueue("df_in", 64)
    df_out = FIFOQueue("df_out", 64)
    dm_in = FIFOQueue("dm_in", 64)
    mid = FIFOQueue("mid", 64)
    golden = AXI4MasterGolden(mem, df_in, df_out, dm_in, mid)

    stim_lines = []

    for row in rows:
        p = _parse_row(row)
        if p is None:
            continue
        op, args = p
        a1, a2 = args[0], args[1]

        if op == "mem":
            wi = int(a1, 10)
            data = int(a2, 16) & 0xFFFFFFFF
            mem.mem[wi] = data
            stim_lines.append("mem %d %08x" % (wi, data))
        elif op == "handle":
            byte_addr = int(a1, 16)
            ln = int(a2, 10)
            df_in.enqueue(pack_handle(byte_addr, ln))
            stim_lines.append("handle %08x %d" % (byte_addr, ln))
        elif op == "mid":
            w = int(a1, 16) & 0xFFFFFFFF
            mid.enqueue(w)
            stim_lines.append("mid %08x" % w)
        elif op == "dm_rd":
            byte_addr = int(a1, 16)
            ln = int(a2, 10)
            dm_in.enqueue(pack_instruction(byte_addr, ln, False))
            stim_lines.append("dm_rd %08x %d" % (byte_addr, ln))
        elif op == "dm_wr":
            byte_addr = int(a1, 16)
            ln = int(a2, 10)
            dm_in.enqueue(pack_instruction(byte_addr, ln, True))
            stim_lines.append("dm_wr %08x %d" % (byte_addr, ln))
        else:
            raise ValueError("unknown op: %s" % op)

    initial_snapshot = list(mem.mem)

    golden_df = []
    golden_mid = []
    pl_df = len(df_out.buffer)
    pl_mid = len(mid.buffer)

    while True:
        ran = golden.process_one()
        if not ran:
            break
        nl_df = len(df_out.buffer)
        if nl_df > pl_df:
            golden_df.extend(df_out.buffer[pl_df:nl_df])
            pl_df = nl_df
        nl_mid = len(mid.buffer)
        if nl_mid > pl_mid:
            golden_mid.extend(mid.buffer[pl_mid:nl_mid])
            pl_mid = nl_mid

    return stim_lines, initial_snapshot, list(mem.mem), golden_df, golden_mid


def write_hex_file(path, words):
    with open(path, "w") as f:
        for w in words:
            f.write("%08x\n" % (w & 0xFFFFFFFF))


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    csv_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "out")
    os.makedirs(out_dir, exist_ok=True)

    with open(csv_path, "r") as f:
        reader = csv.reader(f)
        rows = list(reader)

    stim_lines, initial_snapshot, final_mem, golden_df, golden_mid = run_scenario(rows)

    stim_path = os.path.join(out_dir, "stim.txt")
    with open(stim_path, "w") as f:
        f.write("# generated from %s\n" % csv_path)
        for line in stim_lines:
            f.write(line + "\n")

    write_hex_file(os.path.join(out_dir, "initial_mem.hex"), initial_snapshot)
    write_hex_file(os.path.join(out_dir, "golden_mem.hex"), final_mem)

    with open(os.path.join(out_dir, "golden_df_out.hex"), "w") as f:
        for p in golden_df:
            f.write("%032x\n" % (p & ((1 << 128) - 1)))

    write_hex_file(os.path.join(out_dir, "golden_mid.hex"), golden_mid)

    with open(os.path.join(out_dir, "summary.txt"), "w") as f:
        f.write("stim_lines=%d\n" % len(stim_lines))
        f.write("golden_df_out=%d\n" % len(golden_df))
        f.write("golden_mid_words=%d\n" % len(golden_mid))

    print("Wrote:", stim_path)
    print("Golden: df_out=%d mid=%d" % (len(golden_df), len(golden_mid)))


if __name__ == "__main__":
    main()
