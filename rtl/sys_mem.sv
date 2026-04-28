// sys_mem.sv
// Synthesizable AXI4 subordinate SRAM block.
//
// Replaces sim/model_sys_mem.sv (behavioral/simulation-only) with a version
// suitable for FPGA or ASIC implementation.
//
// Parameters:
//   MEM_WORDS  - depth of the SRAM in DATA_WIDTH-wide words
//   DATA_WIDTH - AXI data bus width (must match axi_4_if parameterisation)
//   ADDR_WIDTH - AXI address bus width

module sys_mem #(
    parameter int MEM_WORDS  = 256,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH
) (
    axi_4_if.slave axi
);

    logic [DATA_WIDTH-1:0] ram[0:MEM_WORDS-1];

    // -------------------------------------------------------------------------
    // Read FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] { R_IDLE, R_ISSUE } rst_t;
    rst_t r_state;
    logic [ADDR_WIDTH-1:0] r_addr;
    logic [7:0] r_last_beat;
    logic [7:0] r_beat;

    assign axi.arready = (r_state == R_IDLE);

    always_ff @(posedge axi.clk or negedge axi.rst_n) begin
        if (!axi.rst_n) begin
            r_state     <= R_IDLE;
            r_addr      <= '0;
            r_last_beat <= '0;
            r_beat      <= '0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (axi.arvalid && axi.arready) begin
                        r_addr      <= axi.araddr;
                        r_last_beat <= axi.arlen;
                        r_beat      <= '0;
                        r_state     <= R_ISSUE;
                    end
                end
                R_ISSUE: begin
                    if (axi.rvalid && axi.rready) begin
                        if (r_beat == r_last_beat)
                            r_state <= R_IDLE;
                        else
                            r_beat <= r_beat + 1'b1;
                    end
                end
                default: r_state <= R_IDLE;
            endcase
        end
    end

    logic [DATA_WIDTH-1:0] rdata_w;
    logic                  rvalid_w;
    logic                  rlast_w;

    always_comb begin
        rdata_w  = '0;
        rvalid_w = 1'b0;
        rlast_w  = 1'b0;
        if (r_state == R_ISSUE) begin
            rvalid_w = 1'b1;
            if (((r_addr >> 2) + r_beat) < MEM_WORDS)
                rdata_w = ram[(r_addr >> 2) + r_beat];
            rlast_w  = (r_beat == r_last_beat);
        end
    end

    assign axi.rvalid = rvalid_w;
    assign axi.rdata  = rdata_w;
    assign axi.rlast  = rlast_w;
    assign axi.rresp  = 2'b00;

    // -------------------------------------------------------------------------
    // Write FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] { W_IDLE, W_DATA, W_RESP } wst_t;
    wst_t w_state;
    logic [ADDR_WIDTH-1:0] w_addr;
    logic [7:0] w_last_beat;
    logic [7:0] w_beat;

    assign axi.awready = (w_state == W_IDLE);
    assign axi.wready  = (w_state == W_DATA);

    always_ff @(posedge axi.clk or negedge axi.rst_n) begin
        if (!axi.rst_n) begin
            w_state    <= W_IDLE;
            w_addr     <= '0;
            w_last_beat <= '0;
            w_beat     <= '0;
            axi.bvalid <= 1'b0;
            axi.bresp  <= 2'b00;
        end else begin
            case (w_state)
                W_IDLE: begin
                    axi.bvalid <= 1'b0;
                    if (axi.awvalid && axi.awready) begin
                        w_addr      <= axi.awaddr;
                        w_last_beat <= axi.awlen;
                        w_beat      <= '0;
                        w_state     <= W_DATA;
                    end
                end
                W_DATA: begin
                    axi.bvalid <= 1'b0;
                    if (axi.wvalid && axi.wready) begin
                        if (((w_addr >> 2) + w_beat) < MEM_WORDS)
                            ram[(w_addr >> 2) + w_beat] <= axi.wdata;
                        if (axi.wlast)
                            w_state <= W_RESP;
                        else
                            w_beat <= w_beat + 1'b1;
                    end
                end
                W_RESP: begin
                    axi.bvalid <= 1'b1;
                    axi.bresp  <= 2'b00;
                    if (axi.bready)
                        w_state <= W_IDLE;
                end
                default: w_state <= W_IDLE;
            endcase
        end
    end

endmodule : sys_mem