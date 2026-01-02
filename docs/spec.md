# DMA Engine Specification

## Register Map

All registers are 32 bits wide and accessed via AXI4-Lite interface. Base address: `0x0000_0000` (configurable in system).

| Offset | Name | Width | Access | Reset | Description |
|--------|------|-------|--------|-------|-------------|
| `0x00` | `CTRL` | 32 | R/W | `0x0000_0000` | Control register |
| `0x04` | `SRC_ADDR` | 32 | R/W | `0x0000_0000` | Source address (AXI4 memory or SRAM) |
| `0x08` | `DST_ADDR` | 32 | R/W | `0x0000_0000` | Destination address (AXI4 memory or SRAM) |
| `0x0C` | `LEN` | 32 | R/W | `0x0000_0000` | Transfer length in bytes |
| `0x10` | `STATUS` | 32 | RO | `0x0000_0000` | Status register |
| `0x14` | `IRQ_STATUS` | 32 | R/W1C | `0x0000_0000` | Interrupt status (write-1-to-clear) |
| `0x18` | `IRQ_ENABLE` | 32 | R/W | `0x0000_0000` | Interrupt enable mask |

### CTRL Register (0x00)

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | `START` | R/W | 0 | Start transfer (self-clearing after latch) |
| 1 | `DIR` | R/W | 0 | Direction: 0=Memory→SRAM, 1=SRAM→Memory |
| 2 | `IRQ_EN_DONE` | R/W | 0 | Enable interrupt on completion |
| 3 | `IRQ_EN_ERR` | R/W | 0 | Enable interrupt on error |
| 31:4 | `RESERVED` | RO | 0 | Reserved, read as 0 |

### SRC_ADDR Register (0x04)

Source address for the transfer. Must be 4-byte aligned.

### DST_ADDR Register (0x08)

Destination address for the transfer. Must be 4-byte aligned.

### LEN Register (0x0C)

Transfer length in bytes. Must be a multiple of 4 (4-byte aligned). Maximum value TBD.

### STATUS Register (0x10) - Read-Only

| Bits | Name | Access | Description |
|------|------|--------|-------------|
| 0 | `BUSY` | RO | Transfer in progress (1) or idle (0) |
| 1 | `DONE` | RO | Transfer completed successfully (sticky until cleared) |
| 2 | `ERROR` | RO | Transfer error occurred (sticky until cleared) |
| 31:3 | `RESERVED` | RO | Reserved, read as 0 |

**Note:** `DONE` and `ERROR` are sticky bits that remain set until cleared via `IRQ_STATUS` W1C.

### IRQ_STATUS Register (0x14) - Write-1-to-Clear

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | `DONE` | R/W1C | 0 | Done interrupt status (write 1 to clear) |
| 1 | `ERROR` | R/W1C | 0 | Error interrupt status (write 1 to clear) |
| 31:2 | `RESERVED` | RO | 0 | Reserved, read as 0 |

Writing 1 to a bit clears that interrupt status bit. Writing 0 has no effect.

### IRQ_ENABLE Register (0x18)

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | `DONE` | R/W | 0 | Enable done interrupt |
| 1 | `ERROR` | R/W | 0 | Enable error interrupt |
| 31:2 | `RESERVED` | RO | 0 | Reserved, read as 0 |

## Start/Busy/Done/Error Definition

### START

- Writing `1` to `CTRL[0]` (START) latches the current values of `SRC_ADDR`, `DST_ADDR`, and `LEN` into the DMA engine.
- The START bit is self-clearing (read back as 0 after being written).
- If `BUSY=1` when START is written, the behavior is undefined (should be prevented by software).

### BUSY

- `BUSY` is asserted (`STATUS[0] = 1`) from when START is accepted until the transfer completes (DONE) or errors (ERROR).
- `BUSY` is cleared when `DONE` or `ERROR` is set.

### DONE

- `DONE` (`STATUS[1]`) is set to 1 when the programmed `LEN` bytes have been fully transferred.
- For AXI writes: DONE is set after the final `B` response is received.
- `DONE` is a sticky bit that remains set until cleared via `IRQ_STATUS[0]` W1C.
- When `DONE` is set and `IRQ_ENABLE[0]` is set, `irq_done` interrupt is asserted.

### ERROR

- `ERROR` (`STATUS[2]`) is set to 1 when:
  - Any AXI read response has `RRESP != OKAY`
  - Any AXI write response has `BRESP != OKAY`
  - Misalignment detected (SRC_ADDR, DST_ADDR, or LEN not 4-byte aligned)
  - Illegal LEN (not a multiple of 4)
- `ERROR` is a sticky bit that remains set until cleared via `IRQ_STATUS[1]` W1C.
- When `ERROR` is set and `IRQ_ENABLE[1]` is set, `irq_error` interrupt is asserted.

## Alignment and Length Rules

1. **Address Alignment:** `SRC_ADDR` and `DST_ADDR` must be 4-byte aligned (bits [1:0] = 0).
2. **Length Alignment:** `LEN` must be a multiple of 4 bytes (bits [1:0] = 0).
3. **Data Width:** All transfers use 32-bit (4-byte) data beats.
4. **Violation Handling:** If alignment rules are violated, `ERROR` is set and the transfer does not start.

## Transfer Modes

### Memory-to-SRAM (DIR=0)
- Source: AXI4 memory (read via AXI4 master)
- Destination: On-chip SRAM (write via SRAM controller)
- Flow: AXI4 read → internal buffer/FIFO → SRAM write

### SRAM-to-Memory (DIR=1)
- Source: On-chip SRAM (read via SRAM controller)
- Destination: AXI4 memory (write via AXI4 master)
- Flow: SRAM read → internal buffer/FIFO → AXI4 write

## Interrupt Behavior

- `irq_done`: Asserted when `IRQ_STATUS[0] = 1` AND `IRQ_ENABLE[0] = 1`
- `irq_error`: Asserted when `IRQ_STATUS[1] = 1` AND `IRQ_ENABLE[1] = 1`
- Interrupts are level-sensitive (asserted while condition is true).
- Software clears interrupts by writing 1 to the corresponding bit in `IRQ_STATUS`.

## AXI4 Protocol Requirements

- **Burst Type:** INCR (incremental) only
- **Burst Length:** Configurable, but start with one outstanding burst at a time
- **Data Width:** 32 bits (4 bytes per beat)
- **Write Strobes:** `WSTRB = 4'b1111` (full word writes)
- **Backpressure:** Must handle stalls on all channels (`ARREADY`, `RVALID`/`RREADY`, `AWREADY`, `WREADY`, `BVALID`/`BREADY`)

## SRAM Interface Requirements

- **Data Width:** 32 bits
- **Read Latency:** 1 cycle (recommended)
- **Write Enable:** Per-byte or per-word enable signals
- **Address Width:** Configurable (typically 10-16 bits for on-chip SRAM)

