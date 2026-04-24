// data mover

module data_mover #(
    //parameters
    parameter int ADDR_WIDTH = 32,
    parameter int BURST_SIZE_WIDTH = 32, 

    // output instruction structs
    parameter int INSTR_WIDTH = ADDR_WIDTH + BURST_SIZE_WIDTH + 1,

    // input descriptor struct
    parameter int DATA_WIDTH = 32,
    parameter int DESC_WORDS = 4,
    parameter int DESC_WIDTH   = (DESC_WORDS * DATA_WIDTH)

)(
    // inputs and outputs
    input logic clock,
    input logic reset,


    // input descriptor struct - read from fifo
    output logic                    df_dm_in_rd_en,
    input  logic                    df_dm_in_empty,
    input  logic [DESC_WIDTH-1:0] df_dm_in_dout, // descriptor struct

    // output instruction struct (AXI only; SRAM path removed)
    output logic                    dm_axi_out_wr_en,
    input  logic                    dm_axi_out_full,
    output logic [INSTR_WIDTH-1:0]   dm_axi_out_din

);

    logic [INSTR_WIDTH-1:0] instr_axi, instr_axi_next;
    logic axi_wr_en;

    assign dm_axi_out_din = instr_axi;
    assign dm_axi_out_wr_en = axi_wr_en;



    typedef enum logic [1:0] {
        GET_DATA,
        DECODE,
        SEND_INSTR
    } data_mover_state;

    data_mover_state state, next_state;

    logic [DESC_WIDTH-1:0] input_data, new_input_data;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            state <= GET_DATA;
            input_data <= '0;
            instr_axi <= '0;
        end else begin
            state <= next_state;
            input_data <= new_input_data;
            instr_axi <= instr_axi_next;
        end
    end

    always_comb begin
        next_state = state;
        new_input_data = input_data;
        instr_axi_next = instr_axi;
        axi_wr_en = 0;
        df_dm_in_rd_en = 0;

        case (state)

            
            GET_DATA: begin
             
                if (df_dm_in_empty == 0) begin
                    df_dm_in_rd_en = 1'b1;
                    next_state = DECODE;
                    new_input_data = df_dm_in_dout;
                end
                else begin
                    next_state = GET_DATA;
                end
                end

            // Descriptor layout (16-bit words, DESC_WIDTH=64):
            // [15:0]=SRC_ADDR [31:16]=DST_ADDR [47:32]=LEN(8-bit@[39:32]) [63:48]=FLAGS([48]=DIR)
            // DIR=1: AXI reads from SRC; DIR=0: AXI writes to DST
            DECODE: begin
                if (input_data[48]) begin
                    instr_axi_next[ADDR_WIDTH-1:0]                    = input_data[ADDR_WIDTH-1:0]; // SRC
                    instr_axi_next[ADDR_WIDTH+BURST_SIZE_WIDTH-1:ADDR_WIDTH] = input_data[39:32];   // LEN
                    instr_axi_next[INSTR_WIDTH-1]                     = 1'b0;                       // read
                end else begin
                    instr_axi_next[ADDR_WIDTH-1:0]                    = input_data[31:16];          // DST
                    instr_axi_next[ADDR_WIDTH+BURST_SIZE_WIDTH-1:ADDR_WIDTH] = input_data[39:32];   // LEN
                    instr_axi_next[INSTR_WIDTH-1]                     = 1'b1;                       // write
                end
                next_state = SEND_INSTR;
            end

            SEND_INSTR: begin
                if (!dm_axi_out_full) begin
                    axi_wr_en  = 1'b1;
                    next_state = GET_DATA;
                end else begin
                    next_state = SEND_INSTR;
                    axi_wr_en  = 1'b0;
                    instr_axi_next = instr_axi;
                end
            end
    default: next_state = GET_DATA;
        endcase
    end
  
endmodule


