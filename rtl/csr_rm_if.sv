// -------------------------------------------------------------------------------------------
// Interface: csr_rm_if
// Description: Signals crossing the CSR ↔ Ring Manager boundary.
//              CSR drives configuration/control; Ring Manager drives status and IRQ set-pulses.
// -------------------------------------------------------------------------------------------

interface csr_rm_if ();

    // CSR → Ring Manager
    logic           ctrl_enable;      // CTRL.ENABLE – must be asserted before descriptors are issued
    logic           ctrl_reset;       // CTRL.RESET – software reset; stops all tasks, clears state
    logic [31:0]    tail_ptr;         // TAIL pointer written by the CPU
    logic [31:0]    ring_base_addr;   // Base address of the ring buffer in memory
    logic [31:0]    ring_len;         // RINGLEN from CSR; number of valid ring slots (must be > 0)
    logic           irq_en;           // CTRL.IRQ_EN – IRQ enable (gating performed in CSR/IRQ)
    logic           error_clear;      // Writing 1 clears STATUS.ERROR and IRQ_STATUS.ERROR

    // Ring Manager → CSR
    logic [31:0]    head_ptr;         // HEAD pointer; read by CSR for HEAD register
    logic           busy;             // 1 while descriptors are in flight
    logic           buffer_empty;     // Asserted when head_ptr == tail_ptr (ring is empty)
    logic           irq_status_empty; // Set-pulse on non-empty→empty transition; CSR latches
    logic           irq_status_error; // Set-pulse on descriptor error; CSR latches

    modport csr (
        output ctrl_enable,
        output ctrl_reset,
        output tail_ptr,
        output ring_base_addr,
        output ring_len,
        output irq_en,
        output error_clear,

        input  head_ptr,
        input  busy,
        input  buffer_empty,
        input  irq_status_empty,
        input  irq_status_error
    );

    modport rm (
        input  ctrl_enable,
        input  ctrl_reset,
        input  tail_ptr,
        input  ring_base_addr,
        input  ring_len,
        input  irq_en,
        input  error_clear,

        output head_ptr,
        output busy,
        output buffer_empty,
        output irq_status_empty,
        output irq_status_error
    );

endinterface : csr_rm_if
