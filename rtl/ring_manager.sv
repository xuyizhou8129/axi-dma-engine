// Ring Manager
// Description: Manages head and tail pointers in system memory

module ring_manager (
    input logic clk,            // system clock
    input logic reset_n,        // active-low reset

    // Inputs from CSR
    input logic [2:0] tail_ptr, // tail managed by CPU
    input logic [31:0] ring_base_addr, // Base address of ring buffer

    // Handshake with Descriptor Fetcher
    output logic [31:0] rm_df_addr, // send address to fetch to DF
    output logic fetch_req_valid, // Buffer not empty (head != tail)
    input logic fetch_req_ready,  // DF is ready for new address

    // Inputs from Data Mover
    input logic dm_done, // DM done --> increment head

    // Status to CSR
    output logic buffer_empty // buffer is empty (head == tail)
);

    // Head pointer
    logic [2:0] head_ptr;

    // 8 bytes per descriptor (64-bit alignment)
    localparam int STRIDE = 8;

    // Combinational Logic
    always_comb begin

        // buffer is empty when head = tail
        buffer_empty = (head_ptr == tail_ptr);

        // fetch request valid when buffer is not empty
        fetch_req_valid = !buffer_empty;

        // fetch address = base + (index * bytes)
        rm_df_addr = ring_base_addr + (head_ptr * STRIDE);

    end

    // Sequential Logic
    always_ff @(posedge clk) begin

        if !(reset_n) begin
            // reset head to start of ring buffer
            head_ptr <= 3'b0; 
        end else if (dm_done) begin
            // increment head if DM signals done
            heat_ptr <= head_ptr + 1'b1;
        end

    end
    
endmodule