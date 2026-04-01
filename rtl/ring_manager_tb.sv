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
//  6. Error - dm_error triggers irq sticky bits and pulses irq_error.
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
    logic     [2:0]   tail_ptr;         // tail managed by CPU
    logic     [31:0]  ring_base_addr;   // Base address of ring buffer
    logic     [2:0]   ring_len;         // RINGLEN from CSR (must be > 0)
    logic             irq_empty_en;     // IRQ enable for empty event
    logic             irq_error_en;     // IRQ enable for error event
    logic             fetch_req_ready;  // DF is ready for new address
    logic             dm_done;          // Desriptor completed successfully
    logic             dm_error;         // Descriptor completed with error

    // Outputs from DUT (Monitors)
    logic     [31:0]  rm_df_addr;       // send address to fetch to DF
    logic             fetch_req_valid;  // High when ring is non-empty, ctrl_enable asserted, and ring_len > 0
    logic             buffer_empty;     // buffer is empty (head == tail)
    logic             status_error;     // STATUS.ERROR - general health flag set on any error
    logic             irq_status_empty; // IRQ_STATUS.EMPTY - sticky bit set on non-empty to empty transition (cleared by CPU / IRQ_CLEAR)
    logic             irq_status_error; // IRQ_STATUS.ERROR - sticky bit set when error interrupt fires (cleared by CPU / IRQ_CLEAR)
    logic             irq_empty;        // single cycle pulse to IRQ on non-empty to empty transition
    logic             irq_error;         // single cycle pulse to IRQ on any error

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
        .tail_ptr           (tail_ptr),
        .ring_base_addr     (ring_base_addr),
        .ring_len           (ring_len),
        .irq_empty_en       (irq_empty_en),
        .irq_error_en       (irq_error_en),
        .fetch_req_ready    (fetch_req_ready),
        .dm_done            (dm_done),
        .dm_error           (dm_error),
        .rm_df_addr         (rm_df_addr),
        .fetch_req_valid    (fetch_req_valid),
        .buffer_empty       (buffer_empty),
        .status_error       (status_error),
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
        reset_n = 1'b0;
        ctrl_enable   = 1'b0;
        tail_ptr      = 3'b0;
        ring_base_addr= 32'h0;
        ring_len      = 3'b0;
        irq_empty_en  = 1'b0;
        irq_error_en  = 1'b0;
        fetch_req_ready = 1'b0;
        dm_done       = 1'b0;
        dm_error      = 1'b0;

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
        check(status_error,     1'b0, "status_error - Test 1");
        check(irq_status_empty, 1'b0, "irq_status_empty - Test 1");
        check(irq_status_error, 1'b0, "irq_status_error - Test 1");
        check(irq_empty,        1'b0, "irq_empty - Test 1");
        check(irq_error,        1'b0, "irq_error - Test 1");

        // Test 2: Normal Operation //
        // Description: one descriptor in a ring of length 4, verifies
        // fetch_req_valid goes high and correct address is sent to DF

        $display("--- Test 2: Normal Operation ---");

        // Step 1: Set up ring - CPU queued 1 descriptor at slot 0
        ctrl_enable = 1'b1;
        ring_base_addr  = 32'hA000_0000; // arbitrary base address
        ring_len = 3'd4; 
        tail_ptr = 3'd1; // head = 0, tail = 1, 1 descriptor waiting
        fetch_req_ready = 1'b1; // DF is ready
        irq_empty_en = 1'b1;

        @(posedge clk); #1;

        check(buffer_empty,     1'b0, "buffer_empty LOW - Test 2 step 1");
        check(fetch_req_valid,  1'b1, "fetch_req_valid HIGH - Test 2 step 1");
        check(rm_df_addr,       32'hA000_0000, "rm_df_addr - Test 2 step 1");

        // Step 2: dm_done firing, head moves forward
        dm_done = 1'b1;
        @(posedge clk); #1;
        dm_done = 1'b0;
        @(posedge clk); #1;

        check(buffer_empty,     1'b1, "buffer_empty HIGH - Test 2 step 2");
        check(irq_status_empty, 1'b1, "irq_status_empty HIGH - Test 2 step 2");
        check(irq_empty,        1'b1, "irq_empty HIGH - Test 2 step 2");

        // Step 3: verify irq_empty was single pulse
        @(posedge clk); #1;

        check(irq_empty, 1'b0, "irq_empty LOW - Test 2 step 3");
        check(irq_status_empty, 1'b1, "irq_status_empty HIGH - Test 2 step 3");
    
        // Test 3: Head Wrap //
        // Description: Ring length is 3. CPU loads 2 descriptors, dm_done fires
        // twice to send head to slot (ring_len - 1), CPU loads another descriptor
        // and dm_done fires again to send head to slot 0.

        // Step 1: Toggle reset, reinitialize inputs (load 2 descriptors)
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        fetch_req_ready = 1'b1;
        ring_len        = 3'd3;
        tail_ptr        = 3'd2;  // 2 descriptors queued at slots 0 and 1

        @(posedge clk); #1;

        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 step 1");

        // Step 2: fire dm_done twice
        dm_done = 1'b1;
        @(posedge clk); #1;
        dm_done = 1'b0;
        @(posedge clk); #1;

        check(rm_df_addr,   32'hA000_0008,  "rm_df_addr - Test 3 Step 2"); // rm_df_addr = ring_base_addr + 1 * 8
        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 Step 2");

        dm_done = 1'b1;
        @(posedge clk); #1;
        dm_done = 1'b0;
        @(posedge clk); #1;

        check(buffer_empty, 1'b1, "buffer_empty HIGH - Test 3 step 2");

        // Step 3: load another descriptor and fire dm_done
        tail_ptr = 3'd0;
        @(posedge clk); #1;

        check(buffer_empty, 1'b0, "buffer_empty LOW - Test 3 step 3");

        dm_done = 1'b1;
        @(posedge clk); #1;
        dm_done = 1'b0;
        @(posedge clk); #1;

        check(rm_df_addr,   32'hA000_0000,  "rm_df_addr - Test 3 step 3"); // rm_df_addr = ring_base_addr + 1 * 8
        check(buffer_empty, 1'b1,           "buffer_empty HIGH - Test 3 step 3");
        check(irq_empty,    1'b1,           "irq_empty HIGH - Test 3 step 3");


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
        ring_len        = 3'd3;
        tail_ptr        = 3'd1;   // 1 descriptor waiting
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
        ring_len        = 3'd6;
        tail_ptr        = 3'd5;   // 5 descriptors loaded
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
        // Description: DM reports error

        $display("--- Test 6: Error ---");

        // Reset and initialize
        reset_n = 1'b0;
        #20;
        reset_n = 1'b1;
        @(posedge clk); #1;

        ctrl_enable     = 1'b1;
        ring_base_addr  = 32'hA000_0000;
        ring_len        = 3'd4;
        tail_ptr        = 3'd1;
        fetch_req_ready = 1'b1;
        irq_error_en    = 1'b1;

        // Step 1: Pulse dm_error

        dm_error = 1'b1;
        @(posedge clk); #1;
        dm_error = 1'b0;

        check(irq_error, 1'b1, "irq_error HIGH - Test 6 step 1");
        check(irq_status_error, 1'b1, "irq_status_error HIGH - Test 6 step 1");
        check(status_error, 1'b1, "status_error HIGH - Test 6 step 1");

        // Step 2: Check next clock cycle irq_empty goes LOW and sticky bits stay HIGH

        @(posedge clk); #1;

        check(irq_error, 1'b0, "irq_error LOW - Test 6 step 1");
        check(irq_status_error, 1'b1, "irq_status_error HIGH - Test 6 step 1");
        check(status_error, 1'b1, "status_error HIGH - Test 6 step 1");

        // display scoreboard
        $display("-------------------------------");
        $display("%0d / %0d tests passed", tests_passed, tests_run);
        $display("-------------------------------");
        $finish;

    end 
    



endmodule

