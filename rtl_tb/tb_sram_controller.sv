`timescale 1ns/1ps

module tb_sram_controller;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam int BRAM_SIZE       = 1024;
    localparam int BRAM_DATA_WIDTH = 32;
    localparam int DATA_WIDTH      = 32;
    localparam int LEN_WIDTH       = 8;
    localparam int INSTR_WIDTH     = 41;
    localparam int BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE);

    // ----------------------------------------------------------------
    // Clock / reset
    // ----------------------------------------------------------------
    logic clock = 0;
    logic reset;
    always #5 clock = ~clock;

    // ----------------------------------------------------------------
    // BRAM wires
    // ----------------------------------------------------------------
    logic [BRAM_ADDR_WIDTH-1:0] read_addr;
    logic [BRAM_ADDR_WIDTH-1:0] write_addr;
    logic                       wr_en;
    logic [BRAM_DATA_WIDTH-1:0] din;
    logic [BRAM_DATA_WIDTH-1:0] dout;

    // ----------------------------------------------------------------
    // AXI4-master handshake
    // ----------------------------------------------------------------
    logic sram_done;
    logic axi4master_done;

    // ----------------------------------------------------------------
    // DUT-driven mid-FIFO signals (DUT is both producer and consumer)
    // ----------------------------------------------------------------
    logic                  mid_wr_en;       // DUT output: write when reading BRAM
    logic [DATA_WIDTH-1:0] mid_din;         // DUT output: data to mid FIFO
    logic                  mid_rd_en;       // DUT output: read when writing BRAM
    logic                  mid_full;        // to DUT: mid FIFO full
    logic                  mid_empty;       // to DUT: mid FIFO empty
    logic [DATA_WIDTH-1:0] mid_dout;        // to DUT: mid FIFO data out

    // ----------------------------------------------------------------
    // DM instruction FIFO signals
    // ----------------------------------------------------------------
    logic                   dm_in_rd_en;    // DUT output: read DM instruction
    logic                   dm_in_empty;    // to DUT: DM FIFO empty
    logic [INSTR_WIDTH-1:0] dm_in_dout;     // to DUT: DM FIFO data out

    // ----------------------------------------------------------------
    // TB-side FIFO push/drain signals
    // ----------------------------------------------------------------
    logic                   tb_mid_wr_en;   // TB push into mid FIFO (write-to-BRAM test)
    logic [DATA_WIDTH-1:0]  tb_mid_din;
    logic                   tb_mid_rd_en;   // TB drain from mid FIFO (read-from-BRAM test)

    logic                   tb_dm_wr_en;    // TB push instruction into DM FIFO
    logic [INSTR_WIDTH-1:0] tb_dm_din;

    logic                   dm_fifo_full;   // not connected to DUT, for TB checks

    // ----------------------------------------------------------------
    // Mid FIFO write mux: TB-side push OR DUT-side write (never overlap)
    // ----------------------------------------------------------------
    wire                   mid_fifo_wr_en = tb_mid_wr_en | mid_wr_en;
    wire [DATA_WIDTH-1:0]  mid_fifo_din   = tb_mid_wr_en ? tb_mid_din : mid_din;
    wire                   mid_fifo_rd_en = tb_mid_rd_en | mid_rd_en;

    // ----------------------------------------------------------------
    // Mid FIFO (fifo.sv)
    // ----------------------------------------------------------------
    fifo #(
        .FIFO_DATA_WIDTH (DATA_WIDTH),
        .FIFO_BUFFER_SIZE(64)
    ) u_mid_fifo (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (mid_fifo_wr_en),
        .din    (mid_fifo_din),
        .full   (mid_full),
        .rd_clk (clock),
        .rd_en  (mid_fifo_rd_en),
        .dout   (mid_dout),
        .empty  (mid_empty)
    );

    // ----------------------------------------------------------------
    // DM instruction FIFO (fifo.sv) - TB writes, DUT reads
    // ----------------------------------------------------------------
    fifo #(
        .FIFO_DATA_WIDTH (INSTR_WIDTH),
        .FIFO_BUFFER_SIZE(8)
    ) u_dm_fifo (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (tb_dm_wr_en),
        .din    (tb_dm_din),
        .full   (dm_fifo_full),
        .rd_clk (clock),
        .rd_en  (dm_in_rd_en),
        .dout   (dm_in_dout),
        .empty  (dm_in_empty)
    );

    // ----------------------------------------------------------------
    // DUT: sram_controller
    // ----------------------------------------------------------------
    sram_controller #(
        .BRAM_SIZE      (BRAM_SIZE),
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .LEN_WIDTH      (LEN_WIDTH),
        .INSTR_WIDTH    (INSTR_WIDTH)
    ) dut (
        .clock          (clock),
        .reset          (reset),
        .read_addr      (read_addr),
        .write_addr     (write_addr),
        .wr_en          (wr_en),
        .din            (din),
        .dout           (dout),
        .sram_done      (sram_done),
        .axi4master_done(axi4master_done),
        .mid_wr_en      (mid_wr_en),
        .mid_full       (mid_full),
        .mid_din        (mid_din),
        .mid_rd_en      (mid_rd_en),
        .mid_empty      (mid_empty),
        .mid_dout       (mid_dout),
        .dm_in_rd_en    (dm_in_rd_en),
        .dm_in_empty    (dm_in_empty),
        .dm_in_dout     (dm_in_dout)
    );

    // ----------------------------------------------------------------
    // BRAM instance
    // ----------------------------------------------------------------
    bram #(
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH),
        .BRAM_SIZE      (BRAM_SIZE)
    ) u_bram (
        .clock   (clock),
        .rd_addr (read_addr),
        .wr_addr (write_addr),
        .wr_en   (wr_en),
        .din     (din),
        .dout    (dout)
    );

    // ----------------------------------------------------------------
    // Scoreboard
    // ----------------------------------------------------------------
    int pass_count, fail_count;

    task automatic check(
        input string       name,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got === exp) begin
            $display("  PASS  [%s] got=0x%08x", name, got);
            pass_count++;
        end else begin
            $display("  FAIL  [%s] got=0x%08x  exp=0x%08x", name, got, exp);
            fail_count++;
        end
    endtask

    // ----------------------------------------------------------------
    // Tasks: push / drain using fifo.sv interface
    // fifo.sv has registered dout (1-cycle pre-fetch) and registered
    // empty (deasserts 1 cycle after write). Pushes must use clock edges.
    // ----------------------------------------------------------------

    // Push one 32-bit word into the mid FIFO from TB side
    task automatic mid_push(input logic [31:0] data);
        while (mid_full) @(posedge clock);
        tb_mid_din   = data;
        tb_mid_wr_en = 1'b1;
        @(posedge clock);
        tb_mid_wr_en = 1'b0;
    endtask

    // Push one DM instruction. rw: 1=write to BRAM, 0=read from BRAM
    task automatic dm_push(
        input logic [31:0] addr,
        input logic [7:0]  len,
        input logic        rw
    );
        while (dm_fifo_full) @(posedge clock);
        tb_dm_din   = {rw, len, addr};
        tb_dm_wr_en = 1'b1;
        @(posedge clock);
        tb_dm_wr_en = 1'b0;
        // fifo.sv has registered empty: wait 2 cycles for DUT to see dm_in_empty=0
        // and for dout to hold valid instruction data
        repeat (2) @(posedge clock);
    endtask

    // Read one word from mid FIFO (for TB-side drain after DUT reads BRAM)
    // fifo.sv pre-fetches dout every cycle; assert rd_en to advance pointer.
    task automatic mid_read(output logic [31:0] data);
        while (mid_empty) @(posedge clock);
        @(posedge clock);            // let dout settle (registered pre-fetch)
        data         = mid_dout;
        tb_mid_rd_en = 1'b1;
        @(posedge clock);
        tb_mid_rd_en = 1'b0;
    endtask

    // Wait for DUT to reach s_wait_axi4master then handshake axi4master_done
    task automatic wait_done;
        int cnt;
        axi4master_done = 1'b0;
        cnt = 0;
        while (!sram_done) begin
            @(posedge clock);
            cnt++;
            if (cnt % 20 == 0)
                $display("  [dbg] cy=%0d state=%0s beat=%0d cur_len=%0d",
                    cnt, dut.state.name(), dut.beat_idx, dut.cur_len);
            if (cnt > 200)
                $fatal(1, "[wait_done] DUT never asserted sram_done after 200 cycles");
        end
        @(posedge clock);
        axi4master_done = 1'b1;
        @(posedge clock);
        axi4master_done = 1'b0;
        repeat (2) @(posedge clock); // let FIFO outputs settle
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        pass_count      = 0;
        fail_count      = 0;
        axi4master_done = 1'b0;
        tb_mid_wr_en    = 1'b0;
        tb_mid_din      = '0;
        tb_mid_rd_en    = 1'b0;
        tb_dm_wr_en     = 1'b0;
        tb_dm_din       = '0;

        reset = 1'b1;
        repeat (4) @(posedge clock);
        reset = 1'b0;
        repeat (2) @(posedge clock);

        // ============================================================
        // Test 1: Write 4 words from mid FIFO into BRAM at address 0
        // ============================================================
        $display("\n--- Test 1: Write 4 words to BRAM ---");

        mid_push(32'hDEAD_0001);
        mid_push(32'hDEAD_0002);
        mid_push(32'hDEAD_0003);
        mid_push(32'hDEAD_0004);
        dm_push(32'h0000_0000, 8'd4, 1'b1);   // write instr, addr=0, len=4

        wait_done();

        check("BRAM[0]", u_bram.mem[0], 32'hDEAD_0001);
        check("BRAM[1]", u_bram.mem[1], 32'hDEAD_0002);
        check("BRAM[2]", u_bram.mem[2], 32'hDEAD_0003);
        check("BRAM[3]", u_bram.mem[3], 32'hDEAD_0004);

        // ============================================================
        // Test 2: Read 4 words from BRAM back into mid FIFO
        // ============================================================
        $display("\n--- Test 2: Read 4 words from BRAM ---");

        dm_push(32'h0000_0000, 8'd4, 1'b0);   // read instr, addr=0, len=4
        wait_done();

        begin
            logic [31:0] rd_val;
            logic [31:0] expected [0:3];
            expected[0] = 32'hDEAD_0001;
            expected[1] = 32'hDEAD_0002;
            expected[2] = 32'hDEAD_0003;
            expected[3] = 32'hDEAD_0004;
            for (int i = 0; i < 4; i++) begin
                mid_read(rd_val);
                check($sformatf("ReadBack[%0d]", i), rd_val, expected[i]);
            end
        end

        // ============================================================
        // Test 3: Write to non-zero base address
        // ============================================================
        $display("\n--- Test 3: Write to word address 0x10 ---");

        mid_push(32'hCAFE_BABE);
        mid_push(32'h1234_5678);
        dm_push(32'h0000_0010, 8'd2, 1'b1);   // write instr, addr=0x10, len=2

        wait_done();

        check("BRAM[0x10]", u_bram.mem[16], 32'hCAFE_BABE);
        check("BRAM[0x11]", u_bram.mem[17], 32'h1234_5678);

        // ============================================================
        // Summary
        // ============================================================
        $display("\n=== TB Complete: pass=%0d  fail=%0d ===", pass_count, fail_count);
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
        #500_000;
        $fatal(1, "[TIMEOUT] Testbench watchdog expired");
    end

endmodule
