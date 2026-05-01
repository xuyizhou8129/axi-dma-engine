//This is the top level module for the DMA top + System Memory (The synthesizable system memory)
//Basically originally in tb_top.sv, we had the dma_top module and the sys_mem module wired together there
// Now we want to have another top level that have them wired together in this file and then use it directly in the tb_top.sv
//Everything else should be exactly the same
//To validate you did the right thing, run make sim-all in the sim directory and see if the test passes after your changes

module system_top #(
    parameter int MEM_WORDS = 1024
) (
    input  logic        clk,
    input  logic        rst_n,

    // AXI4-Lite CSR bus (driven by testbench / SoC)
    csr_soc_bus_if.soc  soc_bus,

    // IRQ outputs (legacy ring-manager pulses + consolidated IRQ block)
    output logic        irq_rm_empty,
    output logic        irq_rm_error,
    output logic        irq_block,
    output logic [1:0]  irq_block_status
);

    // Internal AXI4 bus connecting dma_top (master) to sys_mem (slave)
    axi_4_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axi_sys (.clk(clk), .rst_n(rst_n));

    // DMA engine
    dma_top u_dma (
        .clk             (clk),
        .rst_n           (rst_n),
        .soc_bus         (soc_bus),
        .axi_sys         (axi_sys),
        .irq_rm_empty    (irq_rm_empty),
        .irq_rm_error    (irq_rm_error),
        .irq_block       (irq_block),
        .irq_block_status(irq_block_status)
    );

    // Synthesizable system memory (AXI4 slave)
    sys_mem #(
        .MEM_WORDS(MEM_WORDS)
    ) u_sysmem (
        .axi(axi_sys)
    );

endmodule
