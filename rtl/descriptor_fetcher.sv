// Descriptor Fetcher: bridges Ring Manager → AXI4 master (handle FIFO) and
// AXI4 master → Data Mover (descriptor FIFO). SRAM bounds checking removed.

module descriptor_fetcher #(
    parameter int ADDR_WIDTH   = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH   = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH    = dma_pkg::LEN_WIDTH,
    parameter int DESC_WORDS   = dma_pkg::DESC_WORDS,
    parameter int HANDLE_WIDTH = dma_pkg::HANDLE_WIDTH,
    parameter int INSTR_WIDTH  = dma_pkg::INSTR_WIDTH,
    parameter int DESC_WIDTH   = DESC_WORDS * DATA_WIDTH
)(
    input  logic clock,
    input  logic reset,

    // Handle FIFO → AXI4 master (fetch request)
    output logic                    df_in_wr_en,
    input  logic                    df_in_full,
    output logic [HANDLE_WIDTH-1:0] df_in_din,

    // AXI4 master → descriptor FIFO (fetched payload)
    output logic                    df_out_rd_en,
    input  logic                    df_out_empty,
    input  logic [DESC_WIDTH-1:0]   df_out_dout,

    // Descriptor FIFO → Data Mover
    output logic                    dm_in_wr_en,
    input  logic                    dm_in_full,
    output logic [DESC_WIDTH-1:0]   dm_in_din,

    rm_df_if.df rm_df
);

    assign rm_df.fetch_req_ready = ~df_in_full;
    assign rm_df.df_error        = 1'b0;  // no error sources without SRAM

    // Registered outputs (cut combinational paths)
    logic                    df_in_wr_en_r,  df_in_wr_en_c;
    logic [HANDLE_WIDTH-1:0] df_in_din_r,    df_in_din_c;
    logic                    dm_in_wr_en_r,  dm_in_wr_en_c;
    logic [DESC_WIDTH-1:0]   dm_in_din_r,    dm_in_din_c;

    assign df_in_wr_en = df_in_wr_en_r;
    assign df_in_din   = df_in_din_r;
    assign dm_in_wr_en = dm_in_wr_en_r;
    assign dm_in_din   = dm_in_din_r;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            df_in_wr_en_r <= '0;
            df_in_din_r   <= '0;
            dm_in_wr_en_r <= '0;
            dm_in_din_r   <= '0;
        end else begin
            df_in_wr_en_r <= df_in_wr_en_c;
            df_in_din_r   <= df_in_din_c;
            dm_in_wr_en_r <= dm_in_wr_en_c;
            dm_in_din_r   <= dm_in_din_c;
        end
    end

    always_comb begin
        df_in_wr_en_c = 1'b0;
        df_in_din_c   = '0;
        dm_in_wr_en_c = 1'b0;
        dm_in_din_c   = '0;
        df_out_rd_en  = 1'b0;

        // Forward ring manager address to AXI as fetch handle
        if (!df_in_full && rm_df.fetch_req_valid) begin
            df_in_wr_en_c                        = 1'b1;
            df_in_din_c[ADDR_WIDTH-1:0]          = rm_df.rm_df_addr;
            df_in_din_c[HANDLE_WIDTH-1:ADDR_WIDTH] = LEN_WIDTH'(DESC_WORDS);
        end

        // Forward fetched descriptor to data mover
        if (!df_out_empty && !dm_in_full) begin
            df_out_rd_en  = 1'b1;
            dm_in_wr_en_c = 1'b1;
            dm_in_din_c   = df_out_dout;
        end
    end

endmodule
