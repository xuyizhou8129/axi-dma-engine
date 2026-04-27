// movement_top: Descriptor Fetcher + Data Mover + memory stub.
// Stub replaces AXI4 master: fetches complete in 1 cycle with zeroed descriptor,
// DM instructions complete in 1 cycle (dm_done pulse).

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

    // Probe outputs for observability
    output logic                  probe_df_in_wr_en,
    output logic                  probe_dm_wr_en,
    output logic                  probe_dm_instr_rw
);

    localparam int DM_MOVER_BURST_W = LEN_WIDTH;
    localparam int DM_MOVER_INSTR_W = INSTR_WIDTH;

    wire reset = ~rst_n;

    // -------------------------------------------------------------------------
    // rm_df_if wiring
    // -------------------------------------------------------------------------
    rm_df_if rm_df ();
    assign rm_df.rm_df_addr      = rm_df_addr;
    assign rm_df.fetch_req_valid = rm_df_valid;
    assign df_ready               = rm_df.fetch_req_ready;
    assign df_error               = rm_df.df_error;

    // -------------------------------------------------------------------------
    // Descriptor Fetcher <-> stub (df_in: handle, df_out: descriptor payload)
    // -------------------------------------------------------------------------
    logic                    df_in_wr_en;
    logic                    df_in_full;
    logic [HANDLE_WIDTH-1:0] df_in_din;

    logic                    df_out_rd_en;
    logic                    df_out_empty;
    logic [DESC_WIDTH-1:0]   df_out_dout;

    // Stub: accept fetch handle, respond next cycle with zeroed descriptor.
    logic fetch_pending;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)                              fetch_pending <= 1'b0;
        else if (df_in_wr_en && !df_in_full)   fetch_pending <= 1'b1;
        else if (df_out_rd_en)                  fetch_pending <= 1'b0;
    end
    assign df_in_full   = fetch_pending;
    assign df_out_empty = ~fetch_pending;
    assign df_out_dout  = '0;

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
        .clock        (clk),
        .reset        (reset),
        .df_in_wr_en  (df_in_wr_en),
        .df_in_full   (df_in_full),
        .df_in_din    (df_in_din),
        .df_out_rd_en (df_out_rd_en),
        .df_out_empty (df_out_empty),
        .df_out_dout  (df_out_dout),
        .dm_in_wr_en  (dm_in_wr_en),
        .dm_in_full   (dm_in_full),
        .dm_in_din    (dm_in_din),
        .rm_df        (rm_df)
    );

    // -------------------------------------------------------------------------
    // Descriptor Fetcher -> Data Mover FIFO
    // -------------------------------------------------------------------------
    logic                  df_dm_in_rd_en;
    logic                  df_dm_in_empty;
    logic [DESC_WIDTH-1:0] df_dm_in_dout;

    fifo #(
        .FIFO_DATA_WIDTH (DESC_WIDTH),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_desc_to_dm_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_in_wr_en),
        .din    (dm_in_din),
        .full   (dm_in_full),
        .rd_clk (clk),
        .rd_en  (df_dm_in_rd_en),
        .dout   (df_dm_in_dout),
        .empty  (df_dm_in_empty)
    );

    // -------------------------------------------------------------------------
    // Data Mover
    // -------------------------------------------------------------------------
    logic [DM_MOVER_INSTR_W-1:0] dm_instr;
    logic                         dm_instr_wr_en;
    logic                         dm_instr_full;

    data_mover #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .BURST_SIZE_WIDTH(DM_MOVER_BURST_W),
        .DATA_WIDTH      (DATA_WIDTH),
        .DESC_WORDS      (DESC_WORDS),
        .DESC_WIDTH      (DESC_WIDTH)
    ) u_data_mover (
        .clock           (clk),
        .reset           (reset),
        .df_dm_in_rd_en  (df_dm_in_rd_en),
        .df_dm_in_empty  (df_dm_in_empty),
        .df_dm_in_dout   (df_dm_in_dout),
        .dm_axi_out_wr_en(dm_instr_wr_en),
        .dm_axi_out_full (dm_instr_full),
        .dm_axi_out_din  (dm_instr)
    );

    // Stub: always accept DM instruction, pulse dm_done 1 cycle later.
    assign dm_instr_full = 1'b0;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) dm_done <= 1'b0;
        else       dm_done <= dm_instr_wr_en;
    end

    // -------------------------------------------------------------------------
    // Probe outputs
    // -------------------------------------------------------------------------
    assign probe_df_in_wr_en  = df_in_wr_en;
    assign probe_dm_wr_en     = dm_instr_wr_en;
    assign probe_dm_instr_rw  = dm_instr[dma_pkg::INSTR_RW_BIT];

endmodule
