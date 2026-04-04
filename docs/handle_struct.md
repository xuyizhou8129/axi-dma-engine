# Handle Struct

The **handle** is what the Descriptor Fetcher sends to the **AXI4 Master** so the master can **read the descriptor contents** from system memory (the descriptor lives in the ring buffer in memory).

## Fields

| Field            | Width | Description |
|------------------|-------|-------------|
| Base address     | 32    | Byte address of the descriptor in system memory |
| Descriptor size  | 8     | Number of words to read; **fixed to 4** in this design (matches the four 32-bit words in [descriptor_struct.md](descriptor_struct.md)) |

How these fields are packed on the physical FIFO (exact bit layout) is **implementation-defined**; logically they are the three items above.

The AXI4 Master uses the handle to perform the read; the resulting descriptor is returned on the **callback FIFO** to the Descriptor Fetcher as a full **descriptor struct**.
