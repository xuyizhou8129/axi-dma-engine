// -------------------------------------------------------------------------------------------
// Module: Ring Manager
// Description: Schedules DMA work by sending descriptor addresses to the Descriptor Fetcher.
//              Tracks ring progress by updating the HEAD pointer in the CSR block.
//              Generates completion / error notifications via CSR interrupt bits.
// -------------------------------------------------------------------------------------------

module ring_manager #(
    parameter MAX_INFLIGHT = 4 // maximum number of requests in flight (arbitrarily chosen)
)(
    input logic clk,            // system clock
    input logic reset_n,        // active-low reset

    // Inputs from CSR
    input  logic             ctrl_enable,    // CTRL.ENABLE must be asserted before descriptor is issued
    input  logic             ctrl_reset,     // CTRL.RESET - software reset: stops all tasks, clears state
    input  logic     [31:0]  tail_ptr,       // tail managed by CPU
    input  logic     [31:0]  ring_base_addr, // Base address of ring buffer
    input  logic     [31:0]  ring_len,       // RINGLEN from CSR (must be > 0)
    input  logic             irq_en,         // IRQ enable (gating performed in CSR; accepted but unused here)
    input  logic             error_clear,    // Resets error signals (IRQ_CLEAR[1])

    // Descriptor Fetcher
    output logic     [31:0]  rm_df_addr,      // send address to fetch to DF
    output logic             fetch_req_valid, // High when ring is non-empty, ctrl_enable asserted, and ring_len > 0
    input  logic             fetch_req_ready, // DF is ready for new address
    input  logic             df_error,        // Descriptor completed with error (pulse)

    // Inputs from Data Mover
    input  logic             dm_done,         // Descriptor completed successfully

    // Outputs to CSR
    output logic     [31:0]  head_ptr,         // HEAD pointer (read by CSR for HEAD register)
    output logic             busy,             // 1 while descriptors are in flight
    output logic             buffer_empty,     // ring is empty (head == tail)
    output logic             irq_status_empty, // set-pulse on non-empty to empty transition (CSR latches)
    output logic             irq_status_error, // set-pulse on descriptor error (CSR latches)

    // Outputs to IRQ
    output logic             irq_empty,        // single cycle pulse to IRQ on non-empty to empty transition
    output logic             irq_error         // single cycle pulse to IRQ on any error
);
    // ---------------------------------------------
    // Parameters & local signals
    // ---------------------------------------------

    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count;      // counter for number of descriptors in-flight
    logic                                desc_complete;       // flag for when a descriptor completes
    logic                                was_empty;           // HIGH if buffer was empty last clock cycle
    logic                                status_error;        // internal sticky error flag for gating fetch/head logic

    logic [31:0]                         head_ptr_next;
    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count_next;
    logic                                status_error_next;

    // 16 bytes per descriptor
    localparam int DESCRIPTOR_SIZE = 16;

    // ---------------------------------------------
    // Combinational logic
    // ---------------------------------------------
    always_comb begin
        // ring buffer is empty when head = tail
        buffer_empty = (head_ptr == tail_ptr);

        // fetch request valid: buffer is non-empty & ctrl_enable is HIGH & ring_len > 0 & inflight_count < MAX_INFLIGHT
        fetch_req_valid = (!buffer_empty) && (ctrl_enable) && (ring_len > 0) && (inflight_count < MAX_INFLIGHT) && (!status_error);

        // descriptor address = base address + (head index * descriptor size in bytes)
        rm_df_addr = ring_base_addr + (head_ptr * DESCRIPTOR_SIZE);

        // descriptor complete: dm returns done or error
        desc_complete = dm_done || df_error;

        // head pointer logic //
        head_ptr_next = head_ptr;

        if (desc_complete && !status_error) begin
            if (head_ptr == (ring_len - 1)) begin
                head_ptr_next = '0; // wrap head_ptr
            end else begin
                head_ptr_next = head_ptr + 1'b1; // increment head if desc_complete = HIGH
            end
        end

        // in-flight counter logic //
        inflight_count_next = inflight_count;

        if (fetch_req_ready && fetch_req_valid && desc_complete) begin
            inflight_count_next = inflight_count; // Valid handshaking with DF AND Descriptor completed: pass (net change)
        end else if (fetch_req_ready && fetch_req_valid) begin
            inflight_count_next = inflight_count + 1'b1; // Valid handshaking with DF: increment inflight_count
        end else if (desc_complete && !status_error) begin
            inflight_count_next = inflight_count - 1'b1; // Descriptor completed: decrement inflight_count
        end

        // internal sticky error flag for gating
        status_error_next = status_error;
        if (df_error) begin
            status_error_next = 1'b1;
        end
        if (error_clear) begin // error_clear has priority
            status_error_next = 1'b0;
        end
    end

    // Set-pulse outputs: fire for one cycle; CSR latches them into sticky status/IRQ bits
    assign busy             = (inflight_count > 0);
    assign irq_status_empty = !was_empty && buffer_empty; // non-empty to empty transition
    assign irq_status_error = df_error;                   // error pulse

    // Direct pulses to IRQ module
    assign irq_empty = irq_status_empty;
    assign irq_error = irq_status_error;

    // ---------------------------------------------
    // Sequential logic
    // ---------------------------------------------
    always_ff @(posedge clk) begin

        if (!reset_n || ctrl_reset) begin
            head_ptr       <= 32'b0;
            inflight_count <= '0;
            was_empty      <= 1'b1; // buffer starts empty
            status_error   <= 1'b0;
        end else begin
            head_ptr       <= head_ptr_next;
            inflight_count <= inflight_count_next;
            was_empty      <= buffer_empty;
            status_error   <= status_error_next;
        end

    end

endmodule
