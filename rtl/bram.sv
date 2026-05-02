module bram
#(
  parameter BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
  parameter BRAM_SIZE = dma_pkg::BRAM_SIZE,
  localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
) (
  input  logic clock,

  // Existing port — used by sram_controller during DMA operation (unchanged)
  input  logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
  input  logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
  input  logic wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0] din,
  output logic [BRAM_DATA_WIDTH-1:0] dout,

  // New init port — used by mem_access_ctrl for preload and readback
  input  logic [BRAM_ADDR_WIDTH-1:0] init_addr,
  input  logic                       init_wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0] init_din,
  output logic [BRAM_DATA_WIDTH-1:0] init_dout
);

  // 8x8 two-dimensional memory array
  // syn_ramstyle directs Synplify to infer block RAM (e.g., M9K on Cyclone IV)
  (* syn_ramstyle = "block_ram" *)
  logic [BRAM_SIZE-1:0][BRAM_DATA_WIDTH-1:0] mem;
  logic [BRAM_ADDR_WIDTH-1:0] read_addr;
  logic [BRAM_ADDR_WIDTH-1:0] init_read_addr;

  // Existing read path (unchanged)
  assign dout = mem[read_addr];

  // New init read path
  assign init_dout = mem[init_read_addr];

  always_ff @(posedge clock) begin
    // Existing write path (unchanged)
    read_addr <= rd_addr;
    if (wr_en) mem[wr_addr] <= din;

    // New init write path
    init_read_addr <= init_addr;
    if (init_wr_en) mem[init_addr] <= init_din;
  end

endmodule