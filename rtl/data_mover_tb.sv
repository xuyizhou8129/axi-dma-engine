`timescale 1ns/1ps

module data_mover_tb;

    logic clock;
    logic reset;
    
    // Input FIFO
    logic df_dm_in_wr_en;
    logic df_dm_in_rd_en;
    logic df_dm_in_empty;
    logic df_dm_in_full;
    logic [127:0] df_dm_in_din;
    logic [127:0] df_dm_in_dout;

    // SRAM output FIFO
    logic dm_sram_out_wr_en;
    logic dm_sram_out_rd_en;
    logic dm_sram_out_empty;
    logic dm_sram_out_full;
    logic [64:0] dm_sram_out_din;
    logic [64:0] dm_sram_out_dout;

    // AXI output FIFO
    logic dm_axi_out_wr_en;
    logic dm_axi_out_rd_en;
    logic dm_axi_out_empty;
    logic dm_axi_out_full;
    logic [64:0] dm_axi_out_din;
    logic [64:0] dm_axi_out_dout;

    fifo #(.FIFO_DATA_WIDTH(128), .FIFO_BUFFER_SIZE(16)) input_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(df_dm_in_wr_en),
        .din(df_dm_in_din),
        .full(df_dm_in_full),
        .rd_clk(clock),
        .rd_en(df_dm_in_rd_en),
        .dout(df_dm_in_dout),
        .empty(df_dm_in_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(65), .FIFO_BUFFER_SIZE(16)) sram_output_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(dm_sram_out_wr_en),
        .din(dm_sram_out_din),
        .full(dm_sram_out_full),
        .rd_clk(clock),
        .rd_en(dm_sram_out_rd_en),
        .dout(dm_sram_out_dout),
        .empty(dm_sram_out_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(65), .FIFO_BUFFER_SIZE(16)) axi_output_fifo (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(dm_axi_out_wr_en),
        .din(dm_axi_out_din),
        .full(dm_axi_out_full),
        .rd_clk(clock),
        .rd_en(dm_axi_out_rd_en),
        .dout(dm_axi_out_dout),
        .empty(dm_axi_out_empty)
    );

    data_mover dut (
        .clock(clock),
        .reset(reset),
        .df_dm_in_rd_en(df_dm_in_rd_en),
        .df_dm_in_empty(df_dm_in_empty),
        .df_dm_in_dout(df_dm_in_dout),
        .dm_sram_out_wr_en(dm_sram_out_wr_en),
        .dm_sram_out_full(dm_sram_out_full),
        .dm_sram_out_din(dm_sram_out_din),
        .dm_axi_out_wr_en(dm_axi_out_wr_en),
        .dm_axi_out_full(dm_axi_out_full),
        .dm_axi_out_din(dm_axi_out_din)
    );

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    task push_descriptor(input logic [127:0] desc);
    begin
        @(posedge clock);
        df_dm_in_din   <= desc;
        df_dm_in_wr_en <= 1;
        @(posedge clock);
        df_dm_in_wr_en <= 0;
    end
    endtask

    task pop_axi();
    begin
        if (!dm_axi_out_empty) begin
            dm_axi_out_rd_en <= 1;
            @(posedge clock);
            $display("[%0t] AXI OUT: Addr=0x%h Len=%0d RW=%b",
                     $time,
                     dm_axi_out_dout[31:0],
                     dm_axi_out_dout[63:32],
                     dm_axi_out_dout[64]);
            dm_axi_out_rd_en <= 0;
        end
    end
    endtask

    task pop_sram();
    begin
        if (!dm_sram_out_empty) begin
            dm_sram_out_rd_en <= 1;
            @(posedge clock);
            $display("[%0t] SRAM OUT: Addr=0x%h Len=%0d RW=%b",
                     $time,
                     dm_sram_out_dout[31:0],
                     dm_sram_out_dout[63:32],
                     dm_sram_out_dout[64]);
            dm_sram_out_rd_en <= 0;
        end
    end
    endtask


    initial begin
        df_dm_in_wr_en     = 0;
        dm_axi_out_rd_en   = 0;
        dm_sram_out_rd_en  = 0;
        df_dm_in_din       = 0;

        // Reset
        reset <= 1;
        repeat (5) @(posedge clock);
        reset <= 0;


        $display("Pushing descriptors into input FIFO");
        push_descriptor({32'h0000_0001, 32'h0000_0010, 32'h0000_2000, 32'h0000_1000});
        push_descriptor({32'h0000_0000, 32'h0000_0020, 32'h0000_4000, 32'h0000_3000});

        $display("data_mover");
        repeat (20) @(posedge clock);
        
        $display("Reading output FIFOs");
        repeat (16) begin
            pop_axi();
            pop_sram();
        end
        $finish;
    end

endmodule