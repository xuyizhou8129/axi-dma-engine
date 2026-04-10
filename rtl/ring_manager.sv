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
    input  logic             ctrl_enable,      // CTRL.ENABLE must be asserted before descriptor is issued
    input  logic     [31:0]   tail_ptr,         // tail managed by CPU
    input  logic     [31:0]  ring_base_addr,   // Base address of ring buffer
    input  logic     [2:0]   ring_len,         // RINGLEN from CSR (must be > 0)
    input  logic             irq_empty_en,     // IRQ enable for empty event
    input  logic             irq_error_en,     // IRQ enable for error event
    input  logic             error_clear,      // Resets error signals

    // Descriptor Fetcher
    output logic     [31:0]  rm_df_addr,       // send address to fetch to DF
    output logic             fetch_req_valid,  // High when ring is non-empty, ctrl_enable asserted, and ring_len > 0
    input  logic             fetch_req_ready,  // DF is ready for new address
    input  logic             df_error,         // Descriptor completed with error


    // Inputs from Data Mover
    input  logic             dm_done,          // Desriptor completed successfully

    // Outputs to CSR
    output logic             buffer_empty,     // buffer is empty (head == tail)
    output logic             status_error,     // STATUS.ERROR - general health flag set on any error
    output logic             irq_status_empty, // IRQ_STATUS.EMPTY - sticky bit set on non-empty to empty transition (cleared by CPU / IRQ_CLEAR)
    output logic             irq_status_error, // IRQ_STATUS.ERROR - sticky bit set when error interrupt fires (cleared by CPU / IRQ_CLEAR)

    // Outputs to IRQ
    output logic             irq_empty,        // single cycle pulse to IRQ on non-empty to empty transition
    output logic             irq_error         // single cycle pulse to IRQ on any error
);
    // ---------------------------------------------
    // Parameters & local signals
    // ---------------------------------------------

    // local signals
    logic [2:0]                          head_ptr;            // points to head of ring buffer
    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count;      // counter for number of descriptors in-flight
    logic                                desc_complete;       // flag for when a descriptor completes
    logic                                was_empty;           // HIGH if buffer was empty last clock cycle

    logic [2:0]                          head_ptr_next;       
    logic [$clog2(MAX_INFLIGHT+1)-1 : 0] inflight_count_next;
    logic                                irq_empty_next;
    logic                                irq_status_empty_next;
    logic                                irq_status_error_next;
    logic                                status_error_next;
    logic                                irq_error_next;

    // 16 bytes per descriptor
    localparam int DESCRIPTOR_SIZE = 16;

    // ---------------------------------------------
    // Combinational logic
    // ---------------------------------------------
    always_comb begin
        // ring buffer is empty when head = tail
        buffer_empty = (head_ptr == tail_ptr);

        // fetch request valid: buffer is non-empty & ctrl_enable is HIGH & ring_len > 0 & inflight_count < MAX_INFLIGHT
        fetch_req_valid = (!buffer_empty) && (ctrl_enable) && (ring_len > 3'b0) && (inflight_count < MAX_INFLIGHT) && (!status_error);

        // descriptor address = base address + (head index * descriptor size in bytes)
        rm_df_addr = ring_base_addr + (head_ptr * DESCRIPTOR_SIZE);

        // descriptor complete: dm returns done or error
        desc_complete = dm_done || df_error;

        // head pointer logic //
        head_ptr_next = head_ptr;

        if (desc_complete && !status_error) begin
                if (head_ptr == (ring_len - 1) ) begin
                    head_ptr_next = 3'b0; // reset head_ptr
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
            inflight_count_next = inflight_count - 1'b1; // Descriptor completed: decremenet inflight_count
        end
        

        // interrupt logic //
        irq_status_empty_next = irq_status_empty;
        irq_empty_next = 1'b0;
        irq_status_error_next = irq_status_error;
        irq_error_next = 1'b0;
        status_error_next = status_error;

        // empty interrupt - fires when ring buffer transitions from non-empty to empty
        if (!was_empty && buffer_empty) begin
            irq_status_empty_next = 1'b1;
            if (irq_empty_en) begin
                irq_empty_next = 1'b1;
            end
        end

        // error interrupt - fires when DM reports a descriptor error
        if (df_error) begin
            irq_status_error_next = 1'b1;
            status_error_next     = 1'b1;
            if (irq_error_en) begin
                irq_error_next = 1'b1;
            end
        end

        // error clear - resets all error signals
        // after df_error: error_clear has priority
        if (error_clear) begin
            status_error_next = 1'b0;
            irq_status_error_next = 1'b0;
        end

    end

    // ---------------------------------------------
    // Sequential logic
    // ---------------------------------------------
    always_ff @(posedge clk) begin

        if (!reset_n) begin
            
            head_ptr <= 3'b0; // reset head to start of ring buffer
            inflight_count <= '0;
            was_empty <= 1'b1; // buffer starts empty
            irq_empty <= 1'b0;
            irq_error <= 1'b0;
            irq_status_empty <= 1'b0;
            irq_status_error <= 1'b0;
            status_error <= 1'b0;

        end else begin
            head_ptr           <= head_ptr_next;
            inflight_count     <= inflight_count_next;
            irq_empty          <= irq_empty_next;
            irq_status_empty   <= irq_status_empty_next;
            irq_status_error   <= irq_status_error_next;
            irq_error          <= irq_error_next;
            was_empty          <= buffer_empty;
            status_error       <= status_error_next;
        end

    end
    
endmodule