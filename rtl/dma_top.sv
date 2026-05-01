//wire movement top to the ring manager, csr, and irq
//reuse the interfaces defined in the rtl folder

// DMA top: AXI-Lite (CSR) + AXI4 master (movement_top) + ring_manager + IRQ.sv.
// soc_bus.irq* still comes from CSR (sticky bits + CTRL.IRQ_EN). IRQ.sv irq is an alternate
// consolidated pin (status_empty|status_error) & irq_en — connect one to the CPU in integration.

module dma_top #(
    parameter int MAX_INFLIGHT = 4  // keep equal to dma_pkg::MAX_INFLIGHT
) (
    input logic clk,
    input logic rst_n,
    csr_soc_bus_if soc_bus,
    axi_4_if.master axi_sys,

    // Legacy RM pulses (irq_en-gated inside ring_manager)
    output logic irq_rm_empty,
    output logic irq_rm_error,

    // IRQ.sv: interrupt pin and raw status bits [error, empty]
    output logic       irq_block,
    output logic [1:0] irq_block_status
);

    csr_ring_manager_if ring_mgr (.clk(clk), .rst_n(rst_n));

    logic rst_core_n;
    assign rst_core_n = rst_n & ~ring_mgr.reset;

    logic irq_clr_pe0;
    logic irq_clr_pe1;

    csr u_csr (
        .soc_bus               (soc_bus),
        .ring_mgr              (ring_mgr),
        .irq_clear_pulse_empty (irq_clr_pe0),
        .irq_clear_pulse_error (irq_clr_pe1)
    );

    logic [dma_pkg::ADDR_WIDTH-1:0] rm_df_addr;
    logic                           fetch_req_valid;
    logic                           fetch_req_ready;
    logic                           df_error;
    logic                           dm_done;

    ring_manager #(
        .MAX_INFLIGHT(MAX_INFLIGHT)
    ) u_ring_manager (
        .csr_rm          (ring_mgr),
        .rm_df_addr      (rm_df_addr),
        .fetch_req_valid (fetch_req_valid),
        .fetch_req_ready (fetch_req_ready),
        .df_error        (df_error),
        .as_done         (dm_done),
        .irq_empty       (irq_rm_empty),
        .irq_error       (irq_rm_error)
    );

    IRQ u_irq (
        .clk         (clk),
        .rst_n       (rst_n),
        .empty_event (ring_mgr.irq_empty_set),
        .error_event (ring_mgr.error_set),
        .irq_en      (ring_mgr.irq_en),
        .irq_clear   ({irq_clr_pe1, irq_clr_pe0}),
        .irq_status  (irq_block_status),
        .irq         (irq_block)
    );

    movement_top u_movement (
        .clk         (clk),
        .rst_n       (rst_core_n),
        .rm_df_addr  (rm_df_addr),
        .rm_df_valid (fetch_req_valid),
        .df_ready    (fetch_req_ready),
        .df_error    (df_error),
        .dm_done     (dm_done),
        .axi         (axi_sys)
    );

endmodule
