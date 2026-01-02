// AXI4-Lite Interface
// Single interface containing all channels with modports for master/slave views

interface axi_lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);

    // Write Address Channel
    logic                    awvalid;
    logic                    awready;
    logic [ADDR_WIDTH-1:0]   awaddr;

    // Write Data Channel
    logic                    wvalid;
    logic                    wready;
    logic [DATA_WIDTH-1:0]   wdata;

    // Write Response Channel
    logic                    bvalid;
    logic                    bready;
    logic [1:0]              bresp;

    // Read Address Channel
    logic                    arvalid;
    logic                    arready;
    logic [ADDR_WIDTH-1:0]   araddr;

    // Read Data Channel
    logic                    rvalid;
    logic                    rready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;

    // Modport for AXI-Lite Master (e.g., CPU/BFM)
    // Master drives: awvalid, awaddr, wvalid, wdata, bready, arvalid, araddr, rready
    // Master receives: awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    modport master (
        input  clk, rst_n,
        output awvalid, awaddr,
        input  awready,
        output wvalid, wdata,
        input  wready,
        input  bvalid, bresp,
        output bready,
        output arvalid, araddr,
        input  arready,
        input  rvalid, rdata, rresp,
        output rready
    );

    // Modport for AXI-Lite Slave (e.g., CSR/DUT)
    // Slave receives: awvalid, awaddr, wvalid, wdata, bready, arvalid, araddr, rready
    // Slave drives: awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    modport slave (
        input  clk, rst_n,
        input  awvalid, awaddr,
        output awready,
        input  wvalid, wdata,
        output wready,
        output bvalid, bresp,
        input  bready,
        input  arvalid, araddr,
        output arready,
        output rvalid, rdata, rresp,
        input  rready
    );

endinterface

