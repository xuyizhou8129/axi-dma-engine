# Descriptor Struct

Memory layout of a single descriptor (not a register map). Descriptors live in the ring buffer; the DMA engine reads them via the Descriptor Fetcher.

| Offset | Name       | Width | Description |
|--------|------------|-------|-------------|
| `0x00` | `SRC_ADDR` | 32    | Source address (system memory or SRAM, depending on direction) |
| `0x04` | `DST_ADDR` | 32    | Destination address (system memory or SRAM, depending on direction) |
| `0x08` | `LEN`      | 32    | Number of transactions (burst size) |
| `0x0C` | `FLAGS`    | 32    | Control flags (see below) |

### FLAGS

| Bits   | Name      | Description |
|--------|-----------|-------------|
| 0      | `DIR`     | **Direction:** `1` = System memory → SRAM; `0` = SRAM → System memory |
| 31:1   | Reserved  | Reserved;|
