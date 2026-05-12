# Descriptor Struct

Memory layout of a single descriptor (not a register map). Descriptors live in the ring buffer; the DMA engine reads them via the Descriptor Fetcher.

Addresses are **byte addresses** and must be **4-byte aligned** (AXI word size). The SRAM controller uses `byte_addr >> 2` as a word index into BRAM.

| Offset | Name       | Width | Description |
|--------|------------|-------|-------------|
| `0x00` | `SRC_ADDR` | 32    | Source address (system memory or SRAM, depending on direction) |
| `0x04` | `DST_ADDR` | 32    | Destination address (system memory or SRAM, depending on direction) |
| `0x08` | `LEN`      | 32    | Number of transactions (burst size); **low 8 bits** are used as the beat count |
| `0x0C` | `FLAGS`    | 32    | Control flags (see below) |

### FLAGS

| Bits   | Name      | Description |
|--------|-----------|-------------|
| 0      | `DIR`     | **Direction:** `1` = System memory → SRAM; `0` = SRAM → System memory |
| 31:1   | Reserved  | Reserved; |

### RTL / software mapping

Packed 128-bit descriptor (word0 = bits `[31:0]`, …, word3 = `[127:96]`):

- `DIR` = `FLAGS[0]` = bit **96** of the packed 128-bit bus (`input_data[96]` in `rtl/data_mover.sv`).

CSV `desc` line: `desc,<SRC_hex>,<DST_hex>,<LEN_hex>,<FLAGS_hex>`.
