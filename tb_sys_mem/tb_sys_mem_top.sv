// Structural top: sys_mem DUT + read-data capture registers.
// Stimulus and checks live in tb_sys_mem.sv.

`timescale 1ns / 1ps

module tb_sys_mem_top (
    input logic clk,
    input logic rst_n,

    // Write address channel
    input  logic [31:0] awaddr,
    input  logic [7:0]  awlen,
    input  logic        awvalid,
    output logic        awready,

    // Write data channel
    input  logic [31:0] wdata,
    input  logic        wlast,
    input  logic        wvalid,
    output logic        wready,

    // Write response channel
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,

    // Read address channel
    input  logic [31:0] araddr,
    input  logic [7:0]  arlen,
    input  logic        arvalid,
    output logic        arready,

    // Read data channel
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rlast,
    output logic        rvalid,
    input  logic        rready
);

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int MEM_WORDS  = 256;
    localparam int MAX_CAP    = 512;

    axi_4_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi (.clk(clk), .rst_n(rst_n));

    // Map flat TB ports to interface signals
    assign axi.awaddr  = awaddr;
    assign axi.awlen   = awlen;
    assign axi.awvalid = awvalid;
    assign awready     = axi.awready;

    assign axi.wdata   = wdata;
    assign axi.wlast   = wlast;
    assign axi.wvalid  = wvalid;
    assign wready      = axi.wready;

    assign bvalid      = axi.bvalid;
    assign bresp       = axi.bresp;
    assign axi.bready  = bready;

    assign axi.araddr  = araddr;
    assign axi.arlen   = arlen;
    assign axi.arvalid = arvalid;
    assign arready     = axi.arready;

    assign rdata       = axi.rdata;
    assign rresp       = axi.rresp;
    assign rlast       = axi.rlast;
    assign rvalid      = axi.rvalid;
    assign axi.rready  = rready;

    sys_mem #(
        .MEM_WORDS (MEM_WORDS),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (.axi(axi));

    // Capture all read data beats for scoreboard
    logic [DATA_WIDTH-1:0] cap_rdata[0:MAX_CAP-1];
    integer n_cap_rdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_cap_rdata <= 0;
        end else begin
            if (rvalid && rready && n_cap_rdata < MAX_CAP) begin
                cap_rdata[n_cap_rdata] <= rdata;
                n_cap_rdata            <= n_cap_rdata + 1;
            end
        end
    end

endmodule
