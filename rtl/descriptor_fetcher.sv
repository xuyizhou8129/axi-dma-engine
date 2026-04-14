//Descriptor Fetcher
//Accepts a handle from the ring manager and passes it to the AXI4 Master
//Accepts a descriptor from the AXI4 Master and passes it to the Data Mover
//Workflow:
//If descriptor side fifo is not full && ring manager is valid:
//Take the address from the ring manager and make it a handle struct and put it into the AXI4 Master Input FIFO
//If the AXI4 Master Output FIFO is not empty && Data Mover is not full:
//Pass the descriptor from the AXI4 Master Output FIFO to the Data Mover Input FIFO

//Theoretically I can make this module purely combinational,
//but for cutting down worst path, I register the outputs

//Check the error cases: Invalid SRAM address, Invalid Length (From Descriptor)
//Once error is detected, send out a df_error to the ring manager
//after sending the reset signal to the ring manager, it skips the current bad descriptor and continues

module descriptor_fetcher #(
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH  = dma_pkg::LEN_WIDTH,
    parameter int DESC_WORDS = dma_pkg::DESC_WORDS,
    parameter int HANDLE_WIDTH = dma_pkg::HANDLE_WIDTH,
    parameter int INSTR_WIDTH  = dma_pkg::INSTR_WIDTH,
    parameter int DESC_WIDTH   = (DESC_WORDS * DATA_WIDTH),
    parameter int MAX_SRAM_ADDR = dma_pkg::MAX_SRAM_ADDR
)(
    input  logic clock,
    input  logic reset,

    // Descriptor Fetcher input FIFO (handle)
    output logic                    df_in_wr_en,
    input  logic                    df_in_full,
    output logic [HANDLE_WIDTH-1:0] df_in_din,

    // Descriptor Fetcher callback FIFO (descriptor payload)
    output logic                    df_out_rd_en,
    input  logic                    df_out_empty,
    input  logic [DESC_WIDTH-1:0]   df_out_dout,

    // Data Mover descriptor FIFO
    output logic                    dm_in_wr_en,
    input  logic                    dm_in_full,
    output logic [DESC_WIDTH-1:0]  dm_in_din,

    //handshake with ring manager
    input  logic [ADDR_WIDTH-1:0]  rm_df_addr,
    input logic rm_df_valid,
    output logic df_ready,
    output logic df_error //asserted when an error is detected
);

    localparam int RW_BIT  = dma_pkg::instr_rw_bit(INSTR_WIDTH);
    localparam int LEN_MSB = dma_pkg::instr_len_msb(LEN_WIDTH);
    localparam int LEN_LSB = dma_pkg::INSTR_LEN_LSB;

    //Descriptor Fetcher is ready to fetch a descriptor if the descriptor side fifo is not full
    assign df_ready = df_in_full == 1'b0;

    //Registered outputs - Data Mover
    logic dm_in_wr_en_c, dm_in_wr_en_o;
    logic [DESC_WIDTH-1:0] dm_in_din_c, dm_in_din_o;

    //Registered outputs - AXI4 Master
    logic df_in_wr_en_c, df_in_wr_en_o;
    logic [HANDLE_WIDTH-1:0] df_in_din_c, df_in_din_o;

    //Internal flag to stop receiving from ring manager
    logic df_error_c;

    // 33-bit end-address check to prevent 32-bit wrap-around false negatives
    logic [32:0] desc_end_addr;
    assign desc_end_addr = {1'b0, df_out_dout[31:0]} + ({1'b0, df_out_dout[39:32]} << 2);

typedef enum logic [1:0] {
    s_error,
    s_normal
} state_types;

state_types state, state_c;

    //tied registered values to outputs
    assign dm_in_wr_en = dm_in_wr_en_o;
    assign dm_in_din = dm_in_din_o;
    assign df_in_wr_en = df_in_wr_en_o;
    assign df_in_din = df_in_din_o;
    assign df_error = df_error_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            dm_in_wr_en_o <= 1'b0;
            dm_in_din_o <= '0;
            df_in_wr_en_o <= 1'b0;
            df_in_din_o <= '0;
            state <= s_normal;
        end else begin
            dm_in_wr_en_o <= dm_in_wr_en_c;
            dm_in_din_o <= dm_in_din_c;
            df_in_wr_en_o <= df_in_wr_en_c;
            df_in_din_o <= df_in_din_c;
            state <= state_c;
        end
    end

    always_comb begin
        state_c = state;
        dm_in_wr_en_c = 1'b0;
        dm_in_din_c = '0;
        df_in_wr_en_c = 1'b0;
        df_in_din_c = '0;
        df_out_rd_en = 1'b0;
        df_error_c = 1'b0;
//If descriptor side fifo is not full && ring manager is valid:
//Take the address from the ring manager and make it a handle struct and put it into the AXI4 Master Input FIFO
//If the AXI4 Master Output FIFO is not empty && Data Mover is not full:
//Pass the descriptor from the AXI4 Master Output FIFO to the Data Mover Input FIFO

//Check the error cases: Invalid SRAM address, Invalid Length (From Descriptor)
//Once error is detected, send out a df_error to the ring manager
//after sending the reset signal to the ring manager, it pauses half of the pipeline(receiving from ring manager)
// and clear out the wrong descriptor
    case (state)
        s_normal: begin

                if (df_in_full == 1'b0 && rm_df_valid == 1'b1) begin
                    df_in_wr_en_c = 1'b1;
                    df_in_din_c[31:0] = rm_df_addr;
                    df_in_din_c[39:32] = 8'h4; //Fixed length of 4 words for current descriptor structure
                end
                
                if (df_out_empty == 1'b0 && dm_in_full == 1'b0) begin
                    df_out_rd_en = 1'b1;
                    if (desc_end_addr > MAX_SRAM_ADDR) begin
                        df_error_c = 1'b1;
                        state_c = s_error;
                    end else begin
                        dm_in_din_c = df_out_dout;
                        dm_in_wr_en_c = 1'b1;
                end
            end
        end

         s_error: begin
                if (df_out_empty == 1'b0 && dm_in_full == 1'b0) begin
                    df_out_rd_en = 1'b1;
                    if (desc_end_addr > MAX_SRAM_ADDR) begin
                        df_error_c = 1'b1;
                    end else begin
                        dm_in_din_c = df_out_dout;
                        dm_in_wr_en_c = 1'b1;
                end
            end
                if (df_in_full == 1'b0 && rm_df_valid == 1'b1) begin
                    df_in_wr_en_c = 1'b1;
                    df_in_din_c[31:0] = rm_df_addr;
                    df_in_din_c[39:32] = 8'h4; //Fixed length of 4 words for current descriptor structure
                    state_c = s_normal;
                end
        end
    endcase
    end
endmodule