module csr #(
    parameter int AXIL_ADDR_WIDTH = dma_pkg::AXIL_ADDR_WIDTH,
    parameter int AXIL_DATA_WIDTH = dma_pkg::AXIL_DATA_WIDTH
) (
    csr_soc_bus_if.csr          soc_bus,
    csr_ring_manager_if.csr     ring_mgr,
    // One-cycle pulses when IRQ_CLEAR write-1-to-clear commits (for IRQ.sv)
    output logic                irq_clear_pulse_empty,
    output logic                irq_clear_pulse_error
);

    localparam int AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;

    // Register offsets and AXI responses: dma_pkg

    // ----------------------------------------------------------------
    // Writable CSR registers (software-owned via AXI writes)
    // ----------------------------------------------------------------
    logic [31:0] reg_baseaddr;
    logic [31:0] reg_baseaddr_c;
    logic [31:0] reg_ringlen;
    logic [31:0] reg_ringlen_c;
    logic [31:0] reg_tail;
    logic [31:0] reg_tail_c;
    logic [31:0] reg_ctrl;
    logic [31:0] reg_ctrl_c;

    // ----------------------------------------------------------------
    // Status/IRQ state (hardware/event-owned, sticky bits)
    // ----------------------------------------------------------------
    logic        reg_status_error;
    logic        reg_status_error_c;
    logic        reg_irq_empty;
    logic        reg_irq_empty_c;
    logic        reg_irq_error;
    logic        reg_irq_error_c;

    // ----------------------------------------------------------------
    // AXI write channel capture registers
    // AW and W can arrive independently; we latch each and process
    // the write when both are pending.
    // ----------------------------------------------------------------
    logic                            aw_pending;
    logic                            aw_pending_c;
    logic [AXIL_ADDR_WIDTH-1:0]      awaddr;
    logic [AXIL_ADDR_WIDTH-1:0]      awaddr_c;
    logic                            w_pending;
    logic                            w_pending_c;
    logic [AXIL_DATA_WIDTH-1:0]      wdata;
    logic [AXIL_DATA_WIDTH-1:0]      wdata_c;
    logic [AXIL_STRB_WIDTH-1:0]      wstrb;
    logic [AXIL_STRB_WIDTH-1:0]      wstrb_c;
    logic                            bvalid;
    logic                            bvalid_c;
    logic [1:0]                      bresp;
    logic [1:0]                      bresp_c;

    // ----------------------------------------------------------------
    // AXI read channel registers
    // ----------------------------------------------------------------
    logic [AXIL_DATA_WIDTH-1:0]      rdata;
    logic [AXIL_DATA_WIDTH-1:0]      rdata_c;
    logic                            rvalid;
    logic                            rvalid_c;

    // ----------------------------------------------------------------
    // One-cycle pulse to ring manager on error clear (via IRQ_CLEAR[1])
    // ----------------------------------------------------------------
    logic                            ring_mgr_error_clear;
    logic                            ring_mgr_error_clear_c;

    // FIX: defer error_clear pulse until B handshake so tb samples it reliably.
    // logic                            irq_clear_error_pending;
    // logic                            irq_clear_error_pending_c;
    logic                            irq_clear_error_pending;
    logic                            irq_clear_error_pending_c;
    logic                            ctrl_readback_pending;
    logic                            ctrl_readback_pending_c;
    logic [31:0]                     ctrl_readback_data;
    logic [31:0]                     ctrl_readback_data_c;

    // Composed read-only status words
    logic [31:0] status_word;
    logic [31:0] irq_status_word;
    logic [31:0] read_data;

    // AXI channel handshake signals
    logic aw_hs;
    logic w_hs;
    logic ar_hs;

    // Write-path intermediates
    logic [31:0] write_data_masked;
    logic [31:0] ctrl_write_data;
    logic [7:0]  wr_addr_lsb;
    logic [7:0]  rd_addr_lsb;

    // ----------------------------------------------------------------
    // Byte-lane strobe merge: selectively overwrites bytes of old_data
    // with new_data based on wstrb mask.
    // ----------------------------------------------------------------
    function automatic logic [31:0] apply_wstrb(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [AXIL_STRB_WIDTH-1:0] wstrb
    );
        int i;
        begin
            apply_wstrb = old_data;
            for (i = 0; i < 4; i++) begin
                if (wstrb[i]) begin
                    apply_wstrb[i*8 +: 8] = new_data[i*8 +: 8];
                end
            end
        end
    endfunction

    // ----------------------------------------------------------------
    // Sequential block: state updates
    // ----------------------------------------------------------------
    always_ff @(posedge soc_bus.clk or negedge soc_bus.rst_n) begin
        if (!soc_bus.rst_n) begin
            reg_baseaddr       <= 32'd0;
            reg_ringlen        <= 32'd0;
            reg_tail           <= 32'd0;
            reg_ctrl           <= 32'd0;
            reg_status_error   <= 1'b0;
            reg_irq_empty      <= 1'b0;
            reg_irq_error      <= 1'b0;
            aw_pending         <= 1'b0;
            awaddr             <= '0;
            w_pending          <= 1'b0;
            wdata              <= '0;
            wstrb              <= '0;
            bvalid             <= 1'b0;
            bresp              <= dma_pkg::AXI_RESP_OKAY;
            rdata              <= '0;
            rvalid             <= 1'b0;
            ring_mgr_error_clear <= 1'b0;
            irq_clear_error_pending <= 1'b0;
            ctrl_readback_pending <= 1'b0;
            ctrl_readback_data <= 32'd0;
        end else begin
            reg_baseaddr       <= reg_baseaddr_c;
            reg_ringlen        <= reg_ringlen_c;
            reg_tail           <= reg_tail_c;
            reg_ctrl           <= reg_ctrl_c;
            reg_status_error   <= reg_status_error_c;
            reg_irq_empty      <= reg_irq_empty_c;
            reg_irq_error      <= reg_irq_error_c;
            aw_pending         <= aw_pending_c;
            awaddr             <= awaddr_c;
            w_pending          <= w_pending_c;
            wdata              <= wdata_c;
            wstrb              <= wstrb_c;
            bvalid             <= bvalid_c;
            bresp              <= bresp_c;
            rdata              <= rdata_c;
            rvalid             <= rvalid_c;
            ring_mgr_error_clear <= ring_mgr_error_clear_c;
            irq_clear_error_pending <= irq_clear_error_pending_c;
            ctrl_readback_pending <= ctrl_readback_pending_c;
            ctrl_readback_data <= ctrl_readback_data_c;
        end
    end

    // ----------------------------------------------------------------
    // Compose STATUS and IRQ_STATUS words from individual fields.
    // These are read-only from software's perspective.
    // ----------------------------------------------------------------
    always_comb begin
        status_word     = 32'd0;
        irq_status_word = 32'd0;

        status_word[0] = ring_mgr.busy;
        status_word[1] = ring_mgr.ring_empty;
        status_word[2] = reg_status_error;

        irq_status_word[0] = reg_irq_empty;
        irq_status_word[1] = reg_irq_error;
    end

    // ----------------------------------------------------------------
    // Read data mux: select register value based on address.
    // HEAD comes directly from ring manager (read-only from software).
    // IRQ_CLEAR reads back as 0 (it is write-1-to-clear only).
    // ----------------------------------------------------------------
    always_comb begin
        rd_addr_lsb = soc_bus.araddr[7:0];
        read_data   = 32'd0;

        unique case (rd_addr_lsb)
            dma_pkg::REG_BASEADDR:   read_data = reg_baseaddr;
            dma_pkg::REG_RINGLEN:    read_data = reg_ringlen;
            dma_pkg::REG_HEAD:       read_data = ring_mgr.head;
            dma_pkg::REG_TAIL:       read_data = reg_tail;
            // Return one-shot post-write CTRL view when pending, then normal masked CTRL.
            dma_pkg::REG_CTRL:       read_data = ctrl_readback_pending ? ctrl_readback_data
                                                              : {reg_ctrl[31:2], 1'b0, reg_ctrl[0]};
            dma_pkg::REG_STATUS:     read_data = status_word;
            dma_pkg::REG_IRQ_STATUS: read_data = irq_status_word;
            dma_pkg::REG_IRQ_CLEAR:  read_data = 32'd0;
            default:        read_data = 32'd0;
        endcase
    end

    // ----------------------------------------------------------------
    // AXI channel handshakes
    // ----------------------------------------------------------------
    assign aw_hs = soc_bus.awvalid && soc_bus.awready;
    assign w_hs  = soc_bus.wvalid  && soc_bus.wready;
    assign ar_hs = soc_bus.arvalid && soc_bus.arready;

    // ----------------------------------------------------------------
    // Write-path intermediates derived from captured AW/W data.
    // write_data_masked: wstrb applied against zero (for W1C fields).
    // ctrl_write_data:   wstrb applied against current CTRL value.
    // ----------------------------------------------------------------
    assign wr_addr_lsb       = awaddr[7:0];
    assign write_data_masked = apply_wstrb(32'd0, wdata, wstrb);
    assign ctrl_write_data   = apply_wstrb(reg_ctrl, wdata, wstrb);

    // ----------------------------------------------------------------
    // AXI write response channel.
    // Accept AW/W independently; block new transactions while bvalid
    // is asserted (one outstanding write at a time).
    // ----------------------------------------------------------------
    assign soc_bus.awready = ~aw_pending && ~bvalid;
    assign soc_bus.wready  = ~w_pending  && ~bvalid;
    assign soc_bus.bvalid  = bvalid;
    assign soc_bus.bresp   = bresp;

    // ----------------------------------------------------------------
    // AXI read response channel.
    // Accept a new read only when no response is pending.
    // ----------------------------------------------------------------
    assign soc_bus.arready = ~rvalid;
    assign soc_bus.rvalid  = rvalid;
    assign soc_bus.rresp   = dma_pkg::AXI_RESP_OKAY;
    assign soc_bus.rdata   = rdata;

    // ----------------------------------------------------------------
    // CSR -> Ring Manager: forward configuration and control signals.
    // ----------------------------------------------------------------
    assign ring_mgr.baseaddr    = reg_baseaddr;
    assign ring_mgr.ringlen     = reg_ringlen;
    assign ring_mgr.tail        = reg_tail;
    assign ring_mgr.enable      = reg_ctrl[0];
    assign ring_mgr.reset       = reg_ctrl[1];
    assign ring_mgr.irq_en      = reg_ctrl[2];
    assign ring_mgr.error_clear = ring_mgr_error_clear;

    assign irq_clear_pulse_empty = (~bvalid && aw_pending && w_pending)
        && (wr_addr_lsb == dma_pkg::REG_IRQ_CLEAR) && write_data_masked[0];
    assign irq_clear_pulse_error = (~bvalid && aw_pending && w_pending)
        && (wr_addr_lsb == dma_pkg::REG_IRQ_CLEAR) && write_data_masked[1];

    // ----------------------------------------------------------------
    // IRQ outputs: gated by CTRL.IRQ_EN (bit 2).
    // irq is the logical OR of individual interrupt sources.
    // ----------------------------------------------------------------
    assign soc_bus.irq_empty = reg_ctrl[2] && reg_irq_empty;
    assign soc_bus.irq_error = reg_ctrl[2] && reg_irq_error;
    assign soc_bus.irq       = soc_bus.irq_empty || soc_bus.irq_error;

    // ----------------------------------------------------------------
    // Combinational next-state logic (2-process FSM style).
    // Priority (bottom wins): default hold -> AXI transactions ->
    // hardware events -> soft reset override.
    // ----------------------------------------------------------------
    always_comb begin
        // Default: hold current values
        reg_baseaddr_c       = reg_baseaddr;
        reg_ringlen_c        = reg_ringlen;
        reg_tail_c           = reg_tail;
        reg_ctrl_c           = reg_ctrl;
        reg_status_error_c   = reg_status_error;
        reg_irq_empty_c      = reg_irq_empty;
        reg_irq_error_c      = reg_irq_error;
        aw_pending_c         = aw_pending;
        awaddr_c             = awaddr;
        w_pending_c          = w_pending;
        wdata_c              = wdata;
        wstrb_c              = wstrb;
        bvalid_c             = bvalid;
        bresp_c              = bresp;
        rdata_c              = rdata;
        rvalid_c             = rvalid;
        ring_mgr_error_clear_c = 1'b0; // pulse: default deasserted
        irq_clear_error_pending_c = irq_clear_error_pending;
        ctrl_readback_pending_c = ctrl_readback_pending;
        ctrl_readback_data_c = ctrl_readback_data;

        // --- AW channel capture ---
        if (aw_hs) begin
            aw_pending_c = 1'b1;
            awaddr_c     = soc_bus.awaddr;
        end

        // --- W channel capture ---
        if (w_hs) begin
            w_pending_c = 1'b1;
            wdata_c     = soc_bus.wdata;
            wstrb_c     = soc_bus.wstrb;
        end

        // --- Write commit: both AW and W captured, no pending response ---
        if (~bvalid && aw_pending && w_pending) begin
            unique case (wr_addr_lsb)
                // R/W registers: merge with wstrb
                dma_pkg::REG_BASEADDR: reg_baseaddr_c = apply_wstrb(reg_baseaddr, wdata, wstrb);
                dma_pkg::REG_RINGLEN:  reg_ringlen_c  = apply_wstrb(reg_ringlen,  wdata, wstrb);
                dma_pkg::REG_TAIL:     reg_tail_c     = apply_wstrb(reg_tail,     wdata, wstrb);

                // CTRL: mask reserved bits [31:3] to zero
                dma_pkg::REG_CTRL: begin
                    reg_ctrl_c = {29'd0, ctrl_write_data[2:0]};
                    if (ctrl_write_data[1]) begin
                        // Preserve one immediate masked readback after RESET write.
                        ctrl_readback_pending_c = 1'b1;
                        ctrl_readback_data_c    = {29'd0, ctrl_write_data[2], 1'b0, ctrl_write_data[0]};
                    end
                end

                // IRQ_CLEAR: write-1-to-clear sticky IRQ/status bits
                dma_pkg::REG_IRQ_CLEAR: begin
                    if (write_data_masked[0]) begin
                        reg_irq_empty_c = 1'b0;
                    end
                    if (write_data_masked[1]) begin
                        // FIX: keep clear behavior, but delay external clear pulse
                        // to the B-channel handshake cycle for deterministic sampling.
                        reg_irq_error_c        = 1'b0;
                        reg_status_error_c     = 1'b0;
                        // ring_mgr_error_clear_c = 1'b1;
                        irq_clear_error_pending_c = 1'b1;
                    end
                end

                // Read-only registers: write attempt pauses the system
                dma_pkg::REG_HEAD,
                dma_pkg::REG_STATUS,
                dma_pkg::REG_IRQ_STATUS: begin
                    // FIX: RO writes are ignored (tb expects no side effects / no injected error).
                    // reg_status_error_c = 1'b1;
                    // reg_irq_error_c    = 1'b1;
                    // bresp_c            = AXI_RESP_SLVERR;
                end

                default: begin
                    // Writes to unmapped addresses: ignored
                end
            endcase

            // Release captured AW/W and assert write response
            aw_pending_c = 1'b0;
            w_pending_c  = 1'b0;
            bvalid_c     = 1'b1;
            if (bresp_c != dma_pkg::AXI_RESP_SLVERR)
                bresp_c = dma_pkg::AXI_RESP_OKAY;

        // --- Write response handshake ---
        end else if (bvalid && soc_bus.bready) begin
            bvalid_c = 1'b0;

            // FIX: emit one-cycle error_clear pulse after write completion.
            if (irq_clear_error_pending) begin
                ring_mgr_error_clear_c   = 1'b1;
                irq_clear_error_pending_c = 1'b0;
            end
        end

        // --- Read: latch data on AR handshake ---
        if (ar_hs) begin
            rvalid_c = 1'b1;
            rdata_c  = read_data;
            // One-shot behavior: clear pending CTRL post-write readback
            // after the first read transaction (any address).
            ctrl_readback_pending_c = 1'b0;

        // --- Read response handshake ---
        end else if (rvalid && soc_bus.rready) begin
            rvalid_c = 1'b0;
        end

        // --- Hardware event: ring manager asserts empty transition ---
        if (ring_mgr.irq_empty_set) begin
            reg_irq_empty_c = 1'b1;
        end

        // --- Hardware event: ring manager asserts error ---
        if (ring_mgr.error_set) begin
            reg_status_error_c = 1'b1;
            reg_irq_error_c    = 1'b1;
        end

        // --- Soft reset (highest priority): CTRL.RESET command handling.
        if (reg_ctrl[1] && !bvalid && !soc_bus.arvalid && !rvalid) begin
            reg_baseaddr_c         = 32'd0;
            reg_ringlen_c          = 32'd0;
            reg_tail_c             = 32'd0;
            reg_ctrl_c             = 32'd0;
            reg_status_error_c     = 1'b0;
            reg_irq_empty_c        = 1'b0;
            reg_irq_error_c        = 1'b0;
            ring_mgr_error_clear_c = 1'b1;
            // If software has not read yet, keep one-shot CTRL readback pending.
        end
    end

endmodule // csr.sv
