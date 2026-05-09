module bram
#(
  parameter BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
  parameter BRAM_SIZE = dma_pkg::BRAM_SIZE,
  localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
) (
  input  logic clock,

  input  logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
  input  logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
  input  logic wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0] din,
  output logic [BRAM_DATA_WIDTH-1:0] dout
);

  (* ram_style = "block" *)
  logic [BRAM_DATA_WIDTH-1:0] mem [0:BRAM_SIZE-1];

  // Port A: write
  always_ff @(posedge clock) begin
    if (wr_en) mem[wr_addr] <= din;
  end

  // Port B: registered read output (matches AMD SDP BRAM inference template)
  always_ff @(posedge clock) begin
    dout <= mem[rd_addr];
  end

endmodule
