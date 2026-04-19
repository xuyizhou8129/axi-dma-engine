// chat hated my implementation and thought this was better

// SRAM-side interface with AXI-like channel grouping but no ready/valid handshakes.
//IDLE state: wait for the instruction struct from dm, go to r/w based on info
// If instr = READ --> READ state?? (unecessary) check beats with counter (same as in axi4)
    // read data to mid fifo
// if instr = WRITE --> WRITE state?? check beats as well 
    // write the data from mid fifo into bram
// wait for done signal from axi4master before going idle

module sram_controller #(
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH = dma_pkg::LEN_WIDTH,
    parameter int BRAM_SIZE   = dma_pkg::BRAM_SIZE,
    parameter int INSTR_WIDTH = dma_pkg::INSTR_WIDTH,
    localparam int BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
)(
    // global inputs 
    input logic clock,
    input logic reset,
    
    // interface with sram(bram)
    output  logic [BRAM_ADDR_WIDTH-1:0] read_addr,
    output  logic [BRAM_ADDR_WIDTH-1:0] write_addr, // maybe change later
    output  logic wr_en,
    output  logic [BRAM_DATA_WIDTH-1:0] din, 
    input logic [BRAM_DATA_WIDTH-1:0] dout,

    // interfvace with axi4master
    output logic sram_done,
    input logic axi4master_done,

    // mid fifo 
    output logic                    mid_wr_en,
    input  logic                    mid_full,
    output logic [DATA_WIDTH-1:0]   mid_din,
    output logic                    mid_rd_en,
    input  logic                    mid_empty,
    input  logic [DATA_WIDTH-1:0]   mid_dout,

    // data mover 
    output logic                    dm_in_rd_en,
    input  logic                    dm_in_empty,
    input  logic [INSTR_WIDTH-1:0]  dm_in_dout
);
    
    typedef enum logic [2:0] {
        s_idle,
        s_dm_get,
        s_writing,
        s_reading,
        s_wait_axi4master
    } state_types;
    
    state_types state, state_c;

    logic [ADDR_WIDTH-1:0] cur_addr, cur_addr_c;
    logic [LEN_WIDTH-1:0]  cur_len, cur_len_c;
    logic                  cur_write, cur_write_c;
    logic [LEN_WIDTH-1:0]  beat_idx, beat_idx_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            state      <= s_idle;
            cur_addr   <= '0;
            cur_len    <= '0;
            cur_write  <= 1'b0;
            beat_idx   <= '0;
        end else begin
            state      <= state_c;
            cur_addr   <= cur_addr_c;
            cur_len    <= cur_len_c;
            cur_write  <= cur_write_c;
            beat_idx   <= beat_idx_c;
        end
    end

    assign write_addr = cur_addr[BRAM_ADDR_WIDTH-1:0];
    
    // State machine logic
    always_comb begin
        // defaults
        state_c     = state;
        cur_addr_c  = cur_addr;
        cur_len_c   = cur_len;
        cur_write_c = cur_write;
        beat_idx_c  = beat_idx;

        dm_in_rd_en = 1'b0;
        mid_wr_en   = 1'b0;
        mid_din     = '0;
        mid_rd_en   = 1'b0;
        wr_en       = 1'b0;
        din         = '0;
        sram_done   = 1'b0;
        read_addr   = '0;

        case (state)
            s_idle: begin
                if (!dm_in_empty) state_c = s_dm_get;
            end
            s_dm_get: begin
                dm_in_rd_en = 1'b1;
                cur_addr_c  = {2'b0, dm_in_dout[31:2]};  // byte addr → word addr (>> 2)
                cur_len_c   = dm_in_dout[39:32];
                cur_write_c = dm_in_dout[40];
                beat_idx_c  = '0;

                if (dm_in_dout[40] == 1'b1) begin
                    state_c = s_writing;
                end else begin
                    // Pre-fetch: present first read address so BRAM dout is ready on first s_reading cycle
                    state_c    = s_reading;
                    read_addr  = dm_in_dout[31:2];
                    cur_addr_c = {2'b0, dm_in_dout[31:2]} + 1'b1;
                    beat_idx_c = '0;
                end

            end
            s_writing: begin
                if (!mid_empty) begin
                    mid_rd_en  = 1'b1;
                    wr_en      = 1'b1;
                    din        = mid_dout[BRAM_DATA_WIDTH-1:0];
                    cur_addr_c = cur_addr + 1'b1;
                    beat_idx_c = beat_idx + 1'b1;
                    
                    if (beat_idx == (cur_len - 1'b1) || cur_len == '0) begin
                        state_c = s_wait_axi4master;
                    end
                end
            end
            s_reading: begin
                if (!mid_full) begin
                    mid_wr_en  = 1'b1;
                    mid_din    = {{(DATA_WIDTH-BRAM_DATA_WIDTH){1'b0}}, dout};
                    cur_addr_c = cur_addr + 1'b1;
                    beat_idx_c = beat_idx + 1'b1;
                    read_addr  = cur_addr;

                    if (beat_idx == (cur_len - 1'b1) || cur_len == '0) begin
                        state_c = s_wait_axi4master;
                    end
                end
            end

            s_wait_axi4master: begin
                sram_done = 1'b1;
                if (axi4master_done) state_c = s_idle;
            end
            default: state_c = s_idle;
        endcase
    end
endmodule 