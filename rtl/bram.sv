module bram 
#(
  parameter BRAM_DATA_WIDTH = 32,
  parameter BRAM_SIZE = 1024,
  localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
) (
  input  logic clock,
  input  logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
  input  logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
  input  logic wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0] din, 
  output logic [BRAM_DATA_WIDTH-1:0] dout);

  // 8x8 two-dimensional memory array
  // syn_ramstyle directs Synplify to infer block RAM (e.g., M9K on Cyclone IV)
  (* syn_ramstyle = "block_ram" *)
  logic [BRAM_SIZE-1:0][BRAM_DATA_WIDTH-1:0] mem;
  logic [BRAM_ADDR_WIDTH-1:0] read_addr;
  
  assign dout = mem[read_addr];
  
  always_ff @(posedge clock) begin
    read_addr <= rd_addr;
    if (wr_en) mem[wr_addr] <= din; 
  end

endmodule