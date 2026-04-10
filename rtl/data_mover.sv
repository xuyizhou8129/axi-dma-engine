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
    output logic                    df_dm_in_rd_en, /
    input  logic                    df_dm_in_empty,
    input  logic [DESC_WIDTH-1:0] df_dm_in_dout, // descriptor struct

    // output instruction structs
    output logic                    dm_sram_out_wr_en,
    input  logic                    dm_sram_out_full,
    output logic [INSTR_WIDTH-1:0]   dm_sram_out_din,

    output logic                    dm_axi_out_wr_en,
    input  logic                    dm_axi_out_full,
    output logic [INSTR_WIDTH-1:0]   dm_axi_out_din

    input logic global_enable;

);

    logic [INSTR_WIDTH-1:0] instr_axi, instr_axi_next;
    logic [INSTR_WIDTH-1:0] instr_sram, instr_sram_next;

    logic axi_wr_en;
    logic sram_wr_en;

    assign dm_axi_out_din = instr_axi;
    assign dm_axi_out_wr_en = axi_wr_en;
    
    assign dm_sram_out_din = instr_sram;
    assign dm_sram_out_wr_en = sram_wr_en;



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
            instr_sram <= '0;
            instr_axi <= '0;

        end else begin
            state <= next_state;
            input_data <= new_input_data;
            instr_sram <= instr_sram_next;
            instr_axi <= instr_axi_next;
  
        end

    end

    always_comb begin

        next_state = state;
        new_input_data = input_data;
        instr_sram_next = instr_sram; 
        instr_axi_next = instr_axi; 
        axi_wr_en = 0;
        sram_wr_en = 0;
        df_dm_in_rd_en = 0;

        case (state)

            
            GET_DATA: begin
             
                if (global_enable && df_dm_in_empty == 0) begin
                    df_dm_in_rd_en = 1'b1;
                    next_state = DECODE;
                    new_input_data = df_dm_in_dout;
                end
                else begin
                    next_state = GET_DATA;
                end
                end

            DECODE: begin

                if (global_enable) begin

                if (input_data[96]) begin
                    // insutruction address
                    instr_axi_next[31:0] = input_data[31:0];// src_addr , read = true, is sram = False
                    instr_sram_next[31:0] = input_data[63:32];// dest addr, 

                    // length
                    instr_axi_next[63:32] = input_data[95:64];
                    instr_sram_next[63:32] = input_data[95:64];

                    // read and write
                    instr_axi_next[64] = 1'b1;
                    instr_sram_next[64] = 1'b0;
               end
                else begin
                    instr_axi_next[31:0] = input_data[63:32];
                    instr_sram_next[31:0] = input_data[31:0];

                     // length
                    instr_axi_next[63:32] = input_data[95:64];
                    instr_sram_next[63:32] = input_data[95:64];

                    // read and write
                    instr_axi_next[64] = 1'b0;
                    instr_sram_next[64] = 1'b1;
           end
                next_state = SEND_INSTR;   


            end
            else begin
                next_state = DECODE;
                input_data_next = input_data;
            end

            end

 
    SEND_INSTR: begin
        if (!dm_sram_out_full && !dm_axi_out_full && global_enable) begin     
            axi_wr_en  = 1'b1;
            sram_wr_en = 1'b1;
            next_state = GET_DATA;
        end 
        else begin
            next_state = SEND_INSTR;
            sram_wr_en  = 1'b0;
            axi_wr_en  = 1'b0;
            instr_sram_next = instr_sram;
            instr_axi_next = instr_axi;
        end
    end
    default: next_state = GET_DATA;
        endcase
    end
  
endmodule



