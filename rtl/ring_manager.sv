// -------------------------------------------------------------------------------------------
// Module: Ring Manager
// Description: Schedules DMA work by sending descriptor addresses to the Descriptor Fetcher.
//              Tracks ring progress by updating the HEAD pointer in the CSR block.
//              Generates completion / error notifications via CSR interrupt bits.
// -------------------------------------------------------------------------------------------

module ring_manager #(
    parameter MAX_INFLIGHT = 4 // maximum number of requests in flight (arbitrarily chosen)
)(
    // CSR interface
    csr_ring_manager_if.slave csr_rm,

    // Descriptor Fetcher
    output logic     [31:0]  rm_df_addr,      // send address to fetch to DF
    output logic             fetch_req_valid, // High when ring is non-empty, enable asserted, and ringlen > 0
    input  logic             fetch_req_ready, // DF is ready for new address
    input  logic             df_error,        // Descriptor completed with error (pulse)

    // Input from AXI/SRAM
    input  logic             as_done,         // Done signal: AXI4 & SRAM controller

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

    assign csr_rm.ring_empty    = (csr_rm.head == csr_rm.tail);
    assign fetch_req_valid      = !csr_rm.ring_empty && csr_rm.enable && (csr_rm.ringlen > 0)
                                  && (inflight_count < MAX_INFLIGHT) && !int_status_error;
    assign rm_df_addr           = csr_rm.baseaddr + (csr_rm.head * DESCRIPTOR_SIZE);
    assign csr_rm.busy          = (inflight_count > 0);

    // Pulse outputs: fire one cycle; CSR latches them into sticky status/IRQ bits
    assign csr_rm.irq_empty_set = !was_empty && csr_rm.ring_empty; // non-empty → empty transition
    assign csr_rm.error_set     = df_error;                        // df_error is already a pulse
    assign irq_empty            = csr_rm.irq_en && csr_rm.irq_empty_set;
    assign irq_error            = csr_rm.irq_en && csr_rm.error_set;


    always_comb begin

        // Head pointer logic
        head_ptr_next = csr_rm.head;
        if (fetch_req_valid && fetch_req_ready) begin
            if (csr_rm.head == (csr_rm.ringlen - 1))
                head_ptr_next = '0;
            else
                head_ptr_next = csr_rm.head + 1'b1;
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
        if (df_error)             int_status_error_next = 1'b1;
        if (csr_rm.error_clear)   int_status_error_next = 1'b0; // error_clear has priority

        // SW reset enable
        sw_rst_enable_next = sw_rst_enable;
        if (~int_status_error && (inflight_count == 0)) sw_rst_enable_next = 1'b1;
        if (csr_rm.error_clear)                         sw_rst_enable_next = 1'b0;

    end

    // ---------------------------------------------
    // Sequential logic
    // ---------------------------------------------
    always_ff @(posedge csr_rm.clk) begin

        if (!csr_rm.rst_n || csr_rm.reset) begin
            csr_rm.head        <= 32'b0;
            inflight_count     <= '0;
            was_empty          <= 1'b1; // buffer starts empty
            int_status_error   <= 1'b0;
            sw_rst_enable      <= 1'b0;
        end else begin
            csr_rm.head        <= head_ptr_next;
            inflight_count     <= inflight_count_next;
            was_empty          <= csr_rm.ring_empty;
            int_status_error   <= int_status_error_next;
            sw_rst_enable      <= sw_rst_enable_next;
        end

    end

endmodule
