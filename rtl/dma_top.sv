// top wrapper: AXI-Lite slave + DMA engine + IRQ
// Milestone 0: Minimal stub to allow testbench to compile and run
// To have the very basic thing to test out the pipeline can run, the code will be
// split into different modules later

module dma_top (
    input logic clk,
    input logic rst_n,

    // AXI4-Lite Slave Interface (CSR) - using modport
    axi_lite_if.slave axil
);

    // Milestone 0: Simple stub CSR that just responds to reads/writes
    // Register file (8 registers as per spec)
    logic [31:0] regs [8];

    // Register addresses (4-byte aligned)
    localparam int REG_CTRL      = 0;
    localparam int REG_SRC_ADDR  = 1;
    localparam int REG_DST_ADDR  = 2;
    localparam int REG_LEN       = 3;
    localparam int REG_STATUS    = 4;
    localparam int REG_IRQ_STATUS = 5;
    localparam int REG_IRQ_ENABLE = 6;

    // AXI-Lite write handling
    logic write_enable;
    logic [31:0] write_addr;
    logic [31:0] write_data;
    logic AXI_LITE_DWDone;  // Used for Writing Data FSM
    logic AXI_LITE_AWDone; // Used for Writing Data FSM

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            $display("Resetting register file at time %0t", $time);
            // Reset values
            regs[REG_CTRL] <= 32'h0;
            regs[REG_SRC_ADDR] <= 32'h0;
            regs[REG_DST_ADDR] <= 32'h0;
            regs[REG_LEN] <= 32'h0;
            regs[REG_STATUS] <= 32'h0;
            regs[REG_IRQ_STATUS] <= 32'h0;
            regs[REG_IRQ_ENABLE] <= 32'h0;
            regs[7] <= 32'h0; // Reserved
        end else if (write_enable) begin
            // Write to register (simple implementation, no write protection yet)
            if (write_addr[4:2] < 8) begin
                if (write_addr[4:2] == REG_STATUS) begin
                    // STATUS is read-only, don't write
                end else if (write_addr[4:2] == REG_IRQ_STATUS) begin
                    // W1C: write 1 to clear
                    regs[REG_IRQ_STATUS] <= regs[REG_IRQ_STATUS] & ~write_data;
                end else begin
                    regs[write_addr[4:2]] <= write_data;
                end
            end
        end
    end

    // AXI-Lite write state machine
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_ADDR_DATA,
        WR_RESP
    } wr_state_t;
    wr_state_t wr_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            $display("Resetting AXI-Lite write state machine at time %0t", $time);
            wr_state <= WR_IDLE;
            axil.bvalid <= 1'b0;
            axil.bresp <= 2'b00;
            write_enable <= 1'b0;
            write_addr <= '0;
            write_data <= '0;
            AXI_LITE_AWDone <= 1'b0;
            AXI_LITE_DWDone <= 1'b0;
        end else begin
            write_enable <= 1'b0;
            case (wr_state)
                WR_IDLE: begin
                    axil.bvalid <= 1'b0; //Clear the response valid flag
                    axil.awready <= 1'b1; // Put the flags representing ready high during IDLE state
                    axil.wready <= 1'b1;
                    AXI_LITE_DWDone <= 1'b0;
                    AXI_LITE_AWDone <= 1'b0;
                    // Wait for address and/or data to arrive
                    // Handle all three cases: address first, data first, or both simultaneously
                    if (axil.awvalid && axil.awready) begin
                        // Address handshake - capture address
                        write_addr <= axil.awaddr;
                        AXI_LITE_AWDone <= 1'b1;
                        axil.awready <= 1'b0;
                    end
                    if (axil.wvalid && axil.wready) begin
                        // Data handshake - capture data
                        write_data <= axil.wdata;
                        AXI_LITE_DWDone <= 1'b1;
                        axil.wready <= 1'b0;
                    end
                    // Transition to WR_ADDR_DATA if at least one handshake occurred
                    if ((axil.awvalid && axil.awready) || (axil.wvalid && axil.wready)) begin
                        wr_state <= WR_ADDR_DATA;
                    end
                end
                WR_ADDR_DATA: begin
                    $display("WR_ADDR_DATA");
                    $display("AXI_LITE_AWDone: %b", AXI_LITE_AWDone);
                    $display("AXI_LITE_DWDone: %b", AXI_LITE_DWDone);
                    $display("axil.awvalid: %b", axil.awvalid);
                    $display("axil.awready: %b", axil.awready);
                    $display("axil.wvalid: %b", axil.wvalid);
                    $display("axil.wready: %b", axil.wready);
                    $display("axil.bready: %b", axil.bready);
                    $display("axil.bvalid: %b", axil.bvalid);
                    $display("axil.bresp: %b", axil.bresp);
                if (AXI_LITE_AWDone && AXI_LITE_DWDone) begin
                    wr_state <= WR_RESP;
                    axil.bvalid <= 1'b1;
                    axil.bresp <= 2'b00; // OKAY
                    write_enable <= 1'b1;
                    end
                    if (axil.awvalid && axil.awready && !AXI_LITE_AWDone) begin
                        write_addr <= axil.awaddr;
                        AXI_LITE_AWDone <= 1'b1;
                        axil.awready <= 1'b0;
                    end
                    if (axil.wvalid && axil.wready && !AXI_LITE_DWDone) begin
                        AXI_LITE_DWDone <= 1'b1;
                        write_data <= axil.wdata;
                        axil.wready <= 1'b0;
                    end
                end
                WR_RESP: begin
                    $display("WR_RESP");
                    if (axil.bready && axil.bvalid) begin
                        axil.bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // AXI-Lite read handling
    logic [31:0] read_addr;
    logic [31:0] read_data;

    // AXI-Lite read state machine
    typedef enum logic [1:0] {
        RD_FETCH_ADDR,
        RD_WRITE_DATA
    } rd_state_t;
    rd_state_t rd_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            $display("Resetting AXI-Lite read state machine at time %0t", $time);
            rd_state <= RD_FETCH_ADDR;
            axil.rvalid <= 1'b0;
            axil.rdata <= '0;
            axil.rresp <= 2'b00;
            read_addr <= '0;
            read_data <= '0;
        end else begin
            case (rd_state)
                RD_FETCH_ADDR: begin
                    axil.rvalid <= 1'b0;
                    axil.arready <= 1'b1;
                    if (axil.arvalid && axil.arready) begin
                        read_addr <= axil.araddr;
                        axil.arready <= 1'b0;
                        rd_state <= RD_WRITE_DATA;
                    end
                end
                RD_WRITE_DATA: begin
                    $display("RD_WRITE_DATA");
                    $display("read_addr: %h", read_addr);
                    $display("axil.araddr: %h", axil.araddr);
                    $display("axil.arvalid: %b", axil.arvalid);
                    $display("axil.arready: %b", axil.arready);
                    $display("axil.rvalid: %b", axil.rvalid);
                    $display("axil.rready: %b", axil.rready);
                    $display("axil.rdata: %h", axil.rdata);
                    // Read from register using the captured address (only set once)
                    if (!axil.rvalid) begin
                        // First time in this state - set rvalid and rdata
                        if (read_addr[4:2] < 8) begin
                            axil.rdata <= regs[read_addr[4:2]];
                        end else begin
                            axil.rdata <= 32'h0;
                        end
                        axil.rvalid <= 1'b1;
                        axil.rresp <= 2'b00; // OKAY
                    end
                    // Wait for rready handshake before returning to idle
                    if (axil.rready && axil.rvalid) begin
                        axil.rvalid <= 1'b0;
                        rd_state <= RD_FETCH_ADDR;
                    end
                end
            endcase
        end
    end
endmodule
