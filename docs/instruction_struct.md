# Instruction Struct

**Instruction structs** are issued by the **Data Mover** to the **SRAM controller** and the **AXI4 Master**. They describe a single low-level memory operation (address extent, burst behavior, and direction) after a **descriptor** has been decoded.

## Fields

| Field         | Width | Description |
|---------------|-------|-------------|
| Base address  | 32    | Starting address for this side of the transfer |
| Burst size    | —     | Transfer length in the units agreed with each consumer (e.g. beats or bytes, per implementation) |
| R/W           | 1     | **Read** vs **write** for this instruction |

Two instructions are produced per descriptor—one targeted at SRAM, one at system memory—consistent with the direction bit in the descriptor **FLAGS** (see [descriptor_struct.md](descriptor_struct.md)).
