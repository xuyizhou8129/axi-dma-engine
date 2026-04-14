// -------------------------------------------------------------------------------------------
// Interface: ring_manager_if
// Description: Bundles all signals crossing the Ring Manager module boundary into a single
//              interface with named modports for each connection.
// -------------------------------------------------------------------------------------------

interface ring_manager_if ();

    // -----------------------------------------------------------------------------------------
    // CSR → Ring Manager: ring configuration and control
    // -----------------------------------------------------------------------------------------
    logic           ctrl_enable;    // CTRL.ENABLE – must be asserted before descriptors are issued
    logic           ctrl_reset;     // CTRL.RESET – software reset; stops all tasks, clears state
    logic [31:0]    tail_ptr;       // TAIL pointer written by the CPU
    logic [31:0]    ring_base_addr; // Base address of the ring buffer in memory
    logic [31:0]    ring_len;       // RINGLEN from CSR; number of valid ring slots (must be > 0)
    logic           irq_en;         // CTRL.IRQ_EN – IRQ enable (gating performed in CSR/IRQ)
    logic           error_clear;    // Writing 1 clears STATUS.ERROR and IRQ_STATUS.ERROR

    // -----------------------------------------------------------------------------------------
    // Ring Manager → CSR: status and IRQ set-pulses
    // -----------------------------------------------------------------------------------------
    logic [31:0]    head_ptr;         // HEAD pointer; read by CSR for HEAD register
    logic           busy;             // 1 while descriptors are in flight
    logic           buffer_empty;     // Asserted when head_ptr == tail_ptr (ring is empty)
    logic           irq_status_empty; // Set-pulse on non-empty→empty transition; CSR latches
    logic           irq_status_error; // Set-pulse on descriptor error; CSR latches

    // -----------------------------------------------------------------------------------------
    // Ring Manager → Descriptor Fetcher: fetch request channel (ready/valid handshake)
    // -----------------------------------------------------------------------------------------
    logic [31:0]    rm_df_addr;       // Address of the next descriptor to fetch
    logic           fetch_req_valid;  // Asserted by RM when a fetch can be issued
    logic           fetch_req_ready;  // Asserted by DF when it can accept a new request
    logic           df_error;         // Asserted by DF for one cycle when the fetched descriptor faults

    // -----------------------------------------------------------------------------------------
    // Data Mover → Ring Manager: descriptor completion
    // -----------------------------------------------------------------------------------------
    logic           dm_done; // Single-cycle pulse from DM when a descriptor transfer finishes

    // -----------------------------------------------------------------------------------------
    // Ring Manager → IRQ Controller: interrupt pulses (single-cycle)
    // -----------------------------------------------------------------------------------------
    logic           irq_empty; // Pulses for one cycle on the non-empty → empty ring transition
    logic           irq_error; // Pulses for one cycle when a descriptor error is detected


    // =========================================================================
    // Modport: rm
    //   Used by the ring_manager module itself.
    //   Receives all configuration/control inputs; drives all outputs.
    // =========================================================================
    modport rm (
        // clock / reset are passed directly to the module, not through the interface
        // --- CSR inputs ---
        input  ctrl_enable,
        input  ctrl_reset,
        input  tail_ptr,
        input  ring_base_addr,
        input  ring_len,
        input  irq_en,
        input  error_clear,

        // --- CSR outputs ---
        output head_ptr,
        output busy,
        output buffer_empty,
        output irq_status_empty,
        output irq_status_error,

        // --- Descriptor Fetcher outputs ---
        output rm_df_addr,
        output fetch_req_valid,

        // --- Descriptor Fetcher inputs ---
        input  fetch_req_ready,
        input  df_error,

        // --- Data Mover input ---
        input  dm_done,

        // --- IRQ outputs ---
        output irq_empty,
        output irq_error
    );


    // =========================================================================
    // Modport: csr
    //   Used by the CSR block.
    //   Drives ring configuration and control; monitors status and IRQ set-pulses.
    // =========================================================================
    modport csr (
        // --- configuration outputs (CSR drives these) ---
        output ctrl_enable,
        output ctrl_reset,
        output tail_ptr,
        output ring_base_addr,
        output ring_len,
        output irq_en,
        output error_clear,

        // --- status inputs (RM drives these) ---
        input  head_ptr,
        input  busy,
        input  buffer_empty,
        input  irq_status_empty,
        input  irq_status_error
    );


    // =========================================================================
    // Modport: df
    //   Used by the Descriptor Fetcher.
    //   Receives the fetch-request address; drives ready and error responses.
    // =========================================================================
    modport df (
        // --- fetch request inputs (RM drives these) ---
        input  rm_df_addr,
        input  fetch_req_valid,

        // --- fetch response outputs (DF drives these) ---
        output fetch_req_ready,
        output df_error
    );


    // =========================================================================
    // Modport: dm
    //   Used by the Data Mover.
    //   Drives the single-cycle completion pulse.
    // =========================================================================
    modport dm (
        output dm_done
    );


    // =========================================================================
    // Modport: irq
    //   Used by the IRQ Controller.
    //   Receives the single-cycle interrupt pulses from the Ring Manager.
    // =========================================================================
    modport irq (
        input  irq_empty,
        input  irq_error
    );

endinterface : ring_manager_if
