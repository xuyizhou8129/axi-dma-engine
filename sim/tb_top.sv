`timescale 1ns / 1ps
// ============================================================================
// tb_dma_top — system-level testbench for dma_top
//
// Instantiation hierarchy
//   tb_dma_top
//     dma_top  (DUT — rtl/dma_top.sv)
//       csr, ring_manager, IRQ, movement_top
//         axi_4_master, sram_controller, descriptor_fetcher, bram, FIFOs
//     model_sys_mem (AXI4 behavioural system memory)
//
// Stimulus flow
//   1. Assert reset.
//   2. model_sys_mem loads initial_smem.hex (via +MEMHEX= plusarg or default path).
//   3. load_stim() reads out/stim.txt and issues CSR writes through axil_write().
//      Each line is either:
//        csr_write <byte_offset_hex> <data_hex>
//        (# comment — ignored)
//   4. Wait up to TIMEOUT cycles for ring_empty status.
//   5. check_mem()   — compare model_sys_mem.ram[] against out/golden_smem.hex
//   6. check_irq()   — verify at least one irq_rm_empty pulse was observed
//
// ============================================================================

module tb_dma_top;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam int  MEM_WORDS      = 1024;
    localparam int  CLK_HALF_NS    = 5;      // 100 MHz
    localparam int  TIMEOUT_CYCLES = 50_000;
    localparam int  RESET_CYCLES   = 8;

    // CSR register byte offsets (matches dma_pkg.sv / csr.py)
    localparam logic [31:0] CSR_STATUS     = 32'h14;
    localparam logic [31:0] CSR_IRQ_STATUS = 32'h18;
    localparam logic [1:0]  RING_EMPTY_BIT = 2'd1;   // STATUS[1]

    // -----------------------------------------------------------------------
    // Clock / reset
    // -----------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // -----------------------------------------------------------------------
    // Interfaces
    // -----------------------------------------------------------------------
    axi_4_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axi_sys (.clk(clk), .rst_n(rst_n));

    csr_soc_bus_if soc_bus (.clk(clk), .rst_n(rst_n));

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // Behavioural system memory
    // -----------------------------------------------------------------------
    model_sys_mem #(
        .MEM_WORDS(MEM_WORDS)
    ) u_sysmem (
        .axi(axi_sys)
    );

    // -----------------------------------------------------------------------
    // IRQ observation
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // AXI-Lite driver tasks (single-beat, no burst)
    // -----------------------------------------------------------------------
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        // Write address
        soc_bus.awaddr  = addr;
        soc_bus.awprot  = 3'b000;
        soc_bus.awvalid = 1'b1;
        soc_bus.wdata   = data;
        soc_bus.wstrb   = 4'hF;
        soc_bus.wvalid  = 1'b1;
        soc_bus.bready  = 1'b1;
        @(posedge clk);
        // Hold AW/W until accepted
        while (!(soc_bus.awready && soc_bus.wready)) @(posedge clk);
        soc_bus.awvalid = 1'b0;
        soc_bus.wvalid  = 1'b0;
        // Wait for write response
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

    // -----------------------------------------------------------------------
    // Stimulus loader — parses out/stim.txt
    // -----------------------------------------------------------------------
    task automatic load_stim(input string path);
        int    fh;
        int    n;
        logic [31:0] csr_addr, csr_data;
        reg [2047:0] line;

        fh = $fopen(path, "r");
        if (fh == 0) begin
            $display("FATAL: cannot open %s  (run run_golden.py first)", path);
            $finish(1);
        end

        n = 0;
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            if (line[7:0] == 8'h0A) continue;   // blank
            if (line[7:0] == 8'h23) continue;   // '#'
            if ($sscanf(line, "csr_write %x %x", csr_addr, csr_data) == 2) begin
                axil_write(csr_addr, csr_data);
                n = n + 1;
            end
        end
        $fclose(fh);
        $display("TB: applied %0d CSR write(s) from %s", n, path);
    endtask

    // -----------------------------------------------------------------------
    // Checker: system memory vs golden_smem.hex
    // -----------------------------------------------------------------------
    task automatic check_mem();
        logic [31:0] golden[0:MEM_WORDS-1];
        int i, mism;
        mism = 0;
        $readmemh("out/golden_smem.hex", golden);
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            if (golden[i] !== u_sysmem.ram[i]) begin
                $display("SMEM mismatch @word%0d: got %08x  exp %08x",
                         i, u_sysmem.ram[i], golden[i]);
                mism = mism + 1;
            end
        end
        if (mism != 0)
            $fatal(1, "check_mem: %0d mismatche(s)", mism);
        $display("TB: check_mem PASS (%0d words compared)", MEM_WORDS);
    endtask

    // -----------------------------------------------------------------------
    // Checker: IRQ
    // -----------------------------------------------------------------------
    task automatic check_irq();
        if (!irq_empty_seen)
            $fatal(1, "check_irq: irq_rm_empty never fired");
        if (irq_error_seen)
            $fatal(1, "check_irq: unexpected irq_rm_error");
        $display("TB: check_irq PASS");
    endtask

    // -----------------------------------------------------------------------
    // Checker: ring empty via CSR STATUS
    // -----------------------------------------------------------------------
    task automatic wait_ring_empty();
        logic [31:0] status;
        int cycles;
        cycles = 0;
        forever begin
            axil_read(CSR_STATUS, status);
            if (status[RING_EMPTY_BIT]) break;
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles >= TIMEOUT_CYCLES)
                $fatal(1, "wait_ring_empty: timed out after %0d cycles", TIMEOUT_CYCLES);
        end
        $display("TB: ring empty after ~%0d CSR polls", cycles + 1);
    endtask

    // -----------------------------------------------------------------------
    // AXI-Lite idle initialisation
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        // Initialise AXI-Lite to idle
        axil_idle();
        rst_n = 1'b0;

        // Release reset after a few cycles; model_sys_mem loads MEMHEX on first clk
        repeat (RESET_CYCLES) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Give model_sys_mem one cycle to set ram_preloaded
        repeat (4) @(posedge clk);

        // Apply CSR setup from golden runner (baseaddr, ringlen, tail, ctrl.enable)
        load_stim("out/stim.txt");

        // Wait until ring manager reports empty (head caught up to tail)
        wait_ring_empty();

        // Give IRQ logic a few cycles to propagate
        repeat (16) @(posedge clk);

        // Compare system memory against golden
        check_mem();

        // Verify completion IRQ fired
        check_irq();

        $display("*** TB PASS ***");
        $finish(0);
    end

endmodule
