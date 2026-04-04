`timescale 1ns / 1ns

module csr_tb;

    // ----------------------------------------------------------------
    // Clock and reset
    // ----------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // ----------------------------------------------------------------
    // Interface instantiation
    // ----------------------------------------------------------------
    csr_soc_bus_if soc_bus (
        .clk   (clk),
        .rst_n (rst_n)
    );

    csr_ring_manager_if ring_mgr (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    csr dut (
        .soc_bus (soc_bus),
        .ring_mgr(ring_mgr)
    );

    // ----------------------------------------------------------------
    // Register address constants (mirrors CSR localparams)
    // ----------------------------------------------------------------
    localparam logic [31:0] ADDR_BASEADDR   = 32'h00;
    localparam logic [31:0] ADDR_RINGLEN    = 32'h04;
    localparam logic [31:0] ADDR_HEAD       = 32'h08;
    localparam logic [31:0] ADDR_TAIL       = 32'h0C;
    localparam logic [31:0] ADDR_CTRL       = 32'h10;
    localparam logic [31:0] ADDR_STATUS     = 32'h14;
    localparam logic [31:0] ADDR_IRQ_STATUS = 32'h18;
    localparam logic [31:0] ADDR_IRQ_CLEAR  = 32'h2C;

    // ----------------------------------------------------------------
    // Test counters
    // ----------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // ----------------------------------------------------------------
    // AXI-Lite write task: drives AW+W simultaneously, waits for B.
    // ----------------------------------------------------------------
    task automatic axil_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb = 4'hF
    );
        // Drive AW and W channels on the same cycle
        @(posedge clk);
        soc_bus.awaddr  <= addr;
        soc_bus.awprot  <= 3'd0;
        soc_bus.awvalid <= 1'b1;
        soc_bus.wdata   <= data;
        soc_bus.wstrb   <= strb;
        soc_bus.wvalid  <= 1'b1;

        // Wait for AW handshake
        fork
            begin
                forever begin
                    @(posedge clk);
                    if (soc_bus.awready) begin
                        soc_bus.awvalid <= 1'b0;
                        break;
                    end
                end
            end
            begin
                forever begin
                    @(posedge clk);
                    if (soc_bus.wready) begin
                        soc_bus.wvalid <= 1'b0;
                        break;
                    end
                end
            end
        join

        // Wait for B response
        soc_bus.bready <= 1'b1;
        forever begin
            @(posedge clk);
            if (soc_bus.bvalid) begin
                soc_bus.bready <= 1'b0;
                break;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // AXI-Lite read task: drives AR, waits for R, returns data.
    // ----------------------------------------------------------------
    task automatic axil_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        @(posedge clk);
        soc_bus.araddr  <= addr;
        soc_bus.arprot  <= 3'd0;
        soc_bus.arvalid <= 1'b1;

        // Wait for AR handshake
        forever begin
            @(posedge clk);
            if (soc_bus.arready) begin
                soc_bus.arvalid <= 1'b0;
                break;
            end
        end

        // Wait for R response
        soc_bus.rready <= 1'b1;
        forever begin
            @(posedge clk);
            if (soc_bus.rvalid) begin
                data = soc_bus.rdata;
                soc_bus.rready <= 1'b0;
                break;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Check helper: compare actual vs expected, print result.
    // ----------------------------------------------------------------
    task automatic check(
        input string       name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        if (actual === expected) begin
            $display("[PASS] %s: 0x%08h", name, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s: got 0x%08h, expected 0x%08h", name, actual, expected);
            fail_count++;
        end
    endtask

    // ----------------------------------------------------------------
    // Ring manager side defaults: deassert all event signals.
    // ----------------------------------------------------------------
    task automatic rm_defaults();
        ring_mgr.head          <= 32'd0;
        ring_mgr.busy          <= 1'b0;
        ring_mgr.ring_empty    <= 1'b0;
        ring_mgr.irq_empty_set <= 1'b0;
        ring_mgr.error_set     <= 1'b0;
    endtask

    // ----------------------------------------------------------------
    // SoC bus side defaults: deassert all valid/ready signals.
    // ----------------------------------------------------------------
    task automatic soc_defaults();
        soc_bus.awaddr  <= '0;
        soc_bus.awprot  <= '0;
        soc_bus.awvalid <= 1'b0;
        soc_bus.wdata   <= '0;
        soc_bus.wstrb   <= '0;
        soc_bus.wvalid  <= 1'b0;
        soc_bus.bready  <= 1'b0;
        soc_bus.araddr  <= '0;
        soc_bus.arprot  <= '0;
        soc_bus.arvalid <= 1'b0;
        soc_bus.rready  <= 1'b0;
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    logic [31:0] rd_data;

    initial begin
        $display("=== CSR Testbench Start ===");
        soc_defaults();
        rm_defaults();

        // ---- Reset ----
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // ============================================================
        // Test 1: Reset values - all registers should read 0
        // ============================================================
        $display("\n--- Test 1: Reset values ---");

        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR reset", rd_data, 32'h0);

        axil_read(ADDR_RINGLEN, rd_data);
        check("RINGLEN reset", rd_data, 32'h0);

        axil_read(ADDR_HEAD, rd_data);
        check("HEAD reset", rd_data, 32'h0);

        axil_read(ADDR_TAIL, rd_data);
        check("TAIL reset", rd_data, 32'h0);

        axil_read(ADDR_CTRL, rd_data);
        check("CTRL reset", rd_data, 32'h0);

        axil_read(ADDR_STATUS, rd_data);
        check("STATUS reset", rd_data, 32'h0);

        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ_STATUS reset", rd_data, 32'h0);

        axil_read(ADDR_IRQ_CLEAR, rd_data);
        check("IRQ_CLEAR reset (reads 0)", rd_data, 32'h0);

        // ============================================================
        // Test 2: R/W register write and readback
        // ============================================================
        $display("\n--- Test 2: R/W register write/readback ---");

        axil_write(ADDR_BASEADDR, 32'hDEAD_0000);
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR write", rd_data, 32'hDEAD_0000);

        axil_write(ADDR_RINGLEN, 32'h0000_0100);
        axil_read(ADDR_RINGLEN, rd_data);
        check("RINGLEN write", rd_data, 32'h0000_0100);

        axil_write(ADDR_TAIL, 32'h0000_0042);
        axil_read(ADDR_TAIL, rd_data);
        check("TAIL write", rd_data, 32'h0000_0042);

        // ============================================================
        // Test 3: CTRL register - reserved bits masked to 0
        // ============================================================
        $display("\n--- Test 3: CTRL reserved bits ---");

        axil_write(ADDR_CTRL, 32'hFFFF_FFFF);
        axil_read(ADDR_CTRL, rd_data);
        check("CTRL reserved mask", rd_data, 32'h0000_0005);
        // Note: bit[1] (RESET) triggers soft reset next cycle,
        // which clears CTRL to 0. We read after reset completes.
        // The write stores 3'b111 -> RESET fires -> CTRL clears to 0.
        // Let's verify that by reading again after a cycle.
        @(posedge clk);
        axil_read(ADDR_CTRL, rd_data);
        check("CTRL after soft reset auto-clear", rd_data, 32'h0);

        // Re-program registers after soft reset cleared them
        axil_write(ADDR_BASEADDR, 32'hBEEF_0000);
        axil_write(ADDR_RINGLEN, 32'h0000_0010);
        axil_write(ADDR_TAIL, 32'h0000_0005);

        // Write CTRL with only ENABLE (no RESET)
        axil_write(ADDR_CTRL, 32'h0000_0001);
        axil_read(ADDR_CTRL, rd_data);
        check("CTRL ENABLE only", rd_data, 32'h0000_0001);

        // ============================================================
        // Test 4: HEAD is read-only (driven by ring manager)
        // ============================================================
        $display("\n--- Test 4: HEAD read-only ---");

        ring_mgr.head <= 32'h0000_0007;
        @(posedge clk);
        axil_read(ADDR_HEAD, rd_data);
        check("HEAD from ring_mgr", rd_data, 32'h0000_0007);

        // Write to HEAD should have no effect
        axil_write(ADDR_HEAD, 32'hFFFF_FFFF);
        axil_read(ADDR_HEAD, rd_data);
        check("HEAD unchanged after write", rd_data, 32'h0000_0007);

        // ============================================================
        // Test 5: STATUS register (read-only, composed from hw signals)
        // ============================================================
        $display("\n--- Test 5: STATUS register ---");

        ring_mgr.busy       <= 1'b1;
        ring_mgr.ring_empty <= 1'b0;
        @(posedge clk);
        axil_read(ADDR_STATUS, rd_data);
        check("STATUS busy=1", rd_data, 32'h0000_0001);

        ring_mgr.busy       <= 1'b0;
        ring_mgr.ring_empty <= 1'b1;
        @(posedge clk);
        axil_read(ADDR_STATUS, rd_data);
        check("STATUS ring_empty=1", rd_data, 32'h0000_0002);

        ring_mgr.busy       <= 1'b0;
        ring_mgr.ring_empty <= 1'b0;
        @(posedge clk);

        // ============================================================
        // Test 6: IRQ sticky set via hardware events
        // ============================================================
        $display("\n--- Test 6: IRQ sticky bits ---");

        // Pulse irq_empty_set for one cycle
        ring_mgr.irq_empty_set <= 1'b1;
        @(posedge clk);
        ring_mgr.irq_empty_set <= 1'b0;
        @(posedge clk);

        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ_STATUS empty latched", rd_data, 32'h0000_0001);

        // Pulse error_set for one cycle
        ring_mgr.error_set <= 1'b1;
        @(posedge clk);
        ring_mgr.error_set <= 1'b0;
        @(posedge clk);

        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ_STATUS empty+error latched", rd_data, 32'h0000_0003);

        // STATUS.ERROR should also be sticky
        axil_read(ADDR_STATUS, rd_data);
        check("STATUS.ERROR sticky", rd_data[2], 1'b1);

        // ============================================================
        // Test 7: IRQ_CLEAR write-1-to-clear
        // ============================================================
        $display("\n--- Test 7: IRQ_CLEAR W1C ---");

        // Clear only EMPTY (bit 0)
        axil_write(ADDR_IRQ_CLEAR, 32'h0000_0001);
        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ_STATUS after clear empty", rd_data, 32'h0000_0002);

        // Clear ERROR (bit 1) - should also clear STATUS.ERROR
        axil_write(ADDR_IRQ_CLEAR, 32'h0000_0002);
        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ_STATUS after clear error", rd_data, 32'h0000_0000);

        axil_read(ADDR_STATUS, rd_data);
        check("STATUS.ERROR cleared via IRQ_CLEAR[1]", rd_data[2], 1'b0);

        // ============================================================
        // Test 8: IRQ output gating by CTRL.IRQ_EN
        // ============================================================
        $display("\n--- Test 8: IRQ output gating ---");

        // Set an IRQ source
        ring_mgr.irq_empty_set <= 1'b1;
        @(posedge clk);
        ring_mgr.irq_empty_set <= 1'b0;
        @(posedge clk);

        // IRQ_EN is off (CTRL[2]=0), irq output should be 0
        check("irq deasserted (IRQ_EN=0)", soc_bus.irq, 1'b0);

        // Enable IRQ_EN
        axil_write(ADDR_CTRL, 32'h0000_0005); // ENABLE + IRQ_EN
        @(posedge clk);

        check("irq asserted (IRQ_EN=1)", soc_bus.irq, 1'b1);
        check("irq_empty output", soc_bus.irq_empty, 1'b1);

        // Clear the IRQ source
        axil_write(ADDR_IRQ_CLEAR, 32'h0000_0001);
        @(posedge clk);

        check("irq deasserted after clear", soc_bus.irq, 1'b0);

        // ============================================================
        // Test 9: Simultaneous hardware set + software W1C clear
        // (hardware set should win - last assignment priority)
        // ============================================================
        $display("\n--- Test 9: Simultaneous set + clear priority ---");

        // First set the error bit
        ring_mgr.error_set <= 1'b1;
        @(posedge clk);
        ring_mgr.error_set <= 1'b0;
        @(posedge clk);

        // Now issue a clear while also asserting error_set
        ring_mgr.error_set <= 1'b1;
        // Start the write (will take multiple cycles to commit)
        fork
            axil_write(ADDR_IRQ_CLEAR, 32'h0000_0002);
        join_none
        // Keep error_set asserted through the write commit
        repeat (10) @(posedge clk);
        ring_mgr.error_set <= 1'b0;
        @(posedge clk);
        @(posedge clk);

        axil_read(ADDR_IRQ_STATUS, rd_data);
        check("IRQ error survives concurrent clear (hw wins)", rd_data[1], 1'b1);

        // Clean up
        ring_mgr.error_set <= 1'b0;
        @(posedge clk);
        axil_write(ADDR_IRQ_CLEAR, 32'h0000_0002);

        // ============================================================
        // Test 10: Soft reset via CTRL.RESET
        // ============================================================
        $display("\n--- Test 10: Soft reset ---");

        // Program registers to non-zero values
        axil_write(ADDR_BASEADDR, 32'hAAAA_BBBB);
        axil_write(ADDR_RINGLEN, 32'h0000_0020);
        axil_write(ADDR_TAIL, 32'h0000_000A);
        axil_write(ADDR_CTRL, 32'h0000_0005); // ENABLE + IRQ_EN

        // Verify they hold
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR pre-reset", rd_data, 32'hAAAA_BBBB);

        // Trigger soft reset
        axil_write(ADDR_CTRL, 32'h0000_0002); // RESET bit
        // Wait for reset to propagate (RESET stored -> next cycle clears)
        repeat (2) @(posedge clk);

        // All registers should be back to 0
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR after soft reset", rd_data, 32'h0);

        axil_read(ADDR_RINGLEN, rd_data);
        check("RINGLEN after soft reset", rd_data, 32'h0);

        axil_read(ADDR_TAIL, rd_data);
        check("TAIL after soft reset", rd_data, 32'h0);

        axil_read(ADDR_CTRL, rd_data);
        check("CTRL after soft reset (auto-clear)", rd_data, 32'h0);

        // ============================================================
        // Test 11: Wstrb partial write
        // ============================================================
        $display("\n--- Test 11: Partial write (wstrb) ---");

        axil_write(ADDR_BASEADDR, 32'hAABBCCDD);
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR full write", rd_data, 32'hAABBCCDD);

        // Overwrite only byte 1 (bits [15:8])
        axil_write(ADDR_BASEADDR, 32'h0000_FF00, 4'b0010);
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR partial wstrb byte1", rd_data, 32'hAABBFFDD);

        // Overwrite only byte 3 (bits [31:24])
        axil_write(ADDR_BASEADDR, 32'h1100_0000, 4'b1000);
        axil_read(ADDR_BASEADDR, rd_data);
        check("BASEADDR partial wstrb byte3", rd_data, 32'h11BBFFDD);

        // ============================================================
        // Test 12: Ring manager outputs forwarded correctly
        // ============================================================
        $display("\n--- Test 12: CSR -> ring manager forwarding ---");

        axil_write(ADDR_BASEADDR, 32'h8000_0000);
        axil_write(ADDR_RINGLEN, 32'h0000_0040);
        axil_write(ADDR_TAIL, 32'h0000_0010);
        axil_write(ADDR_CTRL, 32'h0000_0005); // ENABLE + IRQ_EN
        @(posedge clk);

        check("ring_mgr.baseaddr", ring_mgr.baseaddr, 32'h8000_0000);
        check("ring_mgr.ringlen",  ring_mgr.ringlen,  32'h0000_0040);
        check("ring_mgr.tail",     ring_mgr.tail,     32'h0000_0010);
        check("ring_mgr.enable",   {31'd0, ring_mgr.enable}, 32'h1);
        check("ring_mgr.irq_en",   {31'd0, ring_mgr.irq_en}, 32'h1);

        // ============================================================
        // Test 13: error_clear pulse (one cycle only)
        // ============================================================
        $display("\n--- Test 13: error_clear pulse ---");

        // Set error first
        ring_mgr.error_set <= 1'b1;
        @(posedge clk);
        ring_mgr.error_set <= 1'b0;
        @(posedge clk);

        // Clear error via IRQ_CLEAR[1]
        axil_write(ADDR_IRQ_CLEAR, 32'h0000_0002);
        // error_clear should pulse for exactly one cycle
        @(posedge clk);
        check("error_clear pulse asserted", {31'd0, ring_mgr.error_clear}, 32'h1);
        @(posedge clk);
        check("error_clear pulse deasserted", {31'd0, ring_mgr.error_clear}, 32'h0);

        // ============================================================
        // Test 14: Write to read-only STATUS register is ignored
        // ============================================================
        $display("\n--- Test 14: Write to RO registers ---");

        ring_mgr.busy       <= 1'b1;
        ring_mgr.ring_empty <= 1'b1;
        @(posedge clk);

        axil_write(ADDR_STATUS, 32'h0000_0000);
        axil_read(ADDR_STATUS, rd_data);
        check("STATUS unchanged after write", rd_data[1:0], 2'b11);

        ring_mgr.busy       <= 1'b0;
        ring_mgr.ring_empty <= 1'b0;
        @(posedge clk);

        // ============================================================
        // Summary
        // ============================================================
        $display("\n=== CSR Testbench Complete ===");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout watchdog
    // ----------------------------------------------------------------
    initial begin
        #100_000;
        $display("[TIMEOUT] Testbench watchdog expired");
        $fatal(1, "Testbench hung");
    end

endmodule
