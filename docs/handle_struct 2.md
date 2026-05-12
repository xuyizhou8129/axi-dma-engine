# Handle Struct

The **handle** is what the Descriptor Fetcher sends to the **AXI4 Master** so the master can **read the descriptor contents** from system memory (the descriptor lives in the ring buffer in memory).

## Fields

| Field            | Width | Description |
|------------------|-------|-------------|
| Base address     | 32    | Byte address of the descriptor in system memory |
| Length (beats)   | 8     | Number of 32-bit words to read (descriptor fetch supports up to 4 words in RTL) |

The DF→master FIFO provides presence; no separate valid bit. Packed on the FIFO as **40 bits**: `[31:0]` address, `[39:32]` length.

The AXI4 Master uses the handle to perform the read; the resulting descriptor is returned on the **callback FIFO** to the Descriptor Fetcher as a full **descriptor struct**.
