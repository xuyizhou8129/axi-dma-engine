# AXI4 Master (DMA)

The AXI4 Master implements the system-memory side of the DMA engine: it services **handle**-driven descriptor reads for the Descriptor Fetcher and **instruction**-driven data moves for the Data Mover.

## FIFO interfaces

### From Descriptor Fetcher

- **Input:** **handle struct** (see [handle_struct.md](handle_struct.md)) on the FIFO that requests a descriptor read from memory.

### To Descriptor Fetcher (callback)

- **Output:** **descriptor struct** (see [descriptor_struct.md](descriptor_struct.md)) on the callback FIFO, after the descriptor has been read from memory.

### From Data Mover

- **Input:** **instruction struct** (see [instruction_struct.md](instruction_struct.md)): 32-bit address and length (and implied R/W from the instruction), used to generate AXI read/write transactions.

## Arbitration

If a **handle struct** (from the Descriptor Fetcher) and an **instruction struct** (from the Data Mover) are presented in the same cycle, **prioritize the handle**. Descriptor fetch is on the critical path for discovering work; instruction traffic defers.
