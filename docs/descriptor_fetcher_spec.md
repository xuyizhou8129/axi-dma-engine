# Descriptor Fetcher

The Descriptor Fetcher bridges the **ring manager** (descriptor placement and flow control) and the rest of the DMA datapath. It does **not** own a deep input FIFO from the ring: the ring manager drives when a descriptor is valid, so backpressure and sequencing are handled there.

## Interfaces

### From ring manager

- **Descriptor address** and a **ready/valid** (or equivalent) handshake indicating that a descriptor at that address should be fetched.

### To AXI4 Master (DF path)

- **Output:** a **handle struct** (see [handle_struct.md](handle_struct.md)) on the FIFO toward the AXI4 Master—used to read descriptor words from system memory.

### From AXI4 Master (callback path)

- **Input:** a full **descriptor struct** (same layout as [descriptor_struct.md](descriptor_struct.md)), with handshake, after the master has read the memory backing the descriptor.

### To Data Mover

- **Output:** a **descriptor struct** with handshake on the DF–DM input (Data Mover input FIFO).

## End-to-end flow (after the fetcher has handed a descriptor to the Data Mover)

1. Descriptor Fetcher passes the descriptor to the Data Mover.
2. Data Mover splits it into **two instruction structs** (SRAM side and system-memory side).
3. Those instructions are sent to the SRAM controller input FIFO and the AXI4 Master input FIFO respectively.
4. AXI4 Master decodes its instruction into AXI channel transactions.
5. SRAM controller decodes its instruction into the local SRAM interface.
6. Return data from system memory flows through the AXI4 Master into a FIFO that feeds the Data Mover path (rather than going straight into the SRAM controller), so the Data Mover can coordinate both sides and completion.
7. The SRAM controller performs writes to SRAM as driven by that path.
8. The write path signals **done** to the Data Mover.
9. Data Mover notifies the ring manager that **one transaction** (descriptor) has completed.
