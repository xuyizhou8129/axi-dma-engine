// AXI4 Interface
// Single interface containing all channels with modports for master/slave views
// representing the connection between the AXI4 Master and the System Memory

interface axi_4_if #(
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH
)(
    input logic clk,
    input logic rst_n
);

    // Write Address Channel
    logic                    awvalid;
    logic                    awready;
    logic [7:0]              awlen;
    //logic [2:0]              awsize;
    //logic [1:0]              awburst;
    //logic [AXI_ID_WIDTH-1:0] awid;
    logic [ADDR_WIDTH-1:0]   awaddr;

    // Write Data Channel
    logic                    wvalid;
    logic                    wready;
    logic [DATA_WIDTH-1:0]   wdata;
    //logic [(DATA_WIDTH/8)-1:0] wstrb; //let us write into individual bytes if needed
    logic                    wlast;

    // Write Response Channel
    logic                    bvalid;
    logic                    bready;
    logic [1:0]              bresp;

    // Read Address Channel
    logic                    arvalid;
    logic                    arready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic [7:0]              arlen;
    //logic [2:0]              arsize;
    //logic [1:0]              arburst;
    //logic [AXI_ID_WIDTH-1:0] arid;

    // Read Data Channel
    logic                    rvalid;
    logic                    rready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;
    logic                    rlast;

    // Modport for AXI4 Master
    // Master drives: awvalid, awaddr, wvalid, wdata, bready, arvalid, araddr, rready
    // Master receives: awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    modport master (
        input  clk, rst_n,
        output awvalid, awaddr, awlen,
        input  awready,
        output wvalid, wdata, wlast,
        input  wready,
        input  bvalid, bresp,
        output bready,
        output arvalid, araddr, arlen,
        input  arready,
        input  rvalid, rdata, rresp, rlast,
        output rready
    );

    // Modport for AXI4 Slave
    // Slave receives: awvalid, awaddr, wvalid, wdata, bready, arvalid, araddr, rready
    // Slave drives: awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    modport slave (
        input  clk, rst_n,
        input  awvalid, awaddr, awlen,
        output awready,
        input  wvalid, wdata, wlast,
        output wready,
        output bvalid, bresp,
        input  bready,
        input  arvalid, araddr, arlen,
        output arready,
        output rvalid, rdata, rresp, rlast,
        input  rready
    );

endinterface

