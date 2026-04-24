// Ring Manager: schedules DMA work by sending descriptor addresses to the
// Descriptor Fetcher. Tracks progress via head pointer. Generates IRQ events.
// MAX_INFLIGHT=1: at most one descriptor in-flight at any time.

module ring_manager #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT  // must be 1
)(
    csr_ring_manager_if.ring_manager csr_rm,

    output logic [dma_pkg::ADDR_WIDTH-1:0] rm_df_addr,
    output logic  fetch_req_valid,
    input  logic  fetch_req_ready,
    input  logic  df_error,
    input  logic  as_done,

    output logic  irq_empty,
    output logic  irq_error
);
    localparam int DESC_SIZE = dma_pkg::DESCRIPTOR_SIZE_BYTES;  // 8

    logic inflight;
    logic was_empty;
    logic int_status_error;

    logic [7:0] head_next;
    logic       inflight_next;
    logic       int_status_error_next;

    assign csr_rm.ring_empty  = (csr_rm.head == csr_rm.tail);
    assign fetch_req_valid    = !csr_rm.ring_empty && csr_rm.enable
                                && (csr_rm.ringlen > 8'd0)
                                && !inflight && !int_status_error;
    // Descriptor address: base + head * DESC_SIZE (DESC_SIZE=8=2^3, use shift)
    assign rm_df_addr         = csr_rm.baseaddr
                                + dma_pkg::ADDR_WIDTH'({8'd0, csr_rm.head} << 3);
    assign csr_rm.busy        = inflight;

    assign csr_rm.irq_empty_set = !was_empty && csr_rm.ring_empty;
    assign csr_rm.error_set     = df_error;
    assign irq_empty            = csr_rm.irq_en && csr_rm.irq_empty_set;
    assign irq_error            = csr_rm.irq_en && csr_rm.error_set;

    always_comb begin
        head_next = csr_rm.head;
        if (fetch_req_valid && fetch_req_ready)
            head_next = (csr_rm.head == (csr_rm.ringlen - 8'd1)) ? 8'd0
                                                                  : csr_rm.head + 8'd1;

        inflight_next = inflight;
        if (fetch_req_valid && fetch_req_ready && !as_done)
            inflight_next = 1'b1;
        else if ((as_done || df_error) && !(fetch_req_valid && fetch_req_ready))
            inflight_next = 1'b0;

        int_status_error_next = int_status_error;
        if (df_error)           int_status_error_next = 1'b1;
        if (csr_rm.error_clear) int_status_error_next = 1'b0;
    end

    always_ff @(posedge csr_rm.clk) begin
        if (!csr_rm.rst_n || csr_rm.reset) begin
            csr_rm.head      <= '0;
            inflight         <= 1'b0;
            was_empty        <= 1'b1;
            int_status_error <= 1'b0;
        end else begin
            csr_rm.head      <= head_next;
            inflight         <= inflight_next;
            was_empty        <= csr_rm.ring_empty;
            int_status_error <= int_status_error_next;
        end
    end

endmodule
