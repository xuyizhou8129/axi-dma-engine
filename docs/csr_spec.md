# CSR Specification

## Register Map

All registers are 32 bits wide and accessed via AXI4-Lite interface. The descriptor ring buffer base address is programmed via the `BASEADDR` register.

| Offset | Name | Width | Access (From SOC) | Reset | Description |
|--------|------|-------|--------|-------|-------------|
| `0x00` | `BASEADDR` | 32 | R/W | `0x0000_0000` | Base Address of Ring Buffer |
| `0x04` | `RINGLEN` | 32 | R/W | `0x0000_0000` | Length of Ring Buffer (by # of desc) |
| `0x08` | `HEAD` | 32 | RO | `0x0000_0000` | Consumer pointer (managed by DMAs) |
| `0x0C` | `TAIL` | 32 | R/W | `0x0000_0000` | Producer pointer (managed by CPU) |
| `0x10` | `CTRL` | 32 | R/W | `0x0000_0000` | Control register |
| `0x14` | `STATUS` | 32 | RO | `0x0000_0000` | Status register |
| `0x18` | `IRQ_STATUS` | 32 | RO | `0x0000_0000` | Interrupt status|
| `0x2C` | `IRQ_CLEAR` | 32 | R/W | `0x0000_0000` | Interrupt clear |

## Ring Buffer Overview

The DMA engine processes a ring of descriptors in memory:

- `BASEADDR` points to the first descriptor in the ring.
- `RINGLEN` gives the number of descriptor entries in the ring.
- `HEAD` is the index of the next descriptor the DMA engine will consume.
- `TAIL` is the index where software will enqueue the next descriptor.

All indices are in units of descriptors (not bytes) and wrap modulo `RINGLEN`.

Software must ensure the ring is never overrun:

- The ring is **empty** when `HEAD == TAIL - 1`.
- The ring is **full** when `(TAIL + 1) % RINGLEN == HEAD`.
- Software must not advance `TAIL` into the full condition.



### BASEADDR Register (0x00)

| Bits  | Name       | Access | Reset | Description |
|-------|------------|--------|-------|-------------|
| 31:0  | `BASEADDR` | R/W    | 0     | Byte address of the descriptor ring in system memory. Must be aligned to the descriptor size. |

### RINGLEN Register (0x04)

| Bits  | Name      | Access | Reset | Description |
|-------|-----------|--------|-------|-------------|
| 31:0  | `RINGLEN` | R/W    | 0     | Number of descriptor entries in the ring. Must be > 0. |

### HEAD Register (0x08) - Read-Only

| Bits  | Name   | Access | Reset | Description |
|-------|--------|--------|-------|-------------|
| 31:0  | `HEAD` | RO     | 0     | Current consumer index (next descriptor the DMA will process), in \[0, `RINGLEN`-1]. |

`HEAD` is updated by the DMA engine after it finishes processing a descriptor. Software must not write this register.

### TAIL Register (0x0C)

| Bits  | Name   | Access | Reset | Description |
|-------|--------|--------|-------|-------------|
| 31:0  | `TAIL` | R/W    | 0     | Current producer index (one past the last valid descriptor), in \[0, `RINGLEN`-1]. |

Software enqueues descriptors by:

1. Writing a descriptor into memory at `BASEADDR + TAIL * DESC_SIZE` (where `DESC_SIZE` is the descriptor size in bytes).
2. Advancing `TAIL` (modulo `RINGLEN`) to the next free entry, without entering the full condition (Software checks before updating TAIL).

### CTRL Register (0x10)

| Bits | Name           | Access | Reset | Description |
|------|----------------|--------|-------|-------------|
| 0    | `ENABLE`       | R/W    | 0     | Enable DMA engine. When 0, no new descriptors are fetched and `HEAD` stops advancing. |
| 1    | `RESET` | R/W    | 0     | Reset the EMA engine, all current tasks stopped, csr cleared |
| 2    | `IRQ_EN`   | R/W    | 0     | Enable interrupt on error. |
| 31:3 | `RESERVED`     | RO     | 0     | Reserved, read as 0. |

### STATUS Register (0x14) - Read-Only

| Bits | Name         | Access | Description |
|------|--------------|--------|-------------|
| 0    | `BUSY`       | RO     | 1 while the DMA engine is actively processing a descriptor. |
| 1    | `RING_EMPTY` | RO     | 1 when `HEAD == TAIL - 1` (no pending descriptors). |
| 2    | `ERROR`      | RO     | Sticky error indication; set when any fatal error occurs. Cleared via `IRQ_CLEAR[1]`. |
| 31:3 | `RESERVED`   | RO     | Reserved, read as 0. |

### IRQ_STATUS Register (0x18) - Read-Only

| Bits | Name       | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| 0    | `EMPTY`    | RO     | 0     | Latched when the ring transitions from non-empty to empty. |
| 1    | `ERROR`    | RO     | 0     | Latched when an error condition is detected. |
| 31:2 | `RESERVED` | RO     | 0     | Reserved, read as 0. |

### IRQ_CLEAR Register (0x2C) - Write-1-to-Clear

| Bits | Name       | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| 0    | `EMPTY`    | R/W1C  | 0     | Write 1 to clear `IRQ_STATUS[0]`. Writing 0 has no effect. |
| 1    | `ERROR`    | R/W1C  | 0     | Write 1 to clear `IRQ_STATUS[1]` and deassert the error condition. |
| 31:2 | `RESERVED` | RO     | 0     | Reserved, read as 0. |


Note: Empty is no pending instructions, can be no descriptors need to be processed to processing done.
