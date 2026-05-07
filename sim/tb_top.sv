`timescale 1ns / 1ps
// ============================================================================
// tb_dma_top — system-level testbench for system_top
//
// Instantiation hierarchy
//   tb_dma_top
//     system_top dut  (rtl/system_top.sv)
//       dma_top u_dma  (rtl/dma_top.sv)
//         csr, ring_manager, IRQ, movement_top
//           axi_4_master, sram_controller, descriptor_fetcher, bram, FIFOs
//       sys_mem u_sysmem  (rtl/sys_mem.sv)
//
// Stimulus flow
//   1. Assert reset.
//   2. model_sys_mem loads initial_smem.hex (via +MEMHEX= plusarg or default path).
//      load_initial_sram() loads out/initial_sram.hex into dut BRAM (matches run_golden.py).
//   3. load_stim() reads out/stim.txt and issues CSR writes through axil_write().
//      Each line is either:
//        csr_write <byte_offset_hex> <data_hex>
//        (# comment — ignored)
//   4. Wait up to TIMEOUT cycles for ring_empty status.
//   5. check_mem()   — compare model_sys_mem.ram[] against out/golden_smem.hex
//   6. check_sram()  — compare dut BRAM mem[] against out/golden_sram.hex (Python model)
//   7. check_irq()   — verify at least one irq_rm_empty pulse was observed
//
// ============================================================================

module tb_dma_top;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam int  MEM_WORDS      = 1024;
    localparam int  BRAM_WORDS     = dma_pkg::BRAM_SIZE;
    localparam int  CLK_HALF_NS    = 5;      // 100 MHz
    localparam int  TIMEOUT_CYCLES = 50_000;
    localparam int  RESET_CYCLES   = 8;

    // CSR register byte offsets (matches dma_pkg.sv / csr.py)
    localparam logic [31:0] CSR_CTRL       = 32'h10;
    localparam logic [31:0] CSR_STATUS     = 32'h14;
    localparam logic [31:0] CSR_IRQ_STATUS = 32'h18;
    localparam logic [1:0]  RING_EMPTY_BIT = 2'd1;   // STATUS[1]
    localparam int          CTRL_ENABLE_BIT = 0;

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
    csr_soc_bus_if soc_bus (.clk(clk), .rst_n(rst_n));

    // -----------------------------------------------------------------------
    // DUT: system_top = dma_top (u_dma) + sys_mem (u_sysmem)
    // Internal AXI4 bus between them is inside system_top.
    // -----------------------------------------------------------------------
    logic        irq_rm_empty;
    logic        irq_rm_error;
    logic        irq_block;
    logic [1:0]  irq_block_status;

    system_top #(
        .MEM_WORDS(MEM_WORDS)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .soc_bus         (soc_bus),
        .irq_rm_empty    (irq_rm_empty),
        .irq_rm_error    (irq_rm_error),
        .irq_block       (irq_block),
        .irq_block_status(irq_block_status)
    );

    // -----------------------------------------------------------------------
    // IRQ observation
    // -----------------------------------------------------------------------
    logic irq_empty_seen;
    logic irq_error_seen;
    logic expect_error;
    logic tb_pass;

    initial begin
        expect_error = $test$plusargs("EXPECT_ERROR");
        tb_pass      = 1'b0;
    end

    // -----------------------------------------------------------------------
    // Throughput timing: free-running cycle counter + start/stop capture.
    // start_cycle = cycle the CTRL.ENABLE write is accepted by the AXI-Lite
    //               slave (awready & wready high).
    // stop_cycle  = first cycle ring is empty AND not busy after start.
    // -----------------------------------------------------------------------
    longint unsigned cycle_count;
    longint unsigned start_cycle;
    longint unsigned stop_cycle;
    logic            timing_armed;
    logic            timing_done;

    initial begin
        start_cycle  = '0;
        stop_cycle   = '0;
        timing_armed = 1'b0;
        timing_done  = 1'b0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= '0;
        end else begin
            cycle_count <= cycle_count + 1;
            // Latch first cycle of ring_empty && !busy after timing armed.
            if (timing_armed && !timing_done &&
                dut.u_dma.ring_mgr.ring_empty &&
                !dut.u_dma.ring_mgr.busy) begin
                stop_cycle  <= cycle_count;
                timing_done <= 1'b1;
            end
        end
    end

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
        logic kick;
        // A "kick" is a write to CTRL with ENABLE=1 — that is the instruction
        // we time from. Capture the cycle AW/W are accepted.
        kick = (addr == CSR_CTRL) && data[CTRL_ENABLE_BIT] && !timing_armed;
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
        if (kick) begin
            start_cycle  = cycle_count;
            timing_armed = 1'b1;
        end
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
        int     fh;
        int     n;
        integer csr_addr, csr_data;   // integer required for $sscanf %x in Questa
        reg [2047:0] line;

        fh = $fopen(path, "r");
        if (fh == 0) begin
            $display("FATAL: cannot open %s  (run run_golden.py first)", path);
            $finish(1);
        end

        n = 0;
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            // $fgets into reg[N:0] stores string MSB-first; first char is at line[2047:2040]
            if (line[2047:2040] == 8'h0A) continue;   // blank
            if (line[2047:2040] == 8'h23) continue;   // '#'
            if ($sscanf(line, "csr_write %x %x", csr_addr, csr_data) == 2) begin
                axil_write(csr_addr[31:0], csr_data[31:0]);
                n = n + 1;
            end
        end
        $fclose(fh);
        $display("TB: applied %0d CSR write(s) from %s", n, path);
    endtask

    // -----------------------------------------------------------------------
    // Preload sys_mem RAM from initial_smem.hex (descriptor ring + data).
    // Same flat-array copy trick used below for BRAM.
    // -----------------------------------------------------------------------
    task automatic load_initial_smem();
        logic [31:0] smem_init [0:MEM_WORDS-1];
        int i;
        $readmemh("out/initial_smem.hex", smem_init);
        for (i = 0; i < MEM_WORDS; i = i + 1)
            dut.u_sysmem.ram[i] = smem_init[i];
    endtask

    // -----------------------------------------------------------------------
    // Preload BRAM from initial_sram.hex (same image Python uses at DMA start)
    //
    // Note: $readmemh(dut....mem) into a hierarchical 2-D array often does NOT
    // load in Questa/ModelSim (mem stays X). Load a flat TB array then copy.
    // -----------------------------------------------------------------------
    task automatic load_initial_sram();
        logic [31:0] sram_init [0:BRAM_WORDS-1];
        int i;
        $readmemh("out/initial_sram.hex", sram_init);
        for (i = 0; i < BRAM_WORDS; i = i + 1)
            dut.u_dma.u_movement.u_bram.mem[i] = sram_init[i];
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
            if (golden[i] !== dut.u_sysmem.ram[i]) begin
                $display("SMEM mismatch @word%0d: got %08x  exp %08x",
                         i, dut.u_sysmem.ram[i], golden[i]);
                mism = mism + 1;
            end
        end
        if (mism != 0)
            $fatal(1, "check_mem: %0d mismatche(s)", mism);
        $display("TB: check_mem PASS (%0d words compared)", MEM_WORDS);
    endtask

    // -----------------------------------------------------------------------
    // Checker: BRAM (movement_top u_bram) vs golden_sram.hex
    // -----------------------------------------------------------------------
    task automatic check_sram();
        logic [31:0] golden[0:BRAM_WORDS-1];
        int i, mism;
        mism = 0;
        $readmemh("out/golden_sram.hex", golden);
        for (i = 0; i < BRAM_WORDS; i = i + 1) begin
            if (golden[i] !== dut.u_dma.u_movement.u_bram.mem[i]) begin
                $display("SRAM mismatch @word%0d: got %08x  exp %08x",
                         i, dut.u_dma.u_movement.u_bram.mem[i], golden[i]);
                mism = mism + 1;
            end
        end
        if (mism != 0)
            $fatal(1, "check_sram: %0d mismatch(es)", mism);
        $display("TB: check_sram PASS (%0d words compared)", BRAM_WORDS);
    endtask

    // -----------------------------------------------------------------------
    // Checker: IRQ
    // -----------------------------------------------------------------------
    task automatic check_irq();
        if (!irq_empty_seen)
            $fatal(1, "check_irq: irq_rm_empty never fired");
        if (!expect_error && irq_error_seen)
            $fatal(1, "check_irq: unexpected irq_rm_error");
        if (expect_error && !irq_error_seen)
            $fatal(1, "check_irq: EXPECT_ERROR set but irq_rm_error never fired");
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
            if (status[RING_EMPTY_BIT] && !status[0]) break;  // ring empty AND not busy (all in-flight done)
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles >= TIMEOUT_CYCLES)
                $fatal(1, "wait_ring_empty: timed out after %0d cycles", TIMEOUT_CYCLES);
        end
        $display("TB: ring empty after ~%0d CSR polls", cycles + 1);
    endtask

    // -----------------------------------------------------------------------
    // Throughput report
    //
    // Reads out/throughput_info.txt (written by run_golden.py) for the total
    // payload byte count, then reports cycles between the CTRL.ENABLE accept
    // and the first ring_empty && !busy edge.
    // -----------------------------------------------------------------------
    task automatic report_throughput();
        int          fh;
        reg [2047:0] line;
        string       key;
        longint      val;
        longint unsigned total_bytes;
        longint unsigned clk_ns;
        longint unsigned cycles;
        real             bytes_per_cycle;
        real             mbps;

        total_bytes = 0;
        clk_ns      = 10;  // default 100 MHz; overridden by file

        fh = $fopen("out/throughput_info.txt", "r");
        if (fh == 0) begin
            $display("TB: throughput  (out/throughput_info.txt missing — skipping)");
            return;
        end
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            if (line[2047:2040] == 8'h23) continue; // '#'
            if ($sscanf(line, "%s %0d", key, val) == 2) begin
                if (key == "total_payload_bytes") total_bytes = val;
                else if (key == "clk_period_ns")  clk_ns      = val;
            end
        end
        $fclose(fh);

        if (!timing_armed) begin
            $display("TB: throughput  (no CTRL.ENABLE kick observed — skipping)");
            return;
        end
        if (!timing_done) begin
            $display("TB: throughput  (ring never reached empty&&!busy — skipping)");
            return;
        end

        cycles          = stop_cycle - start_cycle;
        bytes_per_cycle = (cycles == 0) ? 0.0 : real'(total_bytes) / real'(cycles);
        // MB/s = bytes / time_s = bytes / (cycles * clk_ns * 1e-9) / 1e6
        //      = bytes_per_cycle * 1e3 / clk_ns
        mbps = (clk_ns == 0) ? 0.0 : bytes_per_cycle * 1000.0 / real'(clk_ns);

        $display("TB: throughput  bytes=%0d  cycles=%0d  start=%0d  stop=%0d  bytes/cycle=%0.3f  MB/s=%0.2f",
                 total_bytes, cycles, start_cycle, stop_cycle, bytes_per_cycle, mbps);
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

        // Preload sys_mem RAM image (descriptor ring + data) before DMA starts
        load_initial_smem();

        // Match Python SRAM image before DMA (zeros + any CSV "sram" rows)
        load_initial_sram();

        // Apply CSR setup from golden runner (baseaddr, ringlen, tail, ctrl.enable)
        load_stim("out/stim.txt");

        // Wait until ring manager reports empty (head caught up to tail)
        wait_ring_empty();

        // Give IRQ logic a few cycles to propagate
        repeat (16) @(posedge clk);

        // Compare system memory against golden
        check_mem();

        // Compare on-chip BRAM against Python golden model
        check_sram();

        // Verify completion IRQ fired
        check_irq();

        // Report end-to-end throughput (CTRL.ENABLE → ring empty && !busy)
        report_throughput();

        $display("*** TB PASS ***");
        tb_pass = 1'b1;
        $finish(0);
    end

endmodule
