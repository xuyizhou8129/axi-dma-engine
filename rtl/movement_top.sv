//Include Descriptor Fetcher, Data Mover, AXI4 Master, SRAM Controller
//Wire the modules together
//Interface with the ring manager, System Memmory(AXI4 Master), and SRAM(SRAM Controller)
//The AND of the sram_done signal and the axi_done signal is the done signal for the movement top, connected to 
//the ring manger
//reuse the interfaces defined in the rtl folder

module movement_top #(
    parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH       = dma_pkg::LEN_WIDTH,
    parameter int DESC_WORDS      = dma_pkg::DESC_WORDS,
    parameter int HANDLE_WIDTH    = dma_pkg::HANDLE_WIDTH,
    parameter int INSTR_WIDTH     = dma_pkg::INSTR_WIDTH,
    parameter int DESC_WIDTH      = DESC_WORDS * DATA_WIDTH,
    parameter int DF_IN_FIFO_Q    = dma_pkg::DF_IN_FIFO_Q,
    parameter int DF_OUT_FIFO_Q   = dma_pkg::DF_OUT_FIFO_Q,
    parameter int DM_FIFO_Q       = dma_pkg::DM_FIFO_Q
) (
    input  logic clk,
    input  logic rst_n,

    // Ring manager <-> Descriptor Fetcher (names match ring_manager_if.df / RM side)
    input  logic [ADDR_WIDTH-1:0] rm_df_addr,
    input  logic                    rm_df_valid,   // fetch_req_valid from RM
    output logic                    df_ready,      // fetch_req_ready to RM
    output logic                    df_error,
    output logic                    dm_done,       // one-cycle pulse to RM when a movement completes

    // System memory (AXI4)
    axi_4_if.master axi
);

    // data_mover packs len as 32 bits; AXI master uses dma_pkg::INSTR_WIDTH (41) with 8-bit len
    localparam int DM_MOVER_BURST_W = 32;
    localparam int DM_MOVER_INSTR_W = ADDR_WIDTH + DM_MOVER_BURST_W + 1;

    wire reset = ~rst_n;

    // Ring manager <-> descriptor_fetcher bundle (scalar ports on movement_top <-> rm_df_if.df on u_df)
    rm_df_if rm_df ();
    assign rm_df.rm_df_addr       = rm_df_addr;
    assign rm_df.fetch_req_valid  = rm_df_valid;
    assign df_ready                = rm_df.fetch_req_ready;
    assign df_error                = rm_df.df_error;

    // -------------------------------------------------------------------------
    // Descriptor fetcher
    // -------------------------------------------------------------------------
    logic                    df_in_wr_en;
    logic                    df_in_full;
    logic [HANDLE_WIDTH-1:0] df_in_din;

    logic                    df_out_rd_en;
    logic                    df_out_empty;
    logic [DESC_WIDTH-1:0]   df_out_dout;

    logic                    dm_in_wr_en;
    logic                    dm_in_full;
    logic [DESC_WIDTH-1:0]   dm_in_din;

    descriptor_fetcher #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (LEN_WIDTH),
        .DESC_WORDS (DESC_WORDS),
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
    // AXI4 master
    // -------------------------------------------------------------------------
    logic                    df_in_rd_en;
    logic                    df_in_empty;
    logic [HANDLE_WIDTH-1:0] df_in_dout;

    logic                    df_out_wr_en;
    logic                    df_out_full;
    logic [DESC_WIDTH-1:0]   df_out_din;

    logic                    dm_in_rd_en_axi;
    logic                    dm_in_empty_axi;
    logic [INSTR_WIDTH-1:0]  dm_in_dout_axi;

    axi_4_master #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (LEN_WIDTH),
        .DESC_WORDS (DESC_WORDS),
        .HANDLE_WIDTH(HANDLE_WIDTH),
        .INSTR_WIDTH (INSTR_WIDTH),
        .DESC_WIDTH  (DESC_WIDTH)
    ) u_axi (
        .clock        (clk),
        .reset        (reset),
        .df_in_rd_en  (df_in_rd_en),
        .df_in_empty  (df_in_empty),
        .df_in_dout   (df_in_dout),
        .df_out_wr_en (df_out_wr_en),
        .df_out_full  (df_out_full),
        .df_out_din   (df_out_din),
        .dm_in_rd_en  (dm_in_rd_en_axi),
        .dm_in_empty  (dm_in_empty_axi),
        .dm_in_dout   (dm_in_dout_axi),
        .axi_done     (dm_done),
        .axi          (axi)
    );

    // -------------------------------------------------------------------------
    // FIFOs (fifo.sv) — df_in, df_out, dm axi
    // -------------------------------------------------------------------------

    // df_in: DF -> AXI (handle)
    fifo #(
        .FIFO_DATA_WIDTH (HANDLE_WIDTH),
        .FIFO_BUFFER_SIZE(DF_IN_FIFO_Q)
    ) u_df_in_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (df_in_wr_en),
        .din    (df_in_din),
        .full   (df_in_full),
        .rd_clk (clk),
        .rd_en  (df_in_rd_en),
        .dout   (df_in_dout),
        .empty  (df_in_empty)
    );

    // df_out: AXI -> DF (descriptor payload)
    fifo #(
        .FIFO_DATA_WIDTH (DESC_WIDTH),
        .FIFO_BUFFER_SIZE(DF_OUT_FIFO_Q)
    ) u_df_out_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (df_out_wr_en),
        .din    (df_out_din),
        .full   (df_out_full),
        .rd_clk (clk),
        .rd_en  (df_out_rd_en),
        .dout   (df_out_dout),
        .empty  (df_out_empty)
    );

    // Descriptor fetcher -> FIFO -> data_mover -> AXI FIFO (65b -> 41b instr)
    logic                    df_dm_in_rd_en;
    logic                    df_dm_in_empty;
    logic [DESC_WIDTH-1:0]   df_dm_in_dout;
    logic                    desc_full;

    logic [DM_MOVER_INSTR_W-1:0] dm_axi_out_din_wide;
    logic                        dm_axi_out_wr_en;
    logic                        dm_full_axi;
    logic [DM_MOVER_INSTR_W-1:0] dm_fifo_axi_dout_wide;

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
        .dm_axi_out_wr_en(dm_axi_out_wr_en),
        .dm_axi_out_full (dm_full_axi),
        .dm_axi_out_din  (dm_axi_out_din_wide)
    );

    fifo #(
        .FIFO_DATA_WIDTH (DM_MOVER_INSTR_W),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_dm_fifo_axi (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_axi_out_wr_en),
        .din    (dm_axi_out_din_wide),
        .full   (dm_full_axi),
        .rd_clk (clk),
        .rd_en  (dm_in_rd_en_axi),
        .dout   (dm_fifo_axi_dout_wide),
        .empty  (dm_in_empty_axi)
    );

    // Narrow 41b: {rw, len[7:0], addr} from 65b {rw, len32[31:0], addr}
    assign dm_in_dout_axi = {dm_fifo_axi_dout_wide[64], dm_fifo_axi_dout_wide[39:32],
                               dm_fifo_axi_dout_wide[31:0]};

    assign dm_in_full = desc_full;
    // dm_done is driven directly by the axi_done pulse from u_axi

endmodule
