// DMA top-level: SPI-CSR + Ring Manager + Movement Top + IRQ.
// External interface: SPI (4 pins) + probe outputs for TinyTapeout validation.
// AXI4 master removed; movement_top uses an internal memory stub.

module dma_top #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT
) (
    input  logic clk,
    input  logic rst_n,

    // SPI CSR interface (mode 0, MSB first)
    input  logic spi_sclk,
    input  logic spi_mosi,
    output logic spi_miso,
    input  logic spi_csn,

    // Consolidated interrupt output
    output logic irq,

    // Probe outputs (map directly to TinyTapeout uo_out / uio pins)
    output logic       probe_fetch_req_valid,  // ring manager firing a fetch
    output logic       probe_df_in_wr_en,      // descriptor fetcher wrote a handle
    output logic       probe_dm_wr_en,         // data mover produced an instruction
    output logic       probe_dm_instr_rw,      // direction bit (0=read, 1=write)
    output logic       probe_ring_empty,       // ring manager: head == tail
    output logic       probe_busy,             // ring manager: descriptor in-flight
    output logic [7:0] probe_rm_df_addr_lo     // lower byte of descriptor address
);

    csr_ring_manager_if ring_mgr (.clk(clk), .rst_n(rst_n));

    logic rst_core_n;
    assign rst_core_n = rst_n & ~ring_mgr.reset;

    logic irq_clr_pe0, irq_clr_pe1;

    spi_csr u_csr (
        .clk                  (clk),
        .rst_n                (rst_n),
        .sclk                 (spi_sclk),
        .mosi                 (spi_mosi),
        .miso                 (spi_miso),
        .csn                  (spi_csn),
        .ring_mgr             (ring_mgr),
        .irq_clear_pulse_empty(irq_clr_pe0),
        .irq_clear_pulse_error(irq_clr_pe1)
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
        .irq_empty       (),
        .irq_error       ()
    );

    IRQ u_irq (
        .clk        (clk),
        .rst_n      (rst_n),
        .empty_event(ring_mgr.irq_empty_set),
        .error_event(ring_mgr.error_set),
        .irq_en     (ring_mgr.irq_en),
        .irq_clear  ({irq_clr_pe1, irq_clr_pe0}),
        .irq_status (),
        .irq        (irq)
    );

    movement_top u_movement (
        .clk              (clk),
        .rst_n            (rst_core_n),
        .rm_df_addr       (rm_df_addr),
        .rm_df_valid      (fetch_req_valid),
        .df_ready         (fetch_req_ready),
        .df_error         (df_error),
        .dm_done          (dm_done),
        .probe_df_in_wr_en(probe_df_in_wr_en),
        .probe_dm_wr_en   (probe_dm_wr_en),
        .probe_dm_instr_rw(probe_dm_instr_rw)
    );

    assign probe_fetch_req_valid = fetch_req_valid;
    assign probe_ring_empty      = ring_mgr.ring_empty;
    assign probe_busy            = ring_mgr.busy;
    assign probe_rm_df_addr_lo   = rm_df_addr[7:0];

endmodule
