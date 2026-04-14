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
    input  logic             irq_en,         // IRQ enable
    input  logic             error_clear,    // Resets error signals (IRQ_CLEAR[1])

    // Descriptor Fetcher
    output logic     [31:0]  rm_df_addr,      // send address to fetch to DF
    output logic             fetch_req_valid, // High when ring is non-empty, ctrl_enable asserted, and ring_len > 0
    input  logic             fetch_req_ready, // DF is ready for new address
    input  logic             df_error,        // Descriptor completed with error (pulse)

    // Input from AXI/SRAM
    input  logic             as_done,         // Done signal: AXI4 & SRAM controller

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
    // Parameters & Local Signals
    // ---------------------------------------------

    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count;      // counter for number of descriptors in-flight
    logic                                was_empty;           // HIGH if buffer was empty last clock cycle
    logic                                int_status_error;    // internal sticky error flag
    logic                                sw_rst_enable;       // allow sw_rst once all descriptors in-flight are completed

    logic [31:0]                         head_ptr_next;
    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count_next;
    logic                                int_status_error_next;
    logic                                sw_rst_enable_next;

    // 16 bytes per descriptor
    localparam int DESCRIPTOR_SIZE = 16;

    // ---------------------------------------------
    // Combinational logic
    // ---------------------------------------------

    assign buffer_empty     = (head_ptr == tail_ptr);
    assign fetch_req_valid  = !buffer_empty && ctrl_enable && (ring_len > 0)
                              && (inflight_count < MAX_INFLIGHT) && !int_status_error;
    assign rm_df_addr       = ring_base_addr + (head_ptr * DESCRIPTOR_SIZE);
    assign busy             = (inflight_count > 0);

    // Pulse outputs: fire one cycle; CSR latches them into sticky status/IRQ bits
    assign irq_status_empty = !was_empty && buffer_empty; // non-empty → empty transition
    assign irq_status_error = df_error;                   // df_error is already a pulse
    assign irq_empty        = irq_en && irq_status_empty;
    assign irq_error        = irq_en && irq_status_error;


    always_comb begin

        // Head pointer logic
        head_ptr_next = head_ptr;
        if (as_done && !buffer_empty) begin
            if (head_ptr == (ring_len - 1))
                head_ptr_next = '0;
            else
                head_ptr_next = head_ptr + 1'b1;
        end 

        // In-flight counter logic
        inflight_count_next = inflight_count;
        if (fetch_req_ready && fetch_req_valid && as_done)
            inflight_count_next = inflight_count;          // simultaneous issue + complete: net zero
        else if (fetch_req_ready && fetch_req_valid)
            inflight_count_next = inflight_count + 1'b1;  // new descriptor issued
        else if (as_done || df_error)
            inflight_count_next = inflight_count - 1'b1;  // descriptor completed

        // Internal error flag
        int_status_error_next = int_status_error;
        if (df_error)    int_status_error_next = 1'b1;
        if (error_clear) int_status_error_next = 1'b0; // error_clear has priority

        // SW reset enable
        sw_rst_enable_next = sw_rst_enable;
        if (~int_status_error && (inflight_count == 0)) sw_rst_enable_next = 1'b1;
        if (error_clear)                               sw_rst_enable_next = 1'b0;

    end

    // ---------------------------------------------
    // Sequential logic
    // ---------------------------------------------
    always_ff @(posedge clk) begin

        if (!reset_n || ctrl_reset) begin
            head_ptr           <= 32'b0;
            inflight_count     <= '0;
            was_empty          <= 1'b1; // buffer starts empty
            int_status_error   <= 1'b0;
            sw_rst_enable      <= 1'b0;
        end else begin
            head_ptr           <= head_ptr_next;
            inflight_count     <= inflight_count_next;
            was_empty          <= buffer_empty;
            int_status_error   <= int_status_error_next;
            sw_rst_enable      <= sw_rst_enable_next;
        end

    end

endmodule