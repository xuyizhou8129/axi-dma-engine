# Data Mover

The Data Mover sits between the Descriptor Fetcher (DF) and the memory-side clients (AXI4 Master for system memory, SRAM controller for on-chip SRAM). It consumes **descriptor** records and turns them into paired **instruction** streams.

## Inputs

- **DF–DM FIFO:** one **descriptor struct** per DMA job (see [descriptor_struct.md](descriptor_struct.md)).

## Behavior

1. Receive a descriptor from the DF–DM FIFO.
2. Decode it into **two instruction structs**: one for the SRAM controller and one for system memory (AXI4 Master), as required by the transfer direction encoded in the descriptor.
3. Issue those instructions in parallel (or as concurrently as the downstream FIFOs allow): one to the SRAM controller input path, one to the AXI4 Master input path.

Each **instruction struct** carries a 32-bit base address, burst size, and read/write direction (see [instruction_struct.md](instruction_struct.md)).

## Ordering and transaction IDs

Multiple operations may be in flight, but completions are observed **in issue order**. Explicit AXI-style transaction IDs are therefore **optional**; ordering is sufficient for correct association of responses with requests in this design.
