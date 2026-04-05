// Structural top: descriptor_fetcher + FIFO models + scoreboard capture registers.
// Stimulus and checks live in tb_desc_fetcher.sv.

`timescale 1ns / 1ps

module tb_desc_fetcher_top (
    input logic clock,
    input logic reset,

    input  logic [31:0] rm_df_addr,
    input  logic        rm_df_valid,
    output logic        df_ready,

    input  logic               tb_df_out_wr_en,
    input  logic [127:0]       tb_df_out_din,
    output logic               tb_df_out_full
);

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int LEN_WIDTH  = 8;
    localparam int DESC_WORDS = 4;
    localparam int HANDLE_WIDTH = 40;
    localparam int DESC_WIDTH = DESC_WORDS * DATA_WIDTH;
    localparam int QD = 64;
    localparam int MAX_CAP = 128;

    // DF <-> AXI-master input FIFO (handle)
    logic                    df_in_wr_en;
    logic                    df_in_full;
    logic [HANDLE_WIDTH-1:0] df_in_din;

    // AXI-master callback FIFO -> DF (descriptor)
    logic                    df_out_rd_en;
    logic                    df_out_empty;
    logic [DESC_WIDTH-1:0]   df_out_dout;

    // DF -> DM descriptor FIFO
    logic                    dm_in_wr_en;
    logic                    dm_in_full;
    logic [DESC_WIDTH-1:0]   dm_in_din;

    descriptor_fetcher #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .DESC_WORDS(DESC_WORDS),
        .HANDLE_WIDTH(HANDLE_WIDTH)
    ) dut (
        .clock       (clock),
        .reset       (reset),
        .df_in_wr_en (df_in_wr_en),
        .df_in_full  (df_in_full),
        .df_in_din   (df_in_din),
        .df_out_rd_en(df_out_rd_en),
        .df_out_empty(df_out_empty),
        .df_out_dout (df_out_dout),
        .dm_in_wr_en (dm_in_wr_en),
        .dm_in_full  (dm_in_full),
        .dm_in_din   (dm_in_din),
        .rm_df_addr  (rm_df_addr),
        .rm_df_valid (rm_df_valid),
        .df_ready    (df_ready)
    );

    logic [HANDLE_WIDTH-1:0] df_in_fifo_dout_unused;
    logic                    df_in_fifo_empty_unused;
    fifo #(
        .FIFO_DATA_WIDTH(HANDLE_WIDTH),
        .FIFO_BUFFER_SIZE(QD)
    ) u_df_in_fifo (
        .reset (reset),
        .wr_clk(clock),
        .wr_en (df_in_wr_en),
        .din   (df_in_din),
        .full  (df_in_full),
        .rd_clk(clock),
        .rd_en (1'b0),
        .dout  (df_in_fifo_dout_unused),
        .empty (df_in_fifo_empty_unused)
    );

    fifo #(
        .FIFO_DATA_WIDTH(DESC_WIDTH),
        .FIFO_BUFFER_SIZE(QD)
    ) u_df_out_fifo (
        .reset (reset),
        .wr_clk(clock),
        .wr_en (tb_df_out_wr_en),
        .din   (tb_df_out_din),
        .full  (tb_df_out_full),
        .rd_clk(clock),
        .rd_en (df_out_rd_en),
        .dout  (df_out_dout),
        .empty (df_out_empty)
    );

    logic [DESC_WIDTH-1:0] dm_in_fifo_dout_unused;
    logic                  dm_in_fifo_empty_unused;
    fifo #(
        .FIFO_DATA_WIDTH(DESC_WIDTH),
        .FIFO_BUFFER_SIZE(QD)
    ) u_dm_in_fifo (
        .reset (reset),
        .wr_clk(clock),
        .wr_en (dm_in_wr_en),
        .din   (dm_in_din),
        .full  (dm_in_full),
        .rd_clk(clock),
        .rd_en (1'b0),
        .dout  (dm_in_fifo_dout_unused),
        .empty (dm_in_fifo_empty_unused)
    );

    logic [HANDLE_WIDTH-1:0] cap_df_in[0:MAX_CAP-1];
    logic [DESC_WIDTH-1:0]   cap_dm_in[0:MAX_CAP-1];
    integer n_cap_df_in, n_cap_dm_in;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            n_cap_df_in <= 0;
            n_cap_dm_in <= 0;
        end else begin
            if (df_in_wr_en && !df_in_full && n_cap_df_in < MAX_CAP) begin
                cap_df_in[n_cap_df_in] <= df_in_din;
                n_cap_df_in <= n_cap_df_in + 1;
            end
            if (dm_in_wr_en && !dm_in_full && n_cap_dm_in < MAX_CAP) begin
                cap_dm_in[n_cap_dm_in] <= dm_in_din;
                n_cap_dm_in <= n_cap_dm_in + 1;
            end
        end
    end

endmodule
