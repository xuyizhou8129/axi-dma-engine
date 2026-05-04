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
    parameter int MAX_INFLIGHT = 4,
    parameter int MEM_WORDS    = 256,
    parameter int BRAM_SIZE    = 256,
    parameter int DATA_WIDTH   = 32,
    parameter int ADDR_WIDTH   = 32
) (
    input  logic        clk,
    input  logic        rst_n,

    // ---- AXI-Lite CSR (slave, port 0) ----
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

    // ---- AXI-Lite Init Controller (slave, port 1) ----
    input  logic [31:0] s_axil_init_awaddr,
    input  logic [2:0]  s_axil_init_awprot,
    input  logic        s_axil_init_awvalid,
    output logic        s_axil_init_awready,

    input  logic [31:0] s_axil_init_wdata,
    input  logic [3:0]  s_axil_init_wstrb,
    input  logic        s_axil_init_wvalid,
    output logic        s_axil_init_wready,

    output logic [1:0]  s_axil_init_bresp,
    output logic        s_axil_init_bvalid,
    input  logic        s_axil_init_bready,

    input  logic [31:0] s_axil_init_araddr,
    input  logic [2:0]  s_axil_init_arprot,
    input  logic        s_axil_init_arvalid,
    output logic        s_axil_init_arready,

    output logic [31:0] s_axil_init_rdata,
    output logic [1:0]  s_axil_init_rresp,
    output logic        s_axil_init_rvalid,
    input  logic        s_axil_init_rready,

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

    // -----------------------------------------------------------------------
    // Internal wires: bram init port (threaded through dma_top/movement_top)
    // -----------------------------------------------------------------------
    localparam int BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE);

    logic [BRAM_ADDR_WIDTH-1:0] bram_init_addr;
    logic                       bram_init_wr_en;
    logic [DATA_WIDTH-1:0]      bram_init_din;
    logic [DATA_WIDTH-1:0]      bram_init_dout;

    // Internal wires: sys_mem init port
    logic [ADDR_WIDTH-1:0]      mem_init_addr;
    logic                       mem_init_wr_en;
    logic [DATA_WIDTH-1:0]      mem_init_wdata;
    logic [DATA_WIDTH-1:0]      mem_init_rdata;

    // init_done (unused internally but available to gate DMA if needed)
    logic                       init_done;

    // DMA engine (AXI4 master on axi_sys)
    dma_top #(
        .MAX_INFLIGHT(MAX_INFLIGHT),
        .BRAM_SIZE   (BRAM_SIZE),
        .DATA_WIDTH  (DATA_WIDTH)
    ) u_dma_top (
        .clk              (clk),
        .rst_n            (rst_n),
        .soc_bus          (soc_bus),
        .axi_sys          (axi_sys.master),
        .irq_rm_empty     (irq_rm_empty),
        .irq_rm_error     (irq_rm_error),
        .irq_block        (irq_block),
        .irq_block_status (irq_block_status),
        .init_done        (init_done),
        .bram_init_addr   (bram_init_addr),
        .bram_init_wr_en  (bram_init_wr_en),
        .bram_init_din    (bram_init_din),
        .bram_init_dout   (bram_init_dout)
    );

    // On-chip SRAM — AXI4 slave on the same axi_sys bus
    sys_mem #(
        .MEM_WORDS(MEM_WORDS)
    ) u_sys_mem (
        .axi          (axi_sys.slave),
        .init_wr_en   (mem_init_wr_en),
        .init_addr    (mem_init_addr),
        .init_wdata   (mem_init_wdata),
        .init_rdata   (mem_init_rdata)
    );

    // Init controller — AXI-Lite slave, drives both memory init ports
    mem_access_ctrl #(
        .BRAM_SIZE  (BRAM_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem_init (
        .clk          (clk),
        .rst_n        (rst_n),

        // AXI-Lite slave port 1
        .awaddr       (s_axil_init_awaddr),
        .awprot       (s_axil_init_awprot),
        .awvalid      (s_axil_init_awvalid),
        .awready      (s_axil_init_awready),
        .wdata        (s_axil_init_wdata),
        .wstrb        (s_axil_init_wstrb),
        .wvalid       (s_axil_init_wvalid),
        .wready       (s_axil_init_wready),
        .bresp        (s_axil_init_bresp),
        .bvalid       (s_axil_init_bvalid),
        .bready       (s_axil_init_bready),
        .araddr       (s_axil_init_araddr),
        .arprot       (s_axil_init_arprot),
        .arvalid      (s_axil_init_arvalid),
        .arready      (s_axil_init_arready),
        .rdata        (s_axil_init_rdata),
        .rresp        (s_axil_init_rresp),
        .rvalid       (s_axil_init_rvalid),
        .rready       (s_axil_init_rready),

        // bram init port
        .bram_init_addr  (bram_init_addr),
        .bram_init_wr_en (bram_init_wr_en),
        .bram_init_din   (bram_init_din),
        .bram_init_dout  (bram_init_dout),

        // sys_mem init port
        .mem_init_addr   (mem_init_addr),
        .mem_init_wr_en  (mem_init_wr_en),
        .mem_init_wdata  (mem_init_wdata),
        .mem_init_rdata  (mem_init_rdata),

        .init_done       (init_done)
    );

endmodule