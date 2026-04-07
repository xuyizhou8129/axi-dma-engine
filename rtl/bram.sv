module bram 
#(
  parameter BRAM_DATA_WIDTH = 8,
  parameter BRAM_ROW_WIDTH = 8,
  parameter BRAM_COL_WIDTH = 8
) (
  input  logic clock,
  input  logic [2:0] rd_row_addr,
  input  logic [2:0] rd_col_addr,
  input  logic [2:0] wr_row_addr,
  input  logic [2:0] wr_col_addr,
  input  logic wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0] din, 
  output logic [BRAM_DATA_WIDTH-1:0] dout);

  // 8x8 two-dimensional memory array
  // syn_ramstyle directs Synplify to infer block RAM (e.g., M9K on Cyclone IV)
  (* syn_ramstyle = "block_ram" *)
  logic [BRAM_ROW_WIDTH-1:0][BRAM_COL_WIDTH-1:0][BRAM_DATA_WIDTH-1:0] mem;
  logic [2:0] read_row_addr;
  logic [2:0] read_col_addr;
  
  assign dout = mem[read_row_addr][read_col_addr];
  
  always_ff @(posedge clock) begin
    read_row_addr <= rd_row_addr;
    read_col_addr <= rd_col_addr;
    if (wr_en) mem[wr_row_addr][wr_col_addr] <= din; 
  end

endmodule