// Flat-port top-level wrapper for Vivado synthesis.
// Instantiates dma_top and sys_mem (on-chip SRAM), eliminating the need for
// an external DDR/MIG connection.  Only the AXI-Lite CSR bus and interrupts
// are exposed as scalar I/O so Vivado can assign package pins.
//
// NOTE: SV interfaces cannot be used as top-level ports because Vivado must
// map every port to a physical pin at elaboration time.  Interfaces are used
// freely for internal wiring (sub-module boundaries) where the tool inlines
// them without issue.

module vivado_config #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT,
    parameter int MEM_WORDS    = 1024
) (
    input  logic        clk,
    input  logic        rst_n,

    // ---- AXI-Lite CSR (slave) ----
    input  logic [31:0] s_axil_awaddr,
    input  logic [2:0]  s_axil_awprot,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,

    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,

    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,

    input  logic [31:0] s_axil_araddr,
    input  logic [2:0]  s_axil_arprot,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,

    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready,

    // ---- Interrupts ----
    output logic        irq_rm_empty,
    output logic        irq_rm_error,
    output logic        irq_block,
    output logic [1:0]  irq_block_status
);

    // Internal interfaces — fine to use inside the hierarchy
    csr_soc_bus_if soc_bus (.clk(clk), .rst_n(rst_n));
    axi_4_if       axi_sys (.clk(clk), .rst_n(rst_n));

    // AXI-Lite CSR connections
    assign soc_bus.awaddr  = s_axil_awaddr;
    assign soc_bus.awprot  = s_axil_awprot;
    assign soc_bus.awvalid = s_axil_awvalid;
    assign s_axil_awready  = soc_bus.awready;

    assign soc_bus.wdata   = s_axil_wdata;
    assign soc_bus.wstrb   = s_axil_wstrb;
    assign soc_bus.wvalid  = s_axil_wvalid;
    assign s_axil_wready   = soc_bus.wready;

    assign s_axil_bresp    = soc_bus.bresp;
    assign s_axil_bvalid   = soc_bus.bvalid;
    assign soc_bus.bready  = s_axil_bready;

    assign soc_bus.araddr  = s_axil_araddr;
    assign soc_bus.arprot  = s_axil_arprot;
    assign soc_bus.arvalid = s_axil_arvalid;
    assign s_axil_arready  = soc_bus.arready;

    assign s_axil_rdata    = soc_bus.rdata;
    assign s_axil_rresp    = soc_bus.rresp;
    assign s_axil_rvalid   = soc_bus.rvalid;
    assign soc_bus.rready  = s_axil_rready;

    // DMA engine (AXI4 master on axi_sys)
    dma_top #(
        .MAX_INFLIGHT(MAX_INFLIGHT)
    ) u_dma_top (
        .clk              (clk),
        .rst_n            (rst_n),
        .soc_bus          (soc_bus),
        .axi_sys          (axi_sys.master),
        .irq_rm_empty     (irq_rm_empty),
        .irq_rm_error     (irq_rm_error),
        .irq_block        (irq_block),
        .irq_block_status (irq_block_status)
    );

    // On-chip SRAM — AXI4 slave on the same axi_sys bus
    sys_mem #(
        .MEM_WORDS(MEM_WORDS)
    ) u_sys_mem (
        .axi(axi_sys.slave)
    );

endmodule