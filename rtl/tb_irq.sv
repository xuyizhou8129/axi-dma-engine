// Testbench for the IRQ module
// Tests that empty/error events set sticky status bits,
// that irq_clear clears them, and that irq_en gates the output.

`timescale 1ns/1ps

module tb_irq;

    // Clock and Reset 
    logic clk;
    logic rst_n;

    // DUT signals 
    logic        empty_event;
    logic        error_event;
    logic        irq_en;
    logic [1:0]  irq_clear;
    logic [1:0]  irq_status;
    logic        irq;

    // Instantiate the IRQ module 
    IRQ dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .empty_event (empty_event),
        .error_event (error_event),
        .irq_en      (irq_en),
        .irq_clear   (irq_clear),
        .irq_status  (irq_status),
        .irq         (irq)
    );

    // Clock generation: 100 MHz (10 ns period) 
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper: wait N clock cycles 
    task wait_clocks(input int n);
        repeat (n) @(posedge clk);
    endtask

    // Keep track of pass/fail counts 
    int pass_count = 0;
    int fail_count = 0;

    // Simple check task 
    // Compares an actual value against what we expect and prints PASS or FAIL.
    task check(input string name,
               input logic [1:0] actual_status,
               input logic       actual_irq,
               input logic [1:0] expected_status,
               input logic       expected_irq);
        if (actual_status === expected_status && actual_irq === expected_irq) begin
            $display("  [PASS] %s", name);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] %s", name);
            $display("         irq_status: got %b, expected %b", actual_status, expected_status);
            $display("         irq:        got %b, expected %b", actual_irq, expected_irq);
            fail_count = fail_count + 1;
        end
    endtask

    // Main test sequence 
    initial begin
        // Start with everything quiet
        empty_event = 0;
        error_event = 0;
        irq_en      = 0;
        irq_clear   = 2'b00;

        // Apply reset 
        rst_n = 0;
        wait_clocks(5);
        rst_n = 1;
        wait_clocks(2);

        $display("=== IRQ Testbench ===");

        // Test 1: After reset, everything should be zero
        $display("\n[Test 1] Reset state");
        check("all zeros after reset",
              irq_status, irq,
              2'b00, 1'b0);

        // Test 2: Fire empty_event, but irq_en is off
        //  Status should go high, but irq pin stays low.
        $display("\n[Test 2] Empty event with IRQ disabled");
        empty_event = 1;
        @(posedge clk);       // event is captured on this edge
        empty_event = 0;      // one-cycle pulse, turn it off
        @(posedge clk);       // let it propagate
        check("status_empty set, irq stays low",
              irq_status, irq,
              2'b01, 1'b0);

        // Test 3: Turn on irq_en, irq should go high now
        $display("\n[Test 3] Enable IRQ output");
        irq_en = 1;
        #1;                   // combinational, just need a tiny delay
        check("irq goes high once enabled",
              irq_status, irq,
              2'b01, 1'b1);

        // Test 4: Clear the empty bit using irq_clear[0]
        $display("\n[Test 4] Clear empty status");
        irq_clear[0] = 1;
        @(posedge clk);       // clear takes effect on the next edge
        irq_clear[0] = 0;
        @(posedge clk);       // let it settle
        check("empty cleared, irq low",
              irq_status, irq,
              2'b00, 1'b0);

        // Test 5: Fire error_event with irq_en still on
        $display("\n[Test 5] Error event with IRQ enabled");
        error_event = 1;
        @(posedge clk);
        error_event = 0;
        @(posedge clk);
        check("status_error set, irq high",
              irq_status, irq,
              2'b10, 1'b1);

        // Test 6: Clear the error bit using irq_clear[1]
        $display("\n[Test 6] Clear error status");
        irq_clear[1] = 1;
        @(posedge clk);
        irq_clear[1] = 0;
        @(posedge clk);
        check("error cleared, irq low",
              irq_status, irq,
              2'b00, 1'b0);

        // Test 7: Both events at the same time
        $display("\n[Test 7] Both events fire together");
        empty_event = 1;
        error_event = 1;
        @(posedge clk);
        empty_event = 0;
        error_event = 0;
        @(posedge clk);
        check("both status bits set, irq high",
              irq_status, irq,
              2'b11, 1'b1);

        // Test 8: Clear only empty, error should keep irq high
        $display("\n[Test 8] Clear only empty, error remains");
        irq_clear[0] = 1;
        @(posedge clk);
        irq_clear[0] = 0;
        @(posedge clk);
        check("only error left, irq still high",
              irq_status, irq,
              2'b10, 1'b1);

        // Test 9: Clear error too, everything should be quiet
        $display("\n[Test 9] Clear error, back to idle");
        irq_clear[1] = 1;
        @(posedge clk);
        irq_clear[1] = 0;
        @(posedge clk);
        check("all clear",
              irq_status, irq,
              2'b00, 1'b0);

        // Test 10: Disable irq_en while a status bit is set
        $display("\n[Test 10] Disable irq_en masks the output");
        empty_event = 1;
        @(posedge clk);
        empty_event = 0;
        @(posedge clk);
        // status is set and irq_en is still 1 from earlier
        check("status set, irq high before disable",
              irq_status, irq,
              2'b01, 1'b1);
        irq_en = 0;
        #1;
        check("irq masked after disable",
              irq_status, irq,
              2'b01, 1'b0);

        // clean up for next run
        irq_clear = 2'b11;
        @(posedge clk);
        irq_clear = 2'b00;
        @(posedge clk);

        // Summary
        $display("\n=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #100;
        $finish;
    end

endmodule