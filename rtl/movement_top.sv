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
    parameter int BRAM_SIZE       = dma_pkg::BRAM_SIZE,
    parameter int DF_IN_FIFO_Q    = dma_pkg::DF_IN_FIFO_Q,
    parameter int DF_OUT_FIFO_Q   = dma_pkg::DF_OUT_FIFO_Q,
    parameter int DM_FIFO_Q       = dma_pkg::DM_FIFO_Q,
    parameter int MID_FIFO_Q      = dma_pkg::MID_FIFO_Q
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

    localparam int BRAM_DATA_WIDTH = DATA_WIDTH;

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

    logic                    mid_wr_en_axi;
    logic                    mid_full;
    logic [DATA_WIDTH-1:0]   mid_din_axi;
    logic                    mid_rd_en_axi;
    logic                    mid_empty;
    logic [DATA_WIDTH-1:0]   mid_dout;

    logic                    sram_done;
    logic                    axi_done;

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
        .mid_wr_en    (mid_wr_en_axi),
        .mid_full     (mid_full),
        .mid_din      (mid_din_axi),
        .mid_rd_en    (mid_rd_en_axi),
        .mid_empty    (mid_empty),
        .mid_dout     (mid_dout),
        .sram_done    (sram_done),
        .axi_done     (axi_done),
        .axi          (axi)
    );

    // -------------------------------------------------------------------------
    // SRAM controller + BRAM
    // -------------------------------------------------------------------------
    localparam int BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE);

    logic [BRAM_ADDR_WIDTH-1:0] bram_rd_addr;
    logic [BRAM_ADDR_WIDTH-1:0] bram_wr_addr;
    logic                       bram_wr_en;
    logic [BRAM_DATA_WIDTH-1:0] bram_din;
    logic [BRAM_DATA_WIDTH-1:0] bram_dout;

    logic                    dm_in_rd_en_sram;
    logic                    dm_in_empty_sram;
    logic [INSTR_WIDTH-1:0]  dm_in_dout_sram;

    logic                    mid_wr_en_sram;
    logic                    mid_rd_en_sram;
    logic [DATA_WIDTH-1:0]   mid_din_sram;

    sram_controller #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .BRAM_DATA_WIDTH (BRAM_DATA_WIDTH),
        .LEN_WIDTH       (LEN_WIDTH),
        .BRAM_SIZE       (BRAM_SIZE),
        .INSTR_WIDTH     (INSTR_WIDTH)
    ) u_sram (
        .clock           (clk),
        .reset           (reset),
        .read_addr       (bram_rd_addr),
        .write_addr      (bram_wr_addr),
        .wr_en           (bram_wr_en),
        .din             (bram_din),
        .dout            (bram_dout),
        .sram_done       (sram_done),
        .axi4master_done (axi_done),
        .mid_wr_en       (mid_wr_en_sram),
        .mid_full        (mid_full),
        .mid_din         (mid_din_sram),
        .mid_rd_en       (mid_rd_en_sram),
        .mid_empty       (mid_empty),
        .mid_dout        (mid_dout),
        .dm_in_rd_en     (dm_in_rd_en_sram),
        .dm_in_empty     (dm_in_empty_sram),
        .dm_in_dout      (dm_in_dout_sram)
    );

    bram #(
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH),
        .BRAM_SIZE      (BRAM_SIZE)
    ) u_bram (
        .clock   (clk),
        .rd_addr (bram_rd_addr),
        .wr_addr (bram_wr_addr),
        .wr_en   (bram_wr_en),
        .din     (bram_din),
        .dout    (bram_dout)
    );

    // -------------------------------------------------------------------------
    // FIFOs (fifo.sv) — df_in, df_out, dual dm (parallel write), mid
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

    // DM: duplicate FIFOs (same write from DF) — AXI and SRAM each have a read port
    logic dm_full_axi;
    logic dm_full_sram;

    // Descriptor fetcher drives 128b dm_in_din; AXI/SRAM expect 41b instruction — use low bits
    wire [INSTR_WIDTH-1:0] dm_in_instr = dm_in_din[INSTR_WIDTH-1:0];

    fifo #(
        .FIFO_DATA_WIDTH (INSTR_WIDTH),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_dm_fifo_axi (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_in_wr_en),
        .din    (dm_in_instr),
        .full   (dm_full_axi),
        .rd_clk (clk),
        .rd_en  (dm_in_rd_en_axi),
        .dout   (dm_in_dout_axi),
        .empty  (dm_in_empty_axi)
    );

    fifo #(
        .FIFO_DATA_WIDTH (INSTR_WIDTH),
        .FIFO_BUFFER_SIZE(DM_FIFO_Q)
    ) u_dm_fifo_sram (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (dm_in_wr_en),
        .din    (dm_in_instr),
        .full   (dm_full_sram),
        .rd_clk (clk),
        .rd_en  (dm_in_rd_en_sram),
        .dout   (dm_in_dout_sram),
        .empty  (dm_in_empty_sram)
    );

    // Block DF push if either parallel DM FIFO is full
    assign dm_in_full = dm_full_axi | dm_full_sram;

    // mid: shared between AXI and SRAM (muxed write data / enables)
    wire mid_wr_en = mid_wr_en_axi | mid_wr_en_sram;
    wire mid_rd_en = mid_rd_en_axi | mid_rd_en_sram;
    wire [DATA_WIDTH-1:0] mid_din = mid_wr_en_axi ? mid_din_axi : mid_din_sram;

    fifo #(
        .FIFO_DATA_WIDTH (DATA_WIDTH),
        .FIFO_BUFFER_SIZE(MID_FIFO_Q)
    ) u_mid_fifo (
        .reset  (reset),
        .wr_clk (clk),
        .wr_en  (mid_wr_en),
        .din    (mid_din),
        .full   (mid_full),
        .rd_clk (clk),
        .rd_en  (mid_rd_en),
        .dout   (mid_dout),
        .empty  (mid_empty)
    );

    // -------------------------------------------------------------------------
    // Ring manager dm_done: pulse when movement completes (both paths handshake)
    // -------------------------------------------------------------------------
    logic handshake_done;
    logic handshake_done_d;

    assign handshake_done = sram_done & axi_done;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            handshake_done_d <= 1'b0;
            dm_done            <= 1'b0;
        end else begin
            handshake_done_d <= handshake_done;
            dm_done            <= handshake_done & ~handshake_done_d;
        end
    end

endmodule
