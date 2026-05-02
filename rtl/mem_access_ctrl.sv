// mem_access_ctrl.sv
// AXI-Lite slave that drives plain SRAM-style init ports on bram and sys_mem.
// Structure mirrors csr.sv: captures AW/W independently, commits on both pending.
//
// Register map (byte offsets, 32-bit aligned):
//   0x00  INIT_ADDR  R/W  Target byte address for next read or write
//   0x04  INIT_DATA  R/W  Data to write; holds last written value
//   0x08  SRAM_WR    W    Write 1 → pulse bram.init_wr_en for one cycle
//   0x0C  SRAM_RD    W    Write 1 → latch bram.init_dout into RDATA reg
//   0x10  MEM_WR     W    Write 1 → pulse sys_mem.init_wr_en for one cycle
//   0x14  MEM_RD     W    Write 1 → latch sys_mem.init_rdata into RDATA reg
//   0x18  RDATA      R    Read-only; holds last captured readback value
//   0x1C  INIT_DONE  R/W  Write 1 → signal preload complete (DMA may now start)

module mem_access_ctrl #(
    parameter int AXIL_ADDR_WIDTH = dma_pkg::AXIL_ADDR_WIDTH,
    parameter int AXIL_DATA_WIDTH = dma_pkg::AXIL_DATA_WIDTH,
    parameter int BRAM_SIZE       = dma_pkg::BRAM_SIZE,
    parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
    parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH
) (
    // AXI-Lite slave port
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic [AXIL_ADDR_WIDTH-1:0] awaddr,
    input  logic [2:0]                 awprot,
    input  logic                       awvalid,
    output logic                       awready,

    input  logic [AXIL_DATA_WIDTH-1:0] wdata,
    input  logic [3:0]                 wstrb,
    input  logic                       wvalid,
    output logic                       wready,

    output logic [1:0]                 bresp,
    output logic                       bvalid,
    input  logic                       bready,

    input  logic [AXIL_ADDR_WIDTH-1:0] araddr,
    input  logic [2:0]                 arprot,
    input  logic                       arvalid,
    output logic                       arready,

    output logic [AXIL_DATA_WIDTH-1:0] rdata,
    output logic [1:0]                 rresp,
    output logic                       rvalid,
    input  logic                       rready,

    // BRAM init port connections
    output logic [$clog2(BRAM_SIZE)-1:0] bram_init_addr,
    output logic                         bram_init_wr_en,
    output logic [DATA_WIDTH-1:0]        bram_init_din,
    input  logic [DATA_WIDTH-1:0]        bram_init_dout,

    // sys_mem init port connections
    output logic [ADDR_WIDTH-1:0]        mem_init_addr,
    output logic                         mem_init_wr_en,
    output logic [DATA_WIDTH-1:0]        mem_init_wdata,
    input  logic [DATA_WIDTH-1:0]        mem_init_rdata,

    // init_done flag (to gate DMA start)
    output logic                         init_done
);

    localparam int AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;

    // Register offsets
    localparam logic [7:0] REG_INIT_ADDR = 8'h00;
    localparam logic [7:0] REG_INIT_DATA = 8'h04;
    localparam logic [7:0] REG_SRAM_WR   = 8'h08;
    localparam logic [7:0] REG_SRAM_RD   = 8'h0C;
    localparam logic [7:0] REG_MEM_WR    = 8'h10;
    localparam logic [7:0] REG_MEM_RD    = 8'h14;
    localparam logic [7:0] REG_RDATA     = 8'h18;
    localparam logic [7:0] REG_INIT_DONE = 8'h1C;

    // ----------------------------------------------------------------
    // Writable registers
    // ----------------------------------------------------------------
    logic [31:0] reg_init_addr;
    logic [31:0] reg_init_data;
    logic [31:0] reg_rdata;
    logic        reg_init_done;

    // ----------------------------------------------------------------
    // AXI write channel capture registers
    // ----------------------------------------------------------------
    logic                            aw_pending;
    logic [AXIL_ADDR_WIDTH-1:0]      aw_addr;
    logic                            w_pending;
    logic [AXIL_DATA_WIDTH-1:0]      wd_data;
    logic [AXIL_STRB_WIDTH-1:0]      wd_strb;
    logic                            bvalid_r;
    logic [1:0]                      bresp_r;

    // ----------------------------------------------------------------
    // AXI read channel registers
    // ----------------------------------------------------------------
    logic [AXIL_DATA_WIDTH-1:0]      rdata_r;
    logic                            rvalid_r;

    // ----------------------------------------------------------------
    // One-cycle output pulses (combinational from commit)
    // ----------------------------------------------------------------
    logic sram_wr_pulse;
    logic sram_rd_pulse;
    logic mem_wr_pulse;
    logic mem_rd_pulse;

    // ----------------------------------------------------------------
    // Byte-lane strobe merge
    // ----------------------------------------------------------------
    function automatic logic [31:0] apply_wstrb(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [AXIL_STRB_WIDTH-1:0] strb
    );
        int i;
        begin
            apply_wstrb = old_data;
            for (i = 0; i < 4; i++) begin
                if (strb[i])
                    apply_wstrb[i*8 +: 8] = new_data[i*8 +: 8];
            end
        end
    endfunction

    // ----------------------------------------------------------------
    // AXI channel handshakes
    // ----------------------------------------------------------------
    logic aw_hs, w_hs, ar_hs;
    assign aw_hs = awvalid && awready;
    assign w_hs  = wvalid  && wready;
    assign ar_hs = arvalid && arready;

    logic [7:0] wr_addr_lsb;
    logic [7:0] rd_addr_lsb;
    assign wr_addr_lsb = aw_addr[7:0];
    assign rd_addr_lsb = araddr[7:0];

    // ----------------------------------------------------------------
    // AXI response channel drive
    // ----------------------------------------------------------------
    assign awready = ~aw_pending && ~bvalid_r;
    assign wready  = ~w_pending  && ~bvalid_r;
    assign bvalid  = bvalid_r;
    assign bresp   = bresp_r;
    assign arready = ~rvalid_r;
    assign rvalid  = rvalid_r;
    assign rresp   = dma_pkg::AXI_RESP_OKAY;
    assign rdata   = rdata_r;

    // ----------------------------------------------------------------
    // Read data mux
    // ----------------------------------------------------------------
    logic [31:0] read_data;
    always_comb begin
        read_data = 32'd0;
        unique case (rd_addr_lsb)
            REG_INIT_ADDR: read_data = reg_init_addr;
            REG_INIT_DATA: read_data = reg_init_data;
            REG_RDATA:     read_data = reg_rdata;
            REG_INIT_DONE: read_data = {31'd0, reg_init_done};
            // Write-only strobes read back as 0
            default:       read_data = 32'd0;
        endcase
    end

    // ----------------------------------------------------------------
    // Output wire assignments (registered address/data, pulse from commit)
    // ----------------------------------------------------------------
    assign bram_init_addr  = reg_init_addr[$clog2(BRAM_SIZE)+1:2];  // byte addr -> word index
    assign bram_init_din   = reg_init_data;
    assign bram_init_wr_en = sram_wr_pulse;

    assign mem_init_addr   = reg_init_addr;
    assign mem_init_wdata  = reg_init_data;
    assign mem_init_wr_en  = mem_wr_pulse;

    assign init_done       = reg_init_done;

    // ----------------------------------------------------------------
    // Sequential state
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_init_addr <= 32'd0;
            reg_init_data <= 32'd0;
            reg_rdata     <= 32'd0;
            reg_init_done <= 1'b0;
            aw_pending    <= 1'b0;
            aw_addr       <= '0;
            w_pending     <= 1'b0;
            wd_data       <= '0;
            wd_strb       <= '0;
            bvalid_r      <= 1'b0;
            bresp_r       <= dma_pkg::AXI_RESP_OKAY;
            rdata_r       <= '0;
            rvalid_r      <= 1'b0;
        end else begin
            // Default deassert pulses (set combinationally below via always_comb)
            // AW capture
            if (aw_hs) begin
                aw_pending <= 1'b1;
                aw_addr    <= awaddr;
            end

            // W capture
            if (w_hs) begin
                w_pending <= 1'b1;
                wd_data   <= wdata;
                wd_strb   <= wstrb;
            end

            // Write commit
            if (~bvalid_r && aw_pending && w_pending) begin
                unique case (wr_addr_lsb)
                    REG_INIT_ADDR: reg_init_addr <= apply_wstrb(reg_init_addr, wd_data, wd_strb);
                    REG_INIT_DATA: reg_init_data <= apply_wstrb(reg_init_data, wd_data, wd_strb);
                    REG_INIT_DONE: reg_init_done <= wd_data[0];
                    // SRAM_WR, SRAM_RD, MEM_WR, MEM_RD: pulse-only, no register update
                    default: ;
                endcase

                // Latch readback on RD pulses (combinational pulse this cycle → latch next)
                if (wr_addr_lsb == REG_SRAM_RD && wd_data[0])
                    reg_rdata <= bram_init_dout;
                if (wr_addr_lsb == REG_MEM_RD && wd_data[0])
                    reg_rdata <= mem_init_rdata;

                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
                bvalid_r   <= 1'b1;
                bresp_r    <= dma_pkg::AXI_RESP_OKAY;
            end

            // Write response handshake
            if (bvalid_r && bready)
                bvalid_r <= 1'b0;

            // Read: latch on AR handshake
            if (ar_hs) begin
                rvalid_r <= 1'b1;
                rdata_r  <= read_data;
            end else if (rvalid_r && rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------------------
    // One-cycle write pulses (combinational: valid only during commit cycle)
    // ----------------------------------------------------------------
    assign sram_wr_pulse = (~bvalid_r && aw_pending && w_pending)
                           && (wr_addr_lsb == REG_SRAM_WR) && wd_data[0];

    assign sram_rd_pulse = (~bvalid_r && aw_pending && w_pending)
                           && (wr_addr_lsb == REG_SRAM_RD) && wd_data[0];

    assign mem_wr_pulse  = (~bvalid_r && aw_pending && w_pending)
                           && (wr_addr_lsb == REG_MEM_WR) && wd_data[0];

    assign mem_rd_pulse  = (~bvalid_r && aw_pending && w_pending)
                           && (wr_addr_lsb == REG_MEM_RD) && wd_data[0];

endmodule : mem_access_ctrl
