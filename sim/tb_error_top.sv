`timescale 1ns / 1ps
// ============================================================================
// tb_dma_error_top — directed error-handling tests for dma_top
//
// Run with plusarg:
//   +ERR_TEST=<name>
// where <name> is one of:
//   overflow_sets_error
//   error_latch_blocks_issue
//   error_clear_resumes
//   masked_irq_still_sets_status
//
// This TB does not depend on run_golden.py artifacts.
// It programs descriptors/backdoor memory directly and validates CSR/IRQ behavior.
// ============================================================================

module tb_dma_error_top;

    localparam int MEM_WORDS      = 1024;
    localparam int CLK_HALF_NS    = 5;
    localparam int TIMEOUT_CYCLES = 50_000;

    localparam logic [31:0] CSR_BASEADDR   = 32'h00;
    localparam logic [31:0] CSR_RINGLEN    = 32'h04;
    localparam logic [31:0] CSR_HEAD       = 32'h08;
    localparam logic [31:0] CSR_TAIL       = 32'h0C;
    localparam logic [31:0] CSR_CTRL       = 32'h10;
    localparam logic [31:0] CSR_STATUS     = 32'h14;
    localparam logic [31:0] CSR_IRQ_STATUS = 32'h18;
    localparam logic [31:0] CSR_IRQ_CLEAR  = 32'h2C;

    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    axi_4_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axi_sys (.clk(clk), .rst_n(rst_n));

    csr_soc_bus_if soc_bus (.clk(clk), .rst_n(rst_n));

    logic        irq_rm_empty;
    logic        irq_rm_error;
    logic        irq_block;
    logic [1:0]  irq_block_status;

    dma_top dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .soc_bus         (soc_bus),
        .axi_sys         (axi_sys),
        .irq_rm_empty    (irq_rm_empty),
        .irq_rm_error    (irq_rm_error),
        .irq_block       (irq_block),
        .irq_block_status(irq_block_status)
    );

    sys_mem #(
        .MEM_WORDS(MEM_WORDS)
    ) u_sysmem (
        .axi(axi_sys)
    );

    logic irq_empty_seen;
    logic irq_error_seen;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_empty_seen <= 1'b0;
            irq_error_seen <= 1'b0;
        end else begin
            if (irq_rm_empty) irq_empty_seen <= 1'b1;
            if (irq_rm_error) irq_error_seen <= 1'b1;
        end
    end

    task automatic axil_idle();
        soc_bus.awaddr  = '0;
        soc_bus.awprot  = '0;
        soc_bus.awvalid = 1'b0;
        soc_bus.wdata   = '0;
        soc_bus.wstrb   = '0;
        soc_bus.wvalid  = 1'b0;
        soc_bus.bready  = 1'b0;
        soc_bus.araddr  = '0;
        soc_bus.arprot  = '0;
        soc_bus.arvalid = 1'b0;
        soc_bus.rready  = 1'b0;
    endtask

    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        soc_bus.awaddr  = addr;
        soc_bus.awprot  = 3'b000;
        soc_bus.awvalid = 1'b1;
        soc_bus.wdata   = data;
        soc_bus.wstrb   = 4'hF;
        soc_bus.wvalid  = 1'b1;
        soc_bus.bready  = 1'b1;
        @(posedge clk);
        while (!(soc_bus.awready && soc_bus.wready)) @(posedge clk);
        soc_bus.awvalid = 1'b0;
        soc_bus.wvalid  = 1'b0;
        while (!soc_bus.bvalid) @(posedge clk);
        soc_bus.bready = 1'b0;
        @(posedge clk);
    endtask

    task automatic axil_read(input logic [31:0] addr, output logic [31:0] rdata);
        soc_bus.araddr  = addr;
        soc_bus.arprot  = 3'b000;
        soc_bus.arvalid = 1'b1;
        soc_bus.rready  = 1'b1;
        @(posedge clk);
        while (!soc_bus.arready) @(posedge clk);
        soc_bus.arvalid = 1'b0;
        while (!soc_bus.rvalid)  @(posedge clk);
        rdata          = soc_bus.rdata;
        soc_bus.rready = 1'b0;
        @(posedge clk);
    endtask

    task automatic write_desc(
        input int unsigned word_base,
        input logic [31:0] src,
        input logic [31:0] dst,
        input logic [31:0] len,
        input logic [31:0] flags
    );
        u_sysmem.ram[word_base + 0] = src;
        u_sysmem.ram[word_base + 1] = dst;
        u_sysmem.ram[word_base + 2] = len;
        u_sysmem.ram[word_base + 3] = flags;
    endtask

    task automatic wait_status_error_set();
        logic [31:0] status;
        int cycles;
        cycles = 0;
        forever begin
            axil_read(CSR_STATUS, status);
            if (status[2]) break;
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles >= TIMEOUT_CYCLES)
                $fatal(1, "wait_status_error_set: timed out");
        end
    endtask

    task automatic wait_ring_empty_and_idle();
        logic [31:0] status;
        int cycles;
        cycles = 0;
        forever begin
            axil_read(CSR_STATUS, status);
            if (status[1] && !status[0]) break;
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles >= TIMEOUT_CYCLES)
                $fatal(1, "wait_ring_empty_and_idle: timed out");
        end
    endtask

    task automatic reset_dut();
        rst_n = 1'b0;
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    task automatic tc_overflow_sets_error();
        logic [31:0] status;
        logic [31:0] irq_status;

        $display("TC overflow_sets_error: start");
        reset_dut();

        // Descriptor ring at word 64; one descriptor with illegal SRAM side address.
        write_desc(
            64,
            32'h00000000,
            32'h00040000,
            32'h00000004,
            32'h00000001
        );

        axil_write(CSR_BASEADDR, 32'h00000100);
        axil_write(CSR_RINGLEN,  32'h00000002);
        axil_write(CSR_TAIL,     32'h00000001);
        axil_write(CSR_CTRL,     32'h00000005); // enable + irq_en

        wait_status_error_set();

        axil_read(CSR_STATUS, status);
        axil_read(CSR_IRQ_STATUS, irq_status);
        if (!status[2])
            $fatal(1, "overflow_sets_error: STATUS.error not set");
        if (!irq_status[1])
            $fatal(1, "overflow_sets_error: IRQ_STATUS.error not set");
        if (!irq_error_seen)
            $fatal(1, "overflow_sets_error: irq_rm_error pulse not observed");

        $display("TC overflow_sets_error: PASS");
    endtask

    task automatic tc_error_latch_blocks_issue();
        logic [31:0] head_before;
        logic [31:0] head_after;

        $display("TC error_latch_blocks_issue: start");
        reset_dut();

        // desc0 (bad): triggers df_error.
        write_desc(64, 32'h00000000, 32'h00040000, 32'h00000004, 32'h00000001);
        // desc1 (good): would write sysmem[200] -> bram[0] if issued.
        write_desc(68, 32'h00000320, 32'h00000000, 32'h00000001, 32'h00000001);
        u_sysmem.ram[200] = 32'hA5A5F00D;

        axil_write(CSR_BASEADDR, 32'h00000100);
        axil_write(CSR_RINGLEN,  32'h00000004);
        axil_write(CSR_TAIL,     32'h00000002);
        axil_write(CSR_CTRL,     32'h00000005); // enable + irq_en

        wait_status_error_set();
        axil_read(CSR_HEAD, head_before);
        repeat (128) @(posedge clk);
        axil_read(CSR_HEAD, head_after);

        if (head_after != head_before)
            $fatal(1, "error_latch_blocks_issue: head advanced despite latched error (%0d -> %0d)",
                   head_before, head_after);
        if (dut.fetch_req_valid !== 1'b0)
            $fatal(1, "error_latch_blocks_issue: fetch_req_valid should be low while latched error");

        $display("TC error_latch_blocks_issue: PASS");
    endtask

    task automatic tc_error_clear_resumes();
        logic [31:0] status;
        logic [31:0] irq_status;

        $display("TC error_clear_resumes: start");
        reset_dut();

        // desc0 (bad): latches error.
        write_desc(64, 32'h00000000, 32'h00040000, 32'h00000004, 32'h00000001);
        // desc1 (good): expected to execute after error clear.
        write_desc(68, 32'h00000320, 32'h00000000, 32'h00000001, 32'h00000001);
        u_sysmem.ram[200] = 32'hCAFEBABE;

        axil_write(CSR_BASEADDR, 32'h00000100);
        axil_write(CSR_RINGLEN,  32'h00000004);
        axil_write(CSR_TAIL,     32'h00000002);
        axil_write(CSR_CTRL,     32'h00000005); // enable + irq_en

        wait_status_error_set();

        // Clear error via IRQ_CLEAR[1].
        axil_write(CSR_IRQ_CLEAR, 32'h00000002);

        wait_ring_empty_and_idle();

        axil_read(CSR_STATUS, status);
        axil_read(CSR_IRQ_STATUS, irq_status);

        if (status[2])
            $fatal(1, "error_clear_resumes: STATUS.error remained set after clear+drain");
        if (irq_status[1])
            $fatal(1, "error_clear_resumes: IRQ_STATUS.error remained set after clear");

        if (dut.u_movement.u_bram.mem[0] !== 32'hCAFEBABE)
            $fatal(1, "error_clear_resumes: good descriptor did not execute after clear");

        $display("TC error_clear_resumes: PASS");
    endtask

    task automatic tc_masked_irq_still_sets_status();
        logic [31:0] status;
        logic [31:0] irq_status;

        $display("TC masked_irq_still_sets_status: start");
        reset_dut();

        write_desc(64, 32'h00000000, 32'h00040000, 32'h00000004, 32'h00000001);

        axil_write(CSR_BASEADDR, 32'h00000100);
        axil_write(CSR_RINGLEN,  32'h00000002);
        axil_write(CSR_TAIL,     32'h00000001);
        axil_write(CSR_CTRL,     32'h00000001); // enable only, irq_en=0

        wait_status_error_set();
        repeat (8) @(posedge clk);

        axil_read(CSR_STATUS, status);
        axil_read(CSR_IRQ_STATUS, irq_status);

        if (!status[2])
            $fatal(1, "masked_irq_still_sets_status: STATUS.error not set");
        if (!irq_status[1])
            $fatal(1, "masked_irq_still_sets_status: IRQ_STATUS.error not set");
        if (irq_error_seen)
            $fatal(1, "masked_irq_still_sets_status: irq_rm_error should be masked when irq_en=0");

        $display("TC masked_irq_still_sets_status: PASS");
    endtask

    initial begin
        string tc;

        axil_idle();
        rst_n = 1'b0;

        if (!$value$plusargs("ERR_TEST=%s", tc)) begin
            $display("FATAL: missing +ERR_TEST=<name>");
            $finish(1);
        end

        if (tc == "overflow_sets_error") begin
            tc_overflow_sets_error();
        end else if (tc == "error_latch_blocks_issue") begin
            tc_error_latch_blocks_issue();
        end else if (tc == "error_clear_resumes") begin
            tc_error_clear_resumes();
        end else if (tc == "masked_irq_still_sets_status") begin
            tc_masked_irq_still_sets_status();
        end else begin
            $display("FATAL: unknown ERR_TEST '%s'", tc);
            $finish(1);
        end

        $display("*** TB ERROR TEST PASS (%s) ***", tc);
        $finish(0);
    end

endmodule
