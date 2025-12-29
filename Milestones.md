# AXI DMA Engine + SRAM Controller + Interrupts — Milestones & Verification Plan

> Goal: Build a small memory-mapped DMA that moves data between AXI4 memory and on-chip SRAM,
> controlled via AXI4-Lite CSRs, with done/error interrupts, and robust backpressure handling.
> Descriptor ring (scatter-gather) is optional and comes *after* the basic DMA works.

---

## Assumptions / Scope (baseline)
- **Programming model (first 6 milestones):** CPU programs CSRs (SRC/DST/LEN/CTRL) over AXI-Lite, then sets `START`.
- **Data width:** start with 32-bit beats (easy). If you want byte-level later, add `WSTRB` + alignment rules.
- **Alignment rule (recommended early):** `SRC`, `DST`, `LEN` all 4-byte aligned; `LEN` multiple of 4.
- **DMA modes (choose 1 to start):**
  - **Memory-to-SRAM** (AXI4 read → SRAM write) and/or **SRAM-to-Memory** (SRAM read → AXI4 write)
  - (Optional) **Memory-to-Memory** (AXI4 read → internal FIFO → AXI4 write)
- **AXI:** support backpressure on all channels; start with **one outstanding burst at a time**.

---

## Repository / RTL Structure (suggested)
- `rtl/`
  - `dma_top.sv` (top-level wrapper)
  - `csr_axil.sv` (AXI-Lite register block)
  - `irq_ctrl.sv` (irq status/enable/w1c)
  - `dma_core.sv` (main FSM: start/busy/done/error; beat counters)
  - `axi_read_master.sv` (AR/R)
  - `axi_write_master.sv` (AW/W/B)
  - `sram_if.sv` (SRAM protocol adapter)
  - `fifo.sv` (optional small FIFO/buffer)
- `tb/`
  - `tb_top.sv` (testbench top)
  - `axi_lite_bfm.sv`
  - `axi_mem_model.sv` (AXI4 slave memory model)
  - `sram_model.sv`
  - `scoreboard.sv` (golden compare helpers)
  - `tests/` (directed SV tests per milestone)
- `docs/`
  - `spec.md` (register map + behavior)

---

## Verification Philosophy
- **Milestones 0–6:** simple, self-checking **SystemVerilog directed tests** + assertions.
- **Later (optional):** wrap BFMs into **UVM** for randomized stress / coverage closure.

---

# Milestone 0 — Spec + Testbench Skeleton
**Objective:** Build the harness first so every later step is measurable.

### Deliverables
- `docs/spec.md` with:
  - register map (addresses, reset values, R/W/W1C)
  - start/busy/done/error definition
  - alignment/length rules
- TB infrastructure:
  - AXI-Lite BFM (reg read/write)
  - AXI4 memory model (backing array)
  - SRAM model (backing array)
  - scoreboard helper: compare memory regions

### Tests
- `t_reg_smoke.sv` (writes/reads a dummy CSR; may stub DUT responses initially)

### Acceptance Criteria
- TB compiles and runs; you can poke CSRs and print reads.
- Scoreboard helper can compare arrays and report mismatches.

---

# Milestone 1 — CSR Block + Interrupts (no datapath yet)
**Objective:** CPU-visible device behavior works early.

### RTL
- `csr_axil.sv`
- `irq_ctrl.sv`
- `dma_top.sv` wires CSR + IRQ + stubbed core

### Must-have registers (example)
- `CTRL` (bit0 START, bit1 DIR, bit2 IRQ_EN_DONE, bit3 IRQ_EN_ERR)
- `SRC_ADDR`, `DST_ADDR`, `LEN`
- `STATUS` (bit0 BUSY, bit1 DONE, bit2 ERROR)
- `IRQ_STATUS` (W1C: DONE/ERROR sticky)

### Tests
- `t_csr_rw.sv`: reset defaults, R/W fields, RO fields, write mask
- `t_irq_w1c.sv`: force internal done/error → IRQ asserts → CPU clears via W1C

### Acceptance Criteria
- CSR reads/writes correct
- `START` latches command (even if core is stubbed)
- IRQ asserts and clears correctly

---

# Milestone 2 — DMA Core FSM (AXI-less functional copy engine)
**Objective:** Get correct copy behavior *without* full AXI complexity.

### RTL
- `dma_core.sv` implements:
  - latch `SRC/DST/LEN` on `START`
  - `BUSY` asserted during transfer
  - beat counter, done/error updates
- Connect DMA core to *simple* memory read/write tasks or internal models (non-AXI) for now.

### Tests
- `t_copy_1beat.sv`: copy 1 word, verify dst == src
- `t_copy_small.sv`: copy 16–64 words, verify
- `t_len0.sv`: `LEN=0` → immediate done (or defined behavior)

### Acceptance Criteria
- Correct data movement in simple model
- No deadlocks; busy clears; done sets

---

# Milestone 3 — SRAM Interface + Latency Handling
**Objective:** Make the SRAM side realistic and stable.

### RTL
- `sram_if.sv`: define SRAM protocol (1-cycle read latency recommended)
- DMA core updated to handle SRAM read latency / write enable timing

### Tests
- `t_sram_unit.sv`: direct SRAM reads/writes through `sram_if`
- `t_mem_to_sram.sv`: model-memory → SRAM copy
- `t_sram_to_mem.sv`: SRAM → model-memory copy

### Acceptance Criteria
- SRAM model contents match expected
- Latency is handled correctly (no off-by-one beats)

---

# Milestone 4 — AXI4 Read Master (AR/R) + Backpressure
**Objective:** Implement AXI4 read bursts robustly.

### RTL
- `axi_read_master.sv` supports:
  - configurable burst length (start with fixed like 16 beats, then compute from LEN)
  - INCR burst only
  - stalls on `ARREADY` and `RVALID`/`RREADY`
  - detect `RRESP` error → signal error up
- Connect to `axi_mem_model.sv` in TB

### Tests
- `t_axi_read_basic.sv`: burst read returns expected stream
- `t_axi_read_backpressure.sv`: random stalls on `ARREADY` and `RVALID`/`RREADY`
- `t_axi_read_error.sv`: inject `RRESP != OKAY` → ERROR + IRQ

### Acceptance Criteria
- Read data ordering correct under stalls
- Correct `RLAST` handling
- Error propagation works

---

# Milestone 5 — AXI4 Write Master (AW/W/B) + Backpressure
**Objective:** Implement AXI4 writes robustly.

### RTL
- `axi_write_master.sv` supports:
  - INCR bursts
  - stalls on `AWREADY`, `WREADY`, and `BVALID`/`BREADY`
  - detect `BRESP` error → signal error up
- Optional: implement `WSTRB=4'b1111` always (if word-aligned only)

### Tests
- `t_axi_write_basic.sv`: write burst, memory model matches expected
- `t_axi_write_backpressure.sv`: random stalls on AW/W/B
- `t_axi_write_error.sv`: inject `BRESP != OKAY` → ERROR + IRQ

### Acceptance Criteria
- No dropped/duplicated beats
- Correct burst termination
- Correct completion / error behavior

---

# Milestone 6 — Full Integration: CSR → DMA Core → AXI ↔ SRAM
**Objective:** The “real DMA” works end-to-end for single-command mode.

### RTL
- `dma_top.sv` fully wired:
  - CSR start → latch cmd → core orchestrates
  - AXI read/write masters + SRAM interface
  - small FIFO/buffer if needed to decouple channels

### Test Suite (minimum)
- `t_smoke_end2end.sv`: small copy, no stalls
- `t_end2end_multi_burst.sv`: large LEN requiring multiple bursts
- `t_end2end_random_stalls.sv`: random stalls on all AXI channels + SRAM ready if applicable
- `t_end2end_random_params.sv`: random aligned SRC/DST/LEN combos

### Acceptance Criteria
- Scoreboard passes for all tests
- No deadlocks across 100+ randomized transfers
- IRQ done/error behavior correct; W1C clears reliably

---

## Optional Milestone 7 — Descriptor Ring (Scatter-Gather)
**Objective:** Add autonomous sequencing for higher “real DMA” feel.

### RTL Additions
- `desc_fetcher.sv`: fetch descriptor(s) via AXI4 from memory
- `ring_mgr.sv`: head/tail, ownership bits, chaining, per-desc status
- CSR extensions: ring base addr, head/tail, enable

### Descriptor Format (example)
- `SRC`, `DST`, `LEN`, `CTRL`, `NEXT` (or implicit ring stride)

### Tests
- `t_desc_chain_3.sv`: 3 descriptors chained, verify all copies
- `t_desc_error.sv`: bad desc → ERROR + IRQ
- `t_desc_backpressure.sv`: stalls during descriptor fetch + data move

### Acceptance Criteria
- Executes a ring without CPU reprogramming each transfer
- Correct per-descriptor + global done/error semantics

---

## “Done” Definition (recommended)
- `DONE` becomes 1 when the programmed LEN bytes have been fully written
  - for AXI writes: after the final `B` response is received
- `ERROR` sticky on any AXI `RRESP/BRESP != OKAY` (and optionally on misalignment/illegal LEN)
- `BUSY` asserted from accepted `START` until `DONE` or `ERROR`

---

## Team Split (4–5 people example)
- Person A: CSR AXI-Lite + IRQ + spec
- Person B: DMA core FSM + counters + command latch
- Person C: AXI read master + tests
- Person D: AXI write master + tests
- Person E (optional): SRAM IF + FIFO + integration glue

---

## Minimal Regression List (what you run every time)
1. `t_csr_rw`
2. `t_irq_w1c`
3. `t_copy_1beat`
4. `t_end2end_multi_burst`
5. `t_end2end_random_stalls` (short: ~20 transfers)
6. `t_end2end_random_params` (short)

---

## Notes (avoid common traps)
- Latch SRC/DST/LEN on START; don’t let CPU writes mid-transfer change behavior.
- Start with **one outstanding burst**. Multiple outstanding adds complexity quickly.
- Make errors sticky; require W1C clear.
- Add assertions early: handshake stability and beat count invariants.
