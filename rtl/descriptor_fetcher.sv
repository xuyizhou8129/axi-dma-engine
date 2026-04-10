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
module descriptor_fetcher #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int LEN_WIDTH  = 8,
    parameter int DESC_WORDS = 4,
    parameter int HANDLE_WIDTH = 40,      // [31:0] addr, [39:32] len (beats)
    parameter int INSTR_WIDTH  = 41,      // [31:0] addr, [39:32] len, [40] rw (1=write, 0=read)
    parameter int DESC_WIDTH   = (DESC_WORDS * DATA_WIDTH)
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
    output logic df_ready
);

    localparam int RW_BIT  = INSTR_WIDTH - 1;
    localparam int LEN_MSB = 32 + LEN_WIDTH - 1;
    localparam int LEN_LSB = 32;

    //Descriptor Fetcher is ready to fetch a descriptor if the descriptor side fifo is not full
    assign df_ready = df_in_full == 1'b0;

    //Registered outputs - Data Mover
    logic dm_in_wr_en_c, dm_in_wr_en_o;
    logic [DESC_WIDTH-1:0] dm_in_din_c, dm_in_din_o;

    //Registered outputs - AXI4 Master
    logic df_in_wr_en_c, df_in_wr_en_o;
    logic [HANDLE_WIDTH-1:0] df_in_din_c, df_in_din_o;

    //tied registered values to outputs
    assign dm_in_wr_en = dm_in_wr_en_o;
    assign dm_in_din = dm_in_din_o;
    assign df_in_wr_en = df_in_wr_en_o;
    assign df_in_din = df_in_din_o;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            dm_in_wr_en_o <= 1'b0;
            dm_in_din_o <= '0;
            df_in_wr_en_o <= 1'b0;
            df_in_din_o <= '0;
        end else begin
            dm_in_wr_en_o <= dm_in_wr_en_c;
            dm_in_din_o <= dm_in_din_c;
            df_in_wr_en_o <= df_in_wr_en_c;
            df_in_din_o <= df_in_din_c;
        end
    end

    always_comb begin
        dm_in_wr_en_c = 1'b0;
        dm_in_din_c = '0;
        df_in_wr_en_c = 1'b0;
        df_in_din_c = '0;
        df_out_rd_en = 1'b0;
//If descriptor side fifo is not full && ring manager is valid:
//Take the address from the ring manager and make it a handle struct and put it into the AXI4 Master Input FIFO
//If the AXI4 Master Output FIFO is not empty && Data Mover is not full:
//Pass the descriptor from the AXI4 Master Output FIFO to the Data Mover Input FIFO
        if (df_in_full == 1'b0 && rm_df_valid == 1'b1) begin
            df_in_wr_en_c = 1'b1;
            df_in_din_c[31:0] = rm_df_addr;
            df_in_din_c[39:32] = 8'h4; //Fixed length of 4 words for current descriptor structure
        end
        
        if (df_out_empty == 1'b0 && dm_in_full == 1'b0) begin
            df_out_rd_en = 1'b1;
            dm_in_din_c = df_out_dout;
            dm_in_wr_en_c = 1'b1;
        end
    end

endmodule