//Origional starter code ben+mike

// SRAM-side interface with AXI-like channel grouping but no ready/valid handshakes.
//IDLE state: wait for the instruction struct from dm, go to r/w based on info
// If instr = READ --> READ state?? (unecessary) check beats with counter (same as in axi4)
    // read data to mid fifo
// if instr = WRITE --> WRITE state?? check beats as well 
    // write the data from mid fifo into bram
// wait for done signal from axi4master before going idle
l

interface sram_controller #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
)(
    // global inputs 
    input logic clock,
    input logic reset,
    // interface with sram(bram)
    output  logic [2:0] read_addr,
    output  logic [2:0] write_addr, // maybe change later
    output  logic wr_en,
    output  logic [BRAM_DATA_WIDTH-1:0] din, 
    input logic [BRAM_DATA_WIDTH-1:0] dout,

    // interfvace with axi4master
    output logic sram_done,
    input logic axi4master_done,
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
    logic [DESC_WIDTH-1:0] desc_buf, desc_buf_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            state      <= s_idle;
            cur_addr   <= '0;
            cur_len    <= '0;
            cur_write  <= 1'b0;
            beat_idx   <= '0;
            desc_buf   <= '0;
        end else begin
            state      <= state_c;
            cur_addr   <= cur_addr_c;
            cur_len    <= cur_len_c;
            cur_write  <= cur_write_c;
            beat_idx   <= beat_idx_c;
            desc_buf   <= desc_buf_c;
        end
    end

  
    // mid fifo 
    // data movier 
    //