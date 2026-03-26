// AXI4-Lite Bus Functional Model (BFM)
// Provides tasks for register read/write operations

module axi_lite_bfm #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    // AXI4-Lite Interface - using master modport
    axi_lite_if.master axil
);

    // Clock input (needs to be connected from testbench)
    logic clk;
    assign clk = axil.clk;

    // Write task: write a value to an address
    task write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
        // Write Address Phase
        @(posedge clk);
        axil.awvalid <= 1'b1;
        axil.awaddr <= addr;
        do begin
            @(posedge clk);
        end while (!axil.awready);
        axil.awvalid <= 1'b0;

        // Write Data Phase
        axil.wvalid <= 1'b1;
        axil.wdata <= data;
        do begin
            @(posedge clk);
        end while (!axil.wready);
        axil.wvalid <= 1'b0;

        // Write Response Phase
        axil.bready <= 1'b1;
        do begin
            @(posedge clk);
        end while (!axil.bvalid);
        axil.bready <= 1'b0;

        if (axil.bresp != 2'b00) begin
            $warning("AXI-Lite write response error: %b at address 0x%h", axil.bresp, addr);
        end
    endtask

    // Read task: read a value from an address
    task read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);
        // Read Address Phase
        @(posedge clk);
        axil.arvalid <= 1'b1;
        axil.araddr <= addr;
        do begin
            @(posedge clk);
        end while (!axil.arready);
        axil.arvalid <= 1'b0;

        // Read Data Phase
        axil.rready <= 1'b1;
        do begin
            @(posedge clk);
        end while (!axil.rvalid);
        data = axil.rdata;
        axil.rready <= 1'b0;

        if (axil.rresp != 2'b00) begin
            $warning("AXI-Lite read response error: %b at address 0x%h", axil.rresp, addr);
        end
    endtask

    // Initial state
    initial begin
        axil.awvalid = 1'b0;
        axil.awaddr = '0;
        axil.wvalid = 1'b0;
        axil.wdata = '0;
        axil.bready = 1'b0;
        axil.arvalid = 1'b0;
        axil.araddr = '0;
        axil.rready = 1'b0;
    end

endmodule

