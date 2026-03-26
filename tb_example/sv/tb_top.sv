// Testbench Top - Simplified for Milestone 0
// Only what's needed for register smoke test

`timescale 1ns/1ps

module tb_top;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // AXI4-Lite Interface - instantiate the interface
    axi_lite_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axil_if (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("Reset released at time %0t", $time);
    end

    // DUT instantiation
    dma_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .axil(axil_if.slave)
    );

    // AXI-Lite BFM (for register access) - using interface modport
    axi_lite_bfm #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axil_bfm (
        .axil(axil_if.master)
    );

    // Instantiate the smoke test
    t_reg_smoke test();

endmodule
