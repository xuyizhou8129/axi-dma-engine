#!/usr/bin/env python3
"""
Auto-generate randomized DMA scenario CSVs under sim/scenarios/.

Each generated CSV follows the format consumed by run_golden.py / tb_top.sv:
  smem,<word_idx>,<hex_data>          preload system memory
  sram,<word_idx>,<hex_data>          preload SRAM
  csr_baseaddr,<hex_addr>             ring base in system memory
  csr_ringlen,<decimal_len>           ring slots (>= num_desc + 1)
  desc,SRC,DST,LEN,FLAGS              descriptor (DIR=FLAGS[0])
  enable

Constraints honored (see sim/run_golden.py, source/sram.py):
  - SMEM_WORDS = 1024  (system memory size in 32-bit words; byte addrs 0..0xFFC)
  - BRAM_SIZE  = 1024  (SRAM size in 32-bit words)
  - Descriptors are 16 bytes; ring occupies csr_baseaddr ..
    csr_baseaddr + 16*ringlen-1 in system memory and must not overlap data.
  - SRC / DST byte addresses are 4-byte aligned.
  - LEN low byte (beats) > 0; we cap at 16 beats per descriptor.

Usage:
  python3 gen_random_tests.py [-n N] [--out-dir DIR] [--seed S] [--prefix P]
"""

from __future__ import print_function

import argparse
import os
import random


SMEM_WORDS = 1024
SRAM_WORDS = 1024
MAX_INFLIGHT = 4         # matches RTL; ringlen must allow num_desc <= MAX_INFLIGHT
MAX_BEATS = 16           # cap per-descriptor length to keep regions small


def _hex32(v):
    return "{:08x}".format(v & 0xFFFFFFFF)


def _byte_addr_to_word(byte_addr):
    return byte_addr >> 2


def _ranges_overlap(a_start, a_len, b_start, b_len):
    return not (a_start + a_len <= b_start or b_start + b_len <= a_start)


def _pick_region(reserved, region_words, mem_words, rng):
    """
    Pick a 4-byte-aligned start word for a contiguous region of `region_words`
    that does not overlap any (start_word, len_words) in `reserved` and stays
    in [0, mem_words). Returns the chosen start word, or None if no fit found.
    """
    for _ in range(64):
        start = rng.randint(0, mem_words - region_words)
        if all(not _ranges_overlap(start, region_words, s, l) for s, l in reserved):
            return start
    return None


def _gen_scenario(rng):
    """
    Build the list of CSV rows (each row is a list of fields) plus a short
    human-readable summary used in the comment block.
    """
    num_desc = rng.randint(1, MAX_INFLIGHT)
    ring_slots = num_desc + 1                         # leave one empty slot
    ring_words = ring_slots * 4                       # 16 bytes per slot

    # Place ring at byte 0 of system memory (matches existing scenarios).
    ring_start_word = 0
    smem_reserved = [(ring_start_word, ring_words)]
    sram_reserved = []

    descriptors = []          # (src_byte, dst_byte, beats, dir_bit)
    smem_preloads = {}        # word_idx -> 32-bit value
    sram_preloads = {}

    for _ in range(num_desc):
        beats = rng.randint(1, MAX_BEATS)
        dir_bit = rng.randint(0, 1)

        if dir_bit == 1:
            # smem -> sram: SRC in smem, DST in sram. Preload SRC in smem.
            src_word = _pick_region(smem_reserved, beats, SMEM_WORDS, rng)
            dst_word = _pick_region(sram_reserved, beats, SRAM_WORDS, rng)
            if src_word is None or dst_word is None:
                continue
            smem_reserved.append((src_word, beats))
            sram_reserved.append((dst_word, beats))
            for i in range(beats):
                smem_preloads[src_word + i] = rng.randint(0, 0xFFFFFFFF)
        else:
            # sram -> smem: SRC in sram, DST in smem. Preload SRC in sram.
            src_word = _pick_region(sram_reserved, beats, SRAM_WORDS, rng)
            dst_word = _pick_region(smem_reserved, beats, SMEM_WORDS, rng)
            if src_word is None or dst_word is None:
                continue
            sram_reserved.append((src_word, beats))
            smem_reserved.append((dst_word, beats))
            for i in range(beats):
                sram_preloads[src_word + i] = rng.randint(0, 0xFFFFFFFF)

        descriptors.append((src_word << 2, dst_word << 2, beats, dir_bit))

    if not descriptors:
        # Fall back to a tiny safe descriptor so we never emit an empty scenario.
        descriptors = [(0x100, 0x100, 4, 1)]
        for i in range(4):
            smem_preloads[64 + i] = rng.randint(0, 0xFFFFFFFF)
        ring_slots = 2

    return descriptors, smem_preloads, sram_preloads, ring_start_word, ring_slots


