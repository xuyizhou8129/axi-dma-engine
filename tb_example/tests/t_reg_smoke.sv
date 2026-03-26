// Register Smoke Test - Simplified
// Basic test to verify CSR read/write works

`timescale 1ns/1ps

module t_reg_smoke;

    // Register addresses
    localparam logic [31:0] REG_CTRL      = 32'h00;
    localparam logic [31:0] REG_SRC_ADDR  = 32'h04;
    localparam logic [31:0] REG_DST_ADDR  = 32'h08;
    localparam logic [31:0] REG_LEN       = 32'h0C;
    localparam logic [31:0] REG_STATUS    = 32'h10;
    localparam logic [31:0] REG_IRQ_STATUS = 32'h14;
    localparam logic [31:0] REG_IRQ_ENABLE = 32'h18;

    // Helper tasks
    task write_reg(input logic [31:0] addr, input logic [31:0] data);
        $root.tb_top.axil_bfm.write(addr, data);
    endtask

    task read_reg(input logic [31:0] addr, output logic [31:0] data);
        $root.tb_top.axil_bfm.read(addr, data);
    endtask

    // Test variables
    logic [31:0] write_val;
    logic [31:0] read_val;

    initial begin
        $display("=== Register Smoke Test ===");
        
        // Wait for reset
        wait($root.tb_top.rst_n);
        #100;

        // Test 1: Write/Read CTRL
        $display("\n[Test 1] CTRL register");
        write_val = 32'h0000_000F;
        write_reg(REG_CTRL, write_val);
        #50;
        read_reg(REG_CTRL, read_val);
        if (read_val == write_val) begin
            $display("  [PASS]");
        end else begin
            $error("  [FAIL] Expected 0x%08h, got 0x%08h", write_val, read_val);
        end

        // Test 2: Write/Read SRC_ADDR
        $display("\n[Test 2] SRC_ADDR register");
        write_val = 32'h1234_5678;
        write_reg(REG_SRC_ADDR, write_val);
        #50;
        read_reg(REG_SRC_ADDR, read_val);
        if (read_val == write_val) begin
            $display("  [PASS]");
        end else begin
            $error("  [FAIL] Expected 0x%08h, got 0x%08h", write_val, read_val);
        end

        // Test 3: Read STATUS
        $display("\n[Test 3] STATUS register (read-only)");
        read_reg(REG_STATUS, read_val);
        $display("  Read: 0x%08h [INFO]", read_val);

        $display("\n=== Test Complete ===");
        #100;
        $finish;
    end

endmodule
