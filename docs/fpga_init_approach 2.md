# FPGA Memory Preload Architecture

## Problem Statement

When `vivado_config` is packaged as a Vivado IP block, MicroBlaze cannot directly
preload data into `sys_mem` (system memory) or `bram` (SRAM) before the DMA engine
starts. MicroBlaze also needs to read back memory contents after DMA completes for
CRC32 comparison. This document describes the chosen solution with minimum changes
to existing RTL files.

---

## Chosen Solution

### Guiding Principle

Both `bram.sv` and `sys_mem.sv` each gain a simple, symmetric direct-access port
(address / data / wr_en / rdata — no AXI handshaking). A single shared AXI-Lite
controller (`mem_access_ctrl`) sits inside `vivado_config`, translates MicroBlaze
AXI-Lite transactions into those plain signals, and handles both memories through
one address space. All other existing RTL files are unchanged.

---

## Symmetric Init Port Design

### Both memories get the same port style

`bram.sv` already has a simple SRAM-style port (`rd_addr`, `wr_addr`, `wr_en`,
`din`, `dout`). `sys_mem.sv` gets an equivalent secondary port added alongside
its existing AXI4 slave port.

```
MicroBlaze (AXI-Lite)
        │
        ▼
  mem_access_ctrl  (new AXI-Lite slave, inside vivado_config.sv)
  registers: INIT_ADDR, INIT_DATA, SRAM_WR, SRAM_RD, MEM_WR, MEM_RD, INIT_DONE
        │                          │
        │  plain wires             │  plain wires
        ▼                          ▼
  bram.init_*                sys_mem.init_*
  (new port on bram.sv)      (new port on sys_mem.sv)
        │                          │
        ▼                          ▼
  bram mem[] array           sys_mem ram[] array
  (same array sram_ctrl      (same array AXI port
   already accesses)          already accesses)
```

---

## Change 1: `bram.sv` — add init port

`bram.sv` currently has one set of read/write ports driven exclusively by
`sram_controller`. Add a second independent port for init access:

```systemverilog
module bram #(
    parameter BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter BRAM_SIZE       = dma_pkg::BRAM_SIZE,
    localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
) (
    input  logic clock,

    // Existing port — used by sram_controller during DMA operation (unchanged)
    input  logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
    input  logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
    input  logic                       wr_en,
    input  logic [BRAM_DATA_WIDTH-1:0] din,
    output logic [BRAM_DATA_WIDTH-1:0] dout,

    // New init port — used by mem_access_ctrl for preload and readback
    input  logic [BRAM_ADDR_WIDTH-1:0] init_addr,
    input  logic                       init_wr_en,
    input  logic [BRAM_DATA_WIDTH-1:0] init_din,
    output logic [BRAM_DATA_WIDTH-1:0] init_dout
);

    (* syn_ramstyle = "block_ram" *)
    logic [BRAM_SIZE-1:0][BRAM_DATA_WIDTH-1:0] mem;
    logic [BRAM_ADDR_WIDTH-1:0] read_addr;
    logic [BRAM_ADDR_WIDTH-1:0] init_read_addr;

    // Existing read path (unchanged)
    assign dout = mem[read_addr];

    // New init read path
    assign init_dout = mem[init_read_addr];

    always_ff @(posedge clock) begin
        // Existing write path (unchanged)
        read_addr <= rd_addr;
        if (wr_en) mem[wr_addr] <= din;

        // New init write path
        init_read_addr <= init_addr;
        if (init_wr_en) mem[init_addr] <= init_din;
    end

endmodule
```

**Why no arbitration needed:** `init_wr_en` and `wr_en` are never asserted
simultaneously. `init_done` (a register in `mem_access_ctrl`) must be set before
any DMA descriptor is submitted, enforced by firmware sequencing.

---

## Change 2: `sys_mem.sv` — add init port

Add a secondary direct-access port alongside the existing AXI4 slave port:

```systemverilog
module sys_mem #(
    parameter int MEM_WORDS  = 256,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH
) (
    axi_4_if.slave axi,

    // New init port — used by mem_access_ctrl for preload and readback
    input  logic                    init_wr_en,
    input  logic [ADDR_WIDTH-1:0]   init_addr,
    input  logic [DATA_WIDTH-1:0]   init_wdata,
    output logic [DATA_WIDTH-1:0]   init_rdata
);

    logic [DATA_WIDTH-1:0] ram[0:MEM_WORDS-1];

    // New init port logic
    assign init_rdata = ram[init_addr >> 2];   // combinational read — valid next cycle after addr stable

    always_ff @(posedge axi.clk) begin
        if (init_wr_en)
            ram[init_addr >> 2] <= init_wdata;
    end

    // ... rest of existing AXI FSM completely unchanged ...
```

**Read timing:** `init_rdata` is a registered read (one cycle latency from
`init_addr` being presented). `mem_access_ctrl` samples it on the AXI read
response cycle — no wait states needed.

---

## Change 3: `mem_access_ctrl` — new AXI-Lite slave (inside `vivado_config.sv`)

This module has exactly the same structure as `csr.sv`: an AXI-Lite slave that
latches writes into registers and drives outputs as plain wires. It is not a
standalone file — it is instantiated as a submodule inside `vivado_config.sv`.

### Register Map

| Offset | Register    | R/W | Function |
|--------|-------------|-----|----------|
| `0x00` | `INIT_ADDR` | R/W | Target byte address for next read or write |
| `0x04` | `INIT_DATA` | R/W | Data to write; holds last written value |
| `0x08` | `SRAM_WR`   | W   | Write 1 → pulse `bram.init_wr_en` for one cycle |
| `0x0C` | `SRAM_RD`   | W   | Write 1 → latch `bram.init_dout` into `RDATA` reg |
| `0x10` | `MEM_WR`    | W   | Write 1 → pulse `sys_mem.init_wr_en` for one cycle |
| `0x14` | `MEM_RD`    | W   | Write 1 → latch `sys_mem.init_rdata` into `RDATA` reg |
| `0x18` | `RDATA`     | R   | Read-only; holds last captured readback value |
| `0x1C` | `INIT_DONE` | R/W | Write 1 → signal preload complete (DMA may now start) |

### Connections to memory ports

```systemverilog
// Inside vivado_config.sv — wiring mem_access_ctrl to bram and sys_mem

mem_access_ctrl u_mem_init (
    .axil          (s_axil_init),      // second AXI-Lite slave port on vivado_config

    // bram init port
    .bram_init_addr   (bram_init_addr),
    .bram_init_wr_en  (bram_init_wr_en),
    .bram_init_din    (bram_init_din),
    .bram_init_dout   (bram_init_dout),

    // sys_mem init port
    .mem_init_addr    (mem_init_addr),
    .mem_init_wr_en   (mem_init_wr_en),
    .mem_init_wdata   (mem_init_wdata),
    .mem_init_rdata   (mem_init_rdata),

    .init_done        (init_done)
);
```

---

## Vivado Block Design

```
MicroBlaze (M_AXI_DP)
        │
        ▼
AXI Interconnect (1M : 2S)
    ├── S0 (e.g. 0x43C0_0000) → vivado_config.s_axil_*       (DMA CSR, existing)
    └── S1 (e.g. 0x43C1_0000) → vivado_config.s_axil_init_*  (mem_access_ctrl, new)

vivado_config IP block (internal hierarchy)
    ├── dma_top
    │       └── movement_top
    │               ├── sram_controller  (unchanged, drives bram existing port)
    │               └── u_bram           (unchanged instantiation location)
    ├── sys_mem      (+ new init port)
    └── mem_access_ctrl  (new)
```

Note: `bram` stays inside `movement_top` — no structural lift-out needed. The
init port signals are threaded up through `movement_top` and `dma_top` as
additional ports (port addition only, no logic change in those files).

---

## Firmware Sequence (Vitis C)

```c
#define CSR_BASE    0x43C00000
#define INIT_BASE   0x43C10000

#define INIT_ADDR   (INIT_BASE + 0x00)
#define INIT_DATA   (INIT_BASE + 0x04)
#define SRAM_WR     (INIT_BASE + 0x08)
#define SRAM_RD     (INIT_BASE + 0x0C)
#define MEM_WR      (INIT_BASE + 0x10)
#define MEM_RD      (INIT_BASE + 0x14)
#define RDATA       (INIT_BASE + 0x18)
#define INIT_DONE   (INIT_BASE + 0x1C)

// 1. Preload SRAM (bram)
for (int i = 0; i < SRAM_N; i++) {
    *(volatile uint32_t*)INIT_ADDR = i * 4;
    *(volatile uint32_t*)INIT_DATA = sram_src[i];
    *(volatile uint32_t*)SRAM_WR   = 1;
}

// 2. Preload system memory
for (int i = 0; i < MEM_N; i++) {
    *(volatile uint32_t*)INIT_ADDR = i * 4;
    *(volatile uint32_t*)INIT_DATA = mem_src[i];
    *(volatile uint32_t*)MEM_WR    = 1;
}

// 3. Signal init complete — bram and sys_mem now owned by DMA
*(volatile uint32_t*)INIT_DONE = 1;

// 4. Program DMA and run
*(volatile uint32_t*)(CSR_BASE + REG_BASEADDR) = descriptor_ring_addr;
*(volatile uint32_t*)(CSR_BASE + REG_RINGLEN)  = ring_len;
*(volatile uint32_t*)(CSR_BASE + REG_TAIL)     = tail;
*(volatile uint32_t*)(CSR_BASE + REG_CTRL)     = 0x5;  // ENABLE | IRQ_EN

// 5. Wait for IRQ / poll STATUS

// 6. Readback for CRC32 comparison
for (int i = 0; i < SRAM_N; i++) {
    *(volatile uint32_t*)INIT_ADDR = i * 4;
    *(volatile uint32_t*)SRAM_RD   = 1;
    sram_result[i] = *(volatile uint32_t*)RDATA;
}
for (int i = 0; i < MEM_N; i++) {
    *(volatile uint32_t*)INIT_ADDR = i * 4;
    *(volatile uint32_t*)MEM_RD    = 1;
    mem_result[i] = *(volatile uint32_t*)RDATA;
}

// 7. Compute CRC32 on sram_result[] and mem_result[], send over UART
```

---

## File Change Summary

| File | Change | Scope |
|------|--------|-------|
| `bram.sv` | Add init port (addr, wr_en, din, dout) | ~10 lines additive |
| `sys_mem.sv` | Add init port (addr, wr_en, wdata, rdata) | ~6 lines additive |
| `movement_top.sv` | Thread bram init signals out as ports | Port addition, no logic change |
| `dma_top.sv` | Thread bram init signals out as ports | Port addition, no logic change |
| `vivado_config.sv` | Add `mem_access_ctrl` instance + flat ports + wiring | New logic |
| `mem_access_ctrl.sv` | **New file** — AXI-Lite slave, same structure as `csr.sv` | New |
| `sram_controller.sv` | **Zero changes** | — |
| `axi_4_if.sv` | **Zero changes** | — |
| `csr.sv` | **Zero changes** | — |
| `dma_pkg.sv` | **Zero changes** | — |

---

## Key Design Constraints

1. **Never use both ports simultaneously on the same memory.**
   The `init_done` register enforces phasing: init phase first, DMA phase second,
   readback phase third. Firmware must respect this order.

2. **`init_done` must be set before writing DMA CSR CTRL.ENABLE.**
   Once `init_done` is asserted, `mem_access_ctrl` should refuse further write
   pulses (or firmware simply never issues them).

3. **All init read/writes are full 32-bit words.** Byte/halfword operations are
   not supported through the init port. This matches the DMA engine's own behavior.

4. **Read latency:** `SRAM_RD` / `MEM_RD` trigger a one-cycle latch of the
   memory output into the `RDATA` register. Firmware reads `RDATA` on the
   following AXI transaction — the AXI handshake itself introduces enough cycles
   that no explicit delay is needed.