def _format_csv(descriptors, smem_preloads, sram_preloads,
                ring_start_word, ring_slots):
    lines = []
    lines.append("op,arg1,arg2,arg3,arg4")
    lines.append("# =============================================================================")
    lines.append("# Auto-generated scenario (gen_random_tests.py)")
    lines.append("#")
    lines.append("# Descriptor ring in system memory:")
    lines.append("#   Ring start byte address = 0x{:08x}".format(ring_start_word << 2))
    lines.append("#   Ring length             = {} slots ({} bytes)".format(
        ring_slots, ring_slots * 16))
    lines.append("# Number of descriptors: {}".format(len(descriptors)))
    lines.append("#")
    for i, (src, dst, beats, dir_bit) in enumerate(descriptors):
        if dir_bit:
            src_loc, dst_loc = "system memory", "SRAM"
        else:
            src_loc, dst_loc = "SRAM", "system memory"
        lines.append(
            "# Descriptor {}: move {} beat(s) from {} 0x{:08x} to {} 0x{:08x} (DIR={})".format(
                i, beats, src_loc, src, dst_loc, dst, dir_bit))
    lines.append("# =============================================================================")
    lines.append("")

    if smem_preloads:
        lines.append("# --- System memory preload ---")
        for idx in sorted(smem_preloads):
            lines.append("smem,{},{},,".format(idx, _hex32(smem_preloads[idx])))
        lines.append("")

    if sram_preloads:
        lines.append("# --- SRAM preload ---")
        for idx in sorted(sram_preloads):
            lines.append("sram,{},{},,".format(idx, _hex32(sram_preloads[idx])))
        lines.append("")

    lines.append("# --- Configure ring ---")
    lines.append("csr_baseaddr,{},,".format(_hex32(ring_start_word << 2)))
    lines.append("csr_ringlen,{},,".format(ring_slots))
    lines.append("")

    lines.append("# SRC, DST, LEN, FLAGS — see docs/descriptor_struct.md")
    for src, dst, beats, dir_bit in descriptors:
        lines.append("desc,{},{},{},{}".format(
            _hex32(src), _hex32(dst), _hex32(beats), _hex32(dir_bit)))
    lines.append("")
    lines.append("enable,,,,")
    return "\n".join(lines) + "\n"


def main():
    p = argparse.ArgumentParser(description="Generate randomized DMA scenario CSVs.")
    p.add_argument("-n", "--num", type=int, default=1,
                   help="Number of CSV files to generate (default: 1).")
    p.add_argument("--out-dir", default=os.path.join(os.path.dirname(__file__), "scenarios"),
                   help="Output directory (default: sim/scenarios).")
    p.add_argument("--prefix", default="random",
                   help="Filename prefix (default: 'random').")
    p.add_argument("--seed", type=int, default=None,
                   help="Base RNG seed; per-file seed = base + index.")
    args = p.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    base_seed = args.seed if args.seed is not None else random.randint(0, 2**31 - 1)

    for i in range(args.num):
        rng = random.Random(base_seed + i)
        descriptors, smem_pre, sram_pre, ring_start, ring_slots = _gen_scenario(rng)
        text = _format_csv(descriptors, smem_pre, sram_pre, ring_start, ring_slots)
        fname = "{}_{:04d}_seed{}.csv".format(args.prefix, i, base_seed + i)
        path = os.path.join(args.out_dir, fname)
        with open(path, "w") as f:
            f.write(text)
        print("wrote", path)


if __name__ == "__main__":
    main()
