// Flat-port top-level wrapper for Vivado synthesis.
// Instantiates dma_top and binds the SV interface ports to scalar I/O so
// Vivado can assign package pins and generate a bitstream.
// Swap the target part in vivado/create_project.tcl; this file is tool-agnostic.

module vivado_config #(
    parameter int MAX_INFLIGHT = dma_pkg::MAX_INFLIGHT
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

    // ---- AXI4 memory master ----
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    output logic [31:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,

    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,
    output logic [31:0] m_axi_wdata,
    output logic        m_axi_wlast,

    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,
    input  logic [1:0]  m_axi_bresp,

    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    output logic [31:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,

    input  logic        m_axi_rvalid,
    output logic        m_axi_rready,
    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rlast,

    // ---- Interrupts ----
    output logic        irq_rm_empty,
    output logic        irq_rm_error,
    output logic        irq_block,
    output logic [1:0]  irq_block_status
);

    // Instantiate interfaces and wire scalar ports into them
    csr_soc_bus_if soc_bus (.clk(clk), .rst_n(rst_n));
    axi_4_if       axi_sys (.clk(clk), .rst_n(rst_n));

    // AXI-Lite CSR connections (soc modport = driver side)
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

    // AXI4 master connections
    assign m_axi_awvalid   = axi_sys.awvalid;
    assign axi_sys.awready = m_axi_awready;
    assign m_axi_awaddr    = axi_sys.awaddr;
    assign m_axi_awlen     = axi_sys.awlen;

    assign m_axi_wvalid    = axi_sys.wvalid;
    assign axi_sys.wready  = m_axi_wready;
    assign m_axi_wdata     = axi_sys.wdata;
    assign m_axi_wlast     = axi_sys.wlast;

    assign axi_sys.bvalid  = m_axi_bvalid;
    assign m_axi_bready    = axi_sys.bready;
    assign axi_sys.bresp   = m_axi_bresp;

    assign m_axi_arvalid   = axi_sys.arvalid;
    assign axi_sys.arready = m_axi_arready;
    assign m_axi_araddr    = axi_sys.araddr;
    assign m_axi_arlen     = axi_sys.arlen;

    assign axi_sys.rvalid  = m_axi_rvalid;
    assign m_axi_rready    = axi_sys.rready;
    assign axi_sys.rdata   = m_axi_rdata;
    assign axi_sys.rresp   = m_axi_rresp;
    assign axi_sys.rlast   = m_axi_rlast;

    dma_top #(
        .MAX_INFLIGHT(MAX_INFLIGHT)
    ) u_dma_top (
        .clk              (clk),
        .rst_n            (rst_n),
        .soc_bus          (soc_bus.soc),
        .axi_sys          (axi_sys.master),
        .irq_rm_empty     (irq_rm_empty),
        .irq_rm_error     (irq_rm_error),
        .irq_block        (irq_block),
        .irq_block_status (irq_block_status)
    );

endmodule
