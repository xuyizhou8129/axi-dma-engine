module bram
#(
	parameter BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
	parameter BRAM_SIZE = dma_pkg::BRAM_SIZE,
	localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
) (
	input logic clock,

	// Existing port — used by sram_controller during DMA operation
	input logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
	input logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
	input logic wr_en,
	input logic [BRAM_DATA_WIDTH-1:0] din,
	output logic [BRAM_DATA_WIDTH-1:0] dout,

	// Init port — used by mem_access_ctrl for preload and readback
	input logic [BRAM_ADDR_WIDTH-1:0] init_addr,
	input logic init_wr_en,
	input logic [BRAM_DATA_WIDTH-1:0] init_din,
	output logic [BRAM_DATA_WIDTH-1:0] init_dout
);

	(* ram_style = "block" *)
	logic [BRAM_DATA_WIDTH-1:0] mem [0:BRAM_SIZE-1];

	always_ff @(posedge clock) begin
		dout <= mem[rd_addr];
		if (wr_en) begin
			mem[wr_addr] <= din;
		end
	end

	always_ff @(posedge clock) begin
		init_dout <= mem[init_addr];
		if (init_wr_en) begin
			mem[init_addr] <= init_din;
		end
	end

endmodule

// Previous implementation kept for reference:
// module bram
// #(
// 	parameter BRAM_DATA_WIDTH = dma_pkg::DATA_WIDTH,
// 	parameter BRAM_SIZE = dma_pkg::BRAM_SIZE,
// 	localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE)
// ) (
// 	input logic clock,
//
// 	// Existing port — used by sram_controller during DMA operation (unchanged)
// 	input logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
// 	input logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
// 	input logic wr_en,
// 	input logic [BRAM_DATA_WIDTH-1:0] din,
// 	output logic [BRAM_DATA_WIDTH-1:0] dout,
//
// 	// New init port — used by mem_access_ctrl for preload and readback
// 	input logic [BRAM_ADDR_WIDTH-1:0] init_addr,
// 	input logic init_wr_en,
// 	input logic [BRAM_DATA_WIDTH-1:0] init_din,
// 	output logic [BRAM_DATA_WIDTH-1:0] init_dout
// );
//
// 	(* ram_style = "block" *)
// 	logic [BRAM_DATA_WIDTH-1:0] mem [0:BRAM_SIZE-1];
//
// 	// Port A (DMA): Vivado simple dual-port template — register output data, not address
// 	always_ff @(posedge clock) begin
// 		if (wr_en) mem[wr_addr] <= din;
// 		dout <= mem[rd_addr];
// 	end
//
// 	// Port B (Init): each port in its own process for true dual-port BRAM inference
// 	always_ff @(posedge clock) begin
// 		if (init_wr_en) mem[init_addr] <= init_din;
// 		init_dout <= mem[init_addr];
// 	end
//
// endmodule
