# Ring Manager Specification

- **Role**
  - Schedules DMA work by sending descriptor addresses to the Descriptor Fetcher.
  - Tracks ring progress by updating the `HEAD` pointer in the CSR block.
  - Generates completion / error notifications via CSR interrupt bits.

- **Preconditions / Checks**
  - **`CTRL.ENABLE`** in CSR is asserted before any descriptor is issued.
  - **`RINGLEN` > 0** in CSR; ring length are valid values asserted by CPU.
  - **Done condition**: ring is empty when `HEAD == TAIL`.
  - **Fold / wrap**: when `HEAD` reaches `RINGLEN`, it wraps to 0 (modulo operation).
  - **Descriptor address calculation**:  
    `DESC_ADDR = BASEADDR + HEAD * DESC_SIZE`.

- **In‑flight Tracking**
  - Design is pipelined; multiple descriptor addresses may be in flight.
  - A small counter tracks how many descriptors are outstanding and which index to issue next.
  - New descriptors are only issued when there is available in‑flight capacity. (Can be arbitrairily decided based on the architecture of the data moving part)

- **CSR / IRQ Interactions**
  - **HEAD update**: after a descriptor completes (success or error), `HEAD` is advanced.
  - **Empty notification**: when the ring transitions from non‑empty to empty, the Ring Manager:
    - Sets the appropriate `IRQ_STATUS.EMPTY` bit. (In CSR)
    - Triggers `irq_empty` if enabled in CSR. (In IRQ)
  - **Error notification**: on descriptor or bus error, the Ring Manager:
    - Sets CSR error status (`STATUS.ERROR`, `IRQ_STATUS.ERROR`). (In CSR)
    - Triggers `irq_error` when enabled. (In IRQ)
