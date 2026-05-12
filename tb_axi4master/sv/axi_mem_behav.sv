// Behavioral AXI4 memory slave (32-bit data, awlen/arlen = beats-1). Used by tb_axi_4_master.
// Loads initial RAM with $readmemh; path is relative to simulation working directory.

`timescale 1ns / 1ps

module axi_mem_behav #(
    parameter int MEM_WORDS = 256
) (
    axi_4_if.slave axi
);

    logic [31:0] ram[0:MEM_WORDS-1];

    typedef enum logic [1:0] { R_IDLE, R_ISSUE } rst_t;
    rst_t r_state;
    logic [31:0] r_addr;
    logic [7:0] r_last_beat;  // beat index when rlast asserted (= arlen)
    logic [7:0] r_beat;

    typedef enum logic [1:0] { W_IDLE, W_DATA, W_RESP } wst_t;
    wst_t w_state;
    logic [31:0] w_addr;
    logic [7:0] w_last_beat;
    logic [7:0] w_beat;

    // RAM must be written from a single procedural block (Questa vopt rejects
    // initial + always_ff both driving ram).
    reg [1023:0] mem_hex_path;
    logic ram_preloaded = 1'b0;

    // Read address channel (stall until RAM image is loaded; one cycle after reset release)
    assign axi.arready = ram_preloaded && (r_state == R_IDLE);

    always_ff @(posedge axi.clk or negedge axi.rst_n) begin
        if (!axi.rst_n) begin
            r_state   <= R_IDLE;
            r_addr    <= '0;
            r_last_beat <= '0;
            r_beat    <= '0;
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

    logic [31:0] rdata_w;
    logic rvalid_w;
    logic rlast_w;

    always_comb begin
        rdata_w  = '0;
        rvalid_w = 1'b0;
        rlast_w  = 1'b0;
        if (r_state == R_ISSUE) begin
            rvalid_w = 1'b1;
            rdata_w  = ram[(r_addr >> 2) + r_beat];
            rlast_w  = (r_beat == r_last_beat);
        end
    end

    assign axi.rvalid = rvalid_w;
    assign axi.rdata  = rdata_w;
    assign axi.rlast  = rlast_w;
    assign axi.rresp  = 2'b00;

    // Write address + data + response
    assign axi.awready = ram_preloaded && (w_state == W_IDLE);
    assign axi.wready  = ram_preloaded && (w_state == W_DATA);

    always_ff @(posedge axi.clk or negedge axi.rst_n) begin
        if (!axi.rst_n) begin
            w_state       <= W_IDLE;
            w_addr        <= '0;
            w_last_beat   <= '0;
            w_beat        <= '0;
            axi.bvalid    <= 1'b0;
            axi.bresp     <= 2'b00;
            ram_preloaded <= 1'b0;
        end else if (!ram_preloaded) begin
            integer ri;
            for (ri = 0; ri < MEM_WORDS; ri = ri + 1)
                ram[ri] = 32'h0;
            if (!$value$plusargs("MEMHEX=%s", mem_hex_path))
                mem_hex_path = "../out/initial_mem.hex";
            $readmemh(mem_hex_path, ram);
            ram_preloaded <= 1'b1;
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
                        ram[(w_addr >> 2) + w_beat] <= axi.wdata;
                        if (axi.wlast) begin
                            if (w_beat != w_last_beat)
                                $error("axi_mem_behav: WLAST beat mismatch");
                            w_state <= W_RESP;
                        end else
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

endmodule
