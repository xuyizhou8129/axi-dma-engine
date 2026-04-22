// Synthesis wrapper: ring_manager + IRQ block only.
// Use with syn/rm_irq.prj for targeted Synplify runs.

module rm_irq_top #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT
)(
    input  logic        clk,
    input  logic        rst_n,

    // CSR control inputs (driven by CSR block in full design)
    input  logic [31:0] baseaddr,
    input  logic [31:0] ringlen,
    input  logic [31:0] tail,
    input  logic        enable,
    input  logic        sw_reset,
    input  logic        irq_en,
    input  logic        error_clear,

    // Descriptor Fetcher handshake
    output logic [31:0] rm_df_addr,
    output logic        fetch_req_valid,
    input  logic        fetch_req_ready,
    input  logic        df_error,

    // Done signal from movement path (AXI4 / SRAM controller)
    input  logic        as_done,

    // CSR status outputs (read back by CSR block in full design)
    output logic [31:0] head,
    output logic        busy,
    output logic        ring_empty,

    // IRQ-gated ring event pulses (alternate path; mirrored from ring_manager)
    output logic        irq_rm_empty,
    output logic        irq_rm_error,

    // IRQ block: CPU irq_clear[1:0] = {error_clear_pulse, empty_clear_pulse}
    input  logic [1:0]  irq_clear,
    output logic [1:0]  irq_status,
    output logic        irq
);

    csr_ring_manager_if ring_mgr (.clk(clk), .rst_n(rst_n));

    // Drive the CSR-side interface signals from top-level ports
    assign ring_mgr.baseaddr    = baseaddr;
    assign ring_mgr.ringlen     = ringlen;
    assign ring_mgr.tail        = tail;
    assign ring_mgr.enable      = enable;
    assign ring_mgr.reset       = sw_reset;
    assign ring_mgr.irq_en      = irq_en;
    assign ring_mgr.error_clear = error_clear;

    // Read ring_manager status signals out through ports
    assign head       = ring_mgr.head;
    assign busy       = ring_mgr.busy;
    assign ring_empty = ring_mgr.ring_empty;

    ring_manager #(
        .MAX_INFLIGHT(MAX_INFLIGHT)
    ) u_ring_manager (
        .csr_rm          (ring_mgr),
        .rm_df_addr      (rm_df_addr),
        .fetch_req_valid (fetch_req_valid),
        .fetch_req_ready (fetch_req_ready),
        .df_error        (df_error),
        .as_done         (as_done),
        .irq_empty       (irq_rm_empty),
        .irq_error       (irq_rm_error)
    );

    IRQ u_irq (
        .clk         (clk),
        .rst_n       (rst_n),
        .empty_event (ring_mgr.irq_empty_set),
        .error_event (ring_mgr.error_set),
        .irq_en      (ring_mgr.irq_en),
        .irq_clear   (irq_clear),
        .irq_status  (irq_status),
        .irq         (irq)
    );

endmodule
