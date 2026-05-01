# Random Scenario Generator

`sim/gen_random_tests.py` autogenerates randomized DMA scenario CSVs that match
the format consumed by `sim/run_golden.py` and `sim/tb_top.sv`.

## Run the generator

From the repo root:

```bash
# Generate 1 random scenario into sim/scenarios/ (default).
python3 sim/gen_random_tests.py

# Generate N scenarios.
python3 sim/gen_random_tests.py -n 10

# Reproducible run — per-file seed = base + index.
python3 sim/gen_random_tests.py -n 5 --seed 42

# Custom output directory and filename prefix.
python3 sim/gen_random_tests.py -n 3 --out-dir /tmp/foo --prefix smoke
```

### Flags

| Flag           | Default           | Meaning                                      |
| -------------- | ----------------- | -------------------------------------------- |
| `-n`, `--num`  | `1`               | Number of CSV files to generate.             |
| `--seed`       | random            | Base RNG seed; per-file seed = base + index. |
| `--out-dir`    | `sim/scenarios`   | Output directory.                            |
| `--prefix`     | `random`          | Filename prefix (`<prefix>_<i>_seed<s>.csv`).|

## Run a generated scenario through the golden model

```bash
cd sim
python3 run_golden.py scenarios/<generated>.csv out/<run_name>
```

This writes `initial_smem.hex`, `golden_smem.hex`, `initial_sram.hex`,
`golden_sram.hex`, `golden_descs.hex`, `stim.txt`, and `summary.txt` into the
output directory.

## Run a generated scenario in simulation

```bash
cd sim
make sim SCENARIO=scenarios/<generated>.csv
```

To run every scenario (including generated ones) and capture pass/fail in
`out/sim-all-report.txt`:

```bash
cd sim
make sim-all
```

## Constraints honored by the generator

- System memory: 1024 32-bit words (`SMEM_WORDS`).
- SRAM: 1024 32-bit words (`BRAM_SIZE`).
- Descriptor ring lives at byte 0 of system memory; each slot is 16 bytes;
  `ringlen = num_desc + 1` (one empty slot, matching `max_inflight.csv`).
- 1..`MAX_INFLIGHT` (=4) descriptors per scenario.
- Beats per descriptor: 1..16 (low byte of `LEN`).
- Random `DIR`; source region is preloaded (smem for `DIR=1`, sram for `DIR=0`).
- All `SRC` / `DST` regions are 4-byte aligned and non-overlapping with each
  other and with the descriptor ring.
