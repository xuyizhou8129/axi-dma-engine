// -----------------------------------------------------------------------------------------
// Module: Ring Manager Testbench
// Description: Testbench for ring_manager.sv
//              Verifies descriptor scheduling, head pointer advancement,
//              in-flight tracking, head wrap, and interrupt generation.
//
// Tests:
//  1. Reset - all outputs initialize to known state.
//  2. Normal operation - descriptor issues and completes, head advances.
//  3. Head wrap - head rolls to 0 when head == (ringlen - 1).
//  4. Backpressure - DF not ready, no descriptor issued.
//  5. In-flight limit - no new descrptor issued when in_flight_count == MAXINFLIGHTCOUNT.
//  6. Error - df_error triggers irq pulse and suppresses further fetches.
//
// ADD TESTS FOR SW_RESET_EN, ERROR_CLEAR
//
// -----------------------------------------------------------------------------------------

`timescale 1ns/1ps  // time unit / precision

module ring_manager_tb;

    // ----------------------------------------
    // DUT Signals Declaration
    // ----------------------------------------

    // Clock and Reset
    logic clk;            // system clock
    logic reset_n;        // active-low reset

    // Inputs to DUT (Drivers)
    logic             ctrl_enable;      // CTRL.ENABLE must be asserted before descriptor is issued
    logic             ctrl_reset;       // CTRL.RESET - software reset
    logic     [31:0]  tail_ptr;         // tail managed by CPU
    logic     [31:0]  ring_base_addr;   // Base address of ring buffer
    logic     [31:0]  ring_len;         // RINGLEN from CSR (must be > 0)
    logic             irq_en;           // IRQ enable (gating performed in CSR)
    logic             error_clear;      // clears internal error flag (IRQ_CLEAR[1])
    logic             fetch_req_ready;  // DF is ready for new address
    logic             as_done;          // Descriptor completed successfully
    logic             df_error;         // Descriptor fetch error

    // Outputs from DUT (Monitors)
    logic     [31:0]  rm_df_addr;       // send address to fetch to DF
    logic             fetch_req_valid;  // High when ring is non-empty, ctrl_enable asserted, and ring_len > 0
    logic     [31:0]  head_ptr;         // HEAD pointer (read by CSR)
    logic             busy;             // 1 while descriptors are in flight
    logic             buffer_empty;     // buffer is empty (head == tail)
    logic             irq_status_empty; // set-pulse on non-empty to empty transition
    logic             irq_status_error; // set-pulse on descriptor error
    logic             irq_empty;        // single cycle pulse to IRQ on non-empty to empty transition
    logic             irq_error;        // single cycle pulse to IRQ on any error

    // ----------------------------------------
    // Scoreboard Counters
    // ----------------------------------------

    int     tests_run;
    int     tests_passed;

    // ----------------------------------------
    // DUT Instantiation
    // ----------------------------------------

    ring_manager #(
        .MAX_INFLIGHT(4)
    ) dut(
        .clk                (clk),
        .reset_n            (reset_n),
        .ctrl_enable        (ctrl_enable),
        .ctrl_reset         (ctrl_reset),
        .tail_ptr           (tail_ptr),
        .ring_base_addr     (ring_base_addr),
        .ring_len           (ring_len),
        .irq_en             (irq_en),
        .error_clear        (error_clear),
        .fetch_req_ready    (fetch_req_ready),
        .as_done            (as_done),
        .df_error           (df_error),
        .rm_df_addr         (rm_df_addr),
        .fetch_req_valid    (fetch_req_valid),
        .head_ptr           (head_ptr),
        .busy               (busy),
        .buffer_empty       (buffer_empty),
        .irq_status_empty   (irq_status_empty),
        .irq_status_error   (irq_status_error),
        .irq_empty          (irq_empty),
        .irq_error          (irq_error)
    );

    // ----------------------------------------
    // Clock Generation
    // ----------------------------------------

    initial clk = 1'b0;
    always #5 clk = ~clk; // 100 Mhz = 10ns period (check)

    // ----------------------------------------
    // Tasks
    // ----------------------------------------

    task check(
        input   logic   signal,
        input   logic   expected_signal,
        input   string  test
    );
        tests_run = tests_run + 1;
        if (signal === expected_signal) begin
            tests_passed = tests_passed + 1;
            $display("PASS: %s", test);
        end else begin
            $error("FAIL: %s expected %0b got %0b", test, expected_signal, signal);
        end

    endtask

    // ----------------------------------------
    // Stimulus
    // ----------------------------------------

    initial begin

        $dumpfile("sim.vcd");
        $dumpvars(0, ring_manager_tb);

        // initialise inputs and scoreboard
        reset_n         = 1'b0;
        ctrl_enable     = 1'b0;
        ctrl_reset      = 1'b0;
        tail_ptr        = 32'b0;
        ring_base_addr  = 32'h0;
        ring_len        = 32'b0;
        irq_en          = 1'b0;
        error_clear     = 1'b0;
        fetch_req_ready = 1'b0;
        as_done         = 1'b0;
        df_error        = 1'b0;

        tests_passed = 0;
        tests_run = 0;

        // Test 1: Reset //
        $display("--- Test 1: Reset ---");
        reset_n = 1'b0;  // assert reset
        #20;             // hold reset for 20ns (2 clock cycles)
        reset_n = 1'b1;  // release reset
        @(posedge clk);  // wait for outputs to update
        #1;              // let combinational outputs settle

        // check all outputs are in known reset state
        check(buffer_empty,     1'b1, "buffer_empty - Test 1");
        check(fetch_req_valid,  1'b0, "fetch_req_valid - Test 1");
        check(irq_status_empty, 1'b0, "irq_status_empty - Test 1");
        check(irq_status_error, 1'b0, "irq_status_error - Test 1");
        check(irq_empty,        1'b0, "irq_empty - Test 1");
        check(irq_error,        1'b0, "irq_error - Test 1");
        check(busy,             1'b0, "busy - Test 1");

        // Test 2: Normal Operation //
        // Description: one descriptor in a ring of length 4, verifies
        // fetch_req_valid goes high and correct address is sent to DF

        $display("--- Test 2: Normal Operation ---");

        // Step 1: Set up ring - CPU queued 1 descriptor at slot 0
        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000; // arbitrary base address
        ring_len        = 32'd4;
        tail_ptr        = 32'd1; // head = 0, tail = 1, 1 descriptor waiting
        fetch_req_ready = 1'b1;
        irq_en          = 1'b1;

        @(posedge clk); #1;

        check(buffer_empty,     1'b0, "buffer_empty LOW - Test 2 step 1");
        check(fetch_req_valid,  1'b1, "fetch_req_valid HIGH - Test 2 step 1");
        check(rm_df_addr,       32'hA000_0000, "rm_df_addr - Test 2 step 1");

        // Step 2: as_done fires — check pulse on the SAME clock where buffer_empty first goes high.
        // was_empty is still 0 at this point (it registered the old buffer_empty=0),
        // so !was_empty && buffer_empty = 1 for exactly this one cycle.
        as_done = 1'b1;
        @(posedge clk); #1;   // head advances, buffer_empty=1, was_empty=0 -> pulse fires

        check(buffer_empty,     1'b1, "buffer_empty HIGH - Test 2 step 2");
        check(irq_status_empty, 1'b1, "irq_status_empty HIGH - Test 2 step 2");
        check(irq_empty,        1'b1, "irq_empty HIGH - Test 2 step 2");

        // Step 3: one more clock - was_empty catches up to 1, pulse gone
        as_done = 1'b0;
        @(posedge clk); #1;

        check(irq_empty,        1'b0, "irq_empty LOW - Test 2 step 3");
        check(irq_status_empty, 1'b0, "irq_status_empty LOW - Test 2 step 3");

        // Test 3: Head Wrap //
        // Description: Ring length is 3. CPU loads 2 descriptors, as_done fires
        // twice to send head to slot (ring_len - 1), CPU loads another descriptor
        // and as_done fires again to send head to slot 0.

        // Step 1: Toggle reset, reinitialize inputs (load 2 descriptors)
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        fetch_req_ready = 1'b1;
        ring_len        = 32'd3;
        tail_ptr        = 32'd2;  // 2 descriptors queued at slots 0 and 1

        @(posedge clk); #1;

        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 step 1");

        // Step 2: fire as_done twice
        as_done = 1'b1;
        @(posedge clk); #1;
        as_done = 1'b0;
        @(posedge clk); #1;

        check(rm_df_addr,   32'hA000_0010,  "rm_df_addr - Test 3 Step 2"); // rm_df_addr = ring_base_addr + 1 * 16
        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 Step 2");

        as_done = 1'b1;
        @(posedge clk); #1;
        as_done = 1'b0;
        @(posedge clk); #1;

        check(buffer_empty, 1'b1, "buffer_empty HIGH - Test 3 step 2");

        // Step 3: load another descriptor and fire as_done
        tail_ptr = 32'd0;
        @(posedge clk); #1;

        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 step 3");

        as_done = 1'b1;
        @(posedge clk); #1;   // head wraps to 0, buffer_empty=1, was_empty=0 -> pulse fires

        check(irq_empty,    1'b1,           "irq_empty HIGH - Test 3 step 3");

        as_done = 1'b0;
        @(posedge clk); #1;   // was_empty catches up, pulse gone

        check(rm_df_addr,   32'hA000_0000,  "rm_df_addr - Test 3 step 3");
        check(buffer_empty, 1'b1,           "buffer_empty HIGH - Test 3 step 3");


        // Test 4: Backpressure
        // Description: DF is not ready, so no descriptor should be issued

        $display("--- Test 4: Backpressure ---");

        // Step 1: Reset and set up ring (DF not ready)
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;
        @(posedge clk); #1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        ring_len        = 32'd3;
        tail_ptr        = 32'd1;   // 1 descriptor waiting
        fetch_req_ready = 1'b0;   // DF not ready

        @(posedge clk); #1;

        // Step 2: wait several cycles and check head never icrements

        check(fetch_req_valid, 1'b1, "fetch_req_valid - Test 4 step 2");
        check(rm_df_addr, 32'hA000_0000, "rm_df_addr - Test 4 step 2");
        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 4 step 2");


        // Test 5: In-flight limit
        // Description: drive 5 descriptors, after 4th
        // descriptor is issued, fetch_req_valid should go LOW
        // buffer_empty should be HIGH as 1 descriptor remains

        $display("--- Test 5: In-flight limit ---");

        // Step 1: Initialize inputs
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;
        @(posedge clk); #1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        ring_len        = 32'd6;
        tail_ptr        = 32'd5;   // 5 descriptors loaded
        fetch_req_ready = 1'b1;

        // Step 2: wait 4 clock cycles

        @(posedge clk); #1;

        check(fetch_req_valid, 1'b1, "fetch_req_valid: 1 in-flight - Test 5 step 2");

        @(posedge clk); #1;

        check(fetch_req_valid, 1'b1, "fetch_req_valid: 2 in-flight - Test 5 step 2");

        @(posedge clk); #1;

        check(fetch_req_valid, 1'b1, "fetch_req_valid 3 in-flight - Test 5 step 2");

        @(posedge clk); #1;

        check(fetch_req_valid, 1'b0, "fetch_req_valid MAX in-flight - Test 5 step 2");
        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 5 step 2");



        // Test 6: Error
        // Description: df_error triggers irq_error/irq_status_error pulses for one cycle,
        // then internal status_error flag latches and suppresses further fetches.

        $display("--- Test 6: Error ---");

        // Reset and initialize
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;
        @(posedge clk); #1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        ring_len        = 32'd4;
        tail_ptr        = 32'd1;
        fetch_req_ready = 1'b1;
        irq_en          = 1'b1;

        // Step 1: assert df_error and check combinational pulse outputs are HIGH
        df_error = 1'b1;
        @(posedge clk); #1;  // clock to register internal status_error; df_error still HIGH

        check(irq_error,        1'b1, "irq_error HIGH - Test 6 step 1");
        check(irq_status_error, 1'b1, "irq_status_error HIGH - Test 6 step 1");

        // Step 2: deassert df_error - irq_error/irq_status_error are combinational so drop immediately
        df_error = 1'b0;
        @(posedge clk); #1;

        check(irq_error,        1'b0, "irq_error LOW - Test 6 step 2");
        check(irq_status_error, 1'b0, "irq_status_error LOW - Test 6 step 2");

        // Step 3: verify internal error flag is sticky - fetch_req_valid should stay LOW
        check(fetch_req_valid, 1'b0, "fetch_req_valid LOW - internal error sticky - Test 6 step 3");

        // display scoreboard
        $display("-------------------------------");
        $display("%0d / %0d tests passed", tests_passed, tests_run);
        $display("-------------------------------");
        $finish;

    end




endmodule
