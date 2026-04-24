// movement_top: Descriptor Fetcher + Data Mover with memory stub.
// AXI4 master removed; stub responds to fetch requests with a hardcoded
// test descriptor so the pipeline can be exercised without external memory.

module movement_top #(
    parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH       = dma_pkg::LEN_WIDTH,
    parameter int DESC_WORDS      = dma_pkg::DESC_WORDS,
    parameter int HANDLE_WIDTH    = dma_pkg::HANDLE_WIDTH,
    parameter int INSTR_WIDTH     = dma_pkg::INSTR_WIDTH,
    parameter int DESC_WIDTH      = DESC_WORDS * DATA_WIDTH,
    parameter int DM_FIFO_Q       = dma_pkg::DM_FIFO_Q
) (
    input  logic clk,
    input  logic rst_n,

    // Ring manager <-> Descriptor Fetcher
    input  logic [ADDR_WIDTH-1:0] rm_df_addr,
    input  logic                  rm_df_valid,
    output logic                  df_ready,
    output logic                  df_error,
    output logic                  dm_done,

    // Probe outputs
    output logic                  probe_df_in_wr_en,
    output logic                  probe_dm_wr_en,
    output logic                  probe_dm_instr_rw
);

    // Descriptor layout (16-bit words, DESC_WIDTH=64):
    // [15:0]=SRC_ADDR [31:16]=DST_ADDR [39:32]=LEN [48]=DIR(1=read,0=write)
    localparam logic [DESC_WIDTH-1:0] TEST_DESC = 64'h0001_0004_1234_ABCD;

    wire reset = ~rst_n;

    // RM <-> DF interface bundle
    rm_df_if rm_df ();
    assign rm_df.rm_df_addr      = rm_df_addr;
    assign rm_df.fetch_req_valid = rm_df_valid;
    assign df_ready              = rm_df.fetch_req_ready;
    assign df_error              = rm_df.df_error;

    // -------------------------------------------------------------------------
    // Memory stub (replaces AXI4 master)
    // df_in side: always ready to accept handles from DF
    // df_out side: one cycle after DF writes a handle, make TEST_DESC available
    // -------------------------------------------------------------------------
    logic                    df_in_full;
    logic                    df_in_wr_en;
    logic [HANDLE_WIDTH-1:0] df_in_din;

    logic                    df_out_rd_en;
    logic                    df_out_empty;
    logic [DESC_WIDTH-1:0]   df_out_dout;

    logic stub_desc_valid;

    assign df_in_full   = 1'b0;
    assign df_out_dout  = TEST_DESC;
    assign df_out_empty = ~stub_desc_valid;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            stub_desc_valid <= 1'b0;
        end else begin
            if (df_in_wr_en && !stub_desc_valid)
                stub_desc_valid <= 1'b1;
            else if (df_out_rd_en)
                stub_desc_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Descriptor Fetcher
    // -------------------------------------------------------------------------
    logic                  dm_in_wr_en;
    logic                  dm_in_full;
    logic [DESC_WIDTH-1:0] dm_in_din;

    descriptor_fetcher #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .LEN_WIDTH   (LEN_WIDTH),
        .DESC_WORDS  (DESC_WORDS),
        .HANDLE_WIDTH(HANDLE_WIDTH),
        .INSTR_WIDTH (INSTR_WIDTH),
        .DESC_WIDTH  (DESC_WIDTH)
    ) u_df (
        .clock       (clk),
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
        .rm_df       (rm_df)
    );

    // -------------------------------------------------------------------------
    // Descriptor → Data Mover FIFO
    // -------------------------------------------------------------------------
    logic                  df_dm_in_rd_en;
    logic                  df_dm_in_empty;
    logic [DESC_WIDTH-1:0] df_dm_in_dout;
    logic                  desc_full;

    fifo #(
        .FIFO_DATA_WIDTH (DESC_WIDTH),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_desc_to_dm_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_in_wr_en),
        .din    (dm_in_din),
        .full   (desc_full),
        .rd_clk (clk),
        .rd_en  (df_dm_in_rd_en),
        .dout   (df_dm_in_dout),
        .empty  (df_dm_in_empty)
    );
    assign dm_in_full = desc_full;

    // -------------------------------------------------------------------------
    // Data Mover
    // -------------------------------------------------------------------------
    logic                   dm_axi_out_wr_en;
    logic                   dm_full_axi;
    logic [INSTR_WIDTH-1:0] dm_axi_out_din;

    data_mover #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .BURST_SIZE_WIDTH(LEN_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .DESC_WORDS      (DESC_WORDS),
        .DESC_WIDTH      (DESC_WIDTH)
    ) u_data_mover (
        .clock           (clk),
        .reset           (reset),
        .df_dm_in_rd_en  (df_dm_in_rd_en),
        .df_dm_in_empty  (df_dm_in_empty),
        .df_dm_in_dout   (df_dm_in_dout),
        .dm_axi_out_wr_en(dm_axi_out_wr_en),
        .dm_axi_out_full (dm_full_axi),
        .dm_axi_out_din  (dm_axi_out_din)
    );

    // -------------------------------------------------------------------------
    // DM output FIFO: stub drains it each cycle and pulses dm_done
    // -------------------------------------------------------------------------
    logic                   dm_in_rd_en_stub;
    logic                   dm_in_empty_stub;

    fifo #(
        .FIFO_DATA_WIDTH (INSTR_WIDTH),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_dm_out_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_axi_out_wr_en),
        .din    (dm_axi_out_din),
        .full   (dm_full_axi),
        .rd_clk (clk),
        .rd_en  (dm_in_rd_en_stub),
        .dout   (/* unused */),
        .empty  (dm_in_empty_stub)
    );

    assign dm_in_rd_en_stub = !dm_in_empty_stub;
    // dm_done is high for exactly 1 cycle when an instruction is drained
    assign dm_done = !dm_in_empty_stub;

    // -------------------------------------------------------------------------
    // Probe outputs
    // -------------------------------------------------------------------------
    assign probe_df_in_wr_en = df_in_wr_en;
    assign probe_dm_wr_en    = dm_axi_out_wr_en;
    assign probe_dm_instr_rw = dm_axi_out_din[INSTR_WIDTH-1];

endmodule
