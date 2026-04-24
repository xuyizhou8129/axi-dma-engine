// SPI mode-0 slave CSR replacing AXI-Lite CSR.
// 16-bit frames: [15:8] = {rw, addr[6:0]}, [7:0] = data.
// rw=1 → read (MISO), rw=0 → write (committed on CSn rising edge).
//
// Register map (7-bit address):
//   0x00  BASEADDR_LO  [7:0]   r/w  descriptor ring base address bits [7:0]
//   0x01  BASEADDR_HI  [7:0]   r/w  descriptor ring base address bits [15:8]
//   0x02  RINGLEN      [7:0]   r/w  number of descriptors in ring
//   0x03  TAIL         [7:0]   r/w  tail pointer (SW advances to submit descriptors)
//   0x04  CTRL         [2:0]   r/w  [0]=enable [1]=soft_reset [2]=irq_en
//   0x05  HEAD         [7:0]   r/o  head pointer (HW advances on completion)
//   0x06  STATUS       [2:0]   r/o  [0]=busy [1]=ring_empty [2]=error
//   0x07  IRQ          [1:0]   r/o  [0]=irq_empty [1]=irq_error; write W1C

module spi_csr (
    input  logic clk,
    input  logic rst_n,

    // SPI (mode 0: CPOL=0 CPHA=0, MSB first)
    input  logic sclk,
    input  logic mosi,
    output logic miso,
    input  logic csn,

    // Ring manager interface
    csr_ring_manager_if.csr ring_mgr,

    // One-cycle clear pulses consumed by IRQ.sv
    output logic irq_clear_pulse_empty,
    output logic irq_clear_pulse_error
);

    // -------------------------------------------------------------------------
    // 2FF synchronizers
    // -------------------------------------------------------------------------
    logic [1:0] sclk_r, mosi_r, csn_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_r <= 2'b00;
            mosi_r <= 2'b00;
            csn_r  <= 2'b11;
        end else begin
            sclk_r <= {sclk_r[0], sclk};
            mosi_r <= {mosi_r[0], mosi};
            csn_r  <= {csn_r[0],  csn};
        end
    end

    wire sclk_re  = ~sclk_r[1] &  sclk_r[0];
    wire sclk_fe  =  sclk_r[1] & ~sclk_r[0];
    wire csn_rise = ~csn_r[1]  &  csn_r[0];

    // -------------------------------------------------------------------------
    // SPI shift engine
    // -------------------------------------------------------------------------
    logic [3:0] bit_cnt;
    logic [7:0] rx_byte;   // shift-in register (MOSI)
    logic [7:0] tx_byte;   // shift-out register (MISO)
    logic       is_read;
    logic [6:0] reg_addr;
    logic [7:0] rx_data;   // latched MOSI data byte

    // Writable CSR registers
    logic [7:0] reg_baseaddr_lo;
    logic [7:0] reg_baseaddr_hi;
    logic [7:0] reg_ringlen;
    logic [7:0] reg_tail;
    logic [7:0] reg_ctrl;

    // HW-set sticky bits
    logic reg_irq_empty;
    logic reg_irq_error;
    logic reg_status_error;

    // Combinational read mux
    logic [7:0] rd_data;
    always_comb begin
        case (reg_addr)
            dma_pkg::REG_BASEADDR_LO: rd_data = reg_baseaddr_lo;
            dma_pkg::REG_BASEADDR_HI: rd_data = reg_baseaddr_hi;
            dma_pkg::REG_RINGLEN:     rd_data = reg_ringlen;
            dma_pkg::REG_TAIL:        rd_data = reg_tail;
            dma_pkg::REG_CTRL:        rd_data = {5'd0, reg_ctrl[2:0]};
            dma_pkg::REG_HEAD:        rd_data = ring_mgr.head;
            dma_pkg::REG_STATUS:      rd_data = {5'd0, reg_status_error,
                                                       ring_mgr.ring_empty,
                                                       ring_mgr.busy};
            dma_pkg::REG_IRQ:         rd_data = {6'd0, reg_irq_error, reg_irq_empty};
            default:                  rd_data = 8'hFF;
        endcase
    end

    // SPI bit counter, shift registers, address/data capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt  <= '0;
            rx_byte  <= '0;
            tx_byte  <= '0;
            is_read  <= '0;
            reg_addr <= '0;
            rx_data  <= '0;
        end else begin
            if (csn_r[1]) begin
                bit_cnt <= '0;
            end else begin
                if (sclk_re) begin
                    rx_byte <= {rx_byte[6:0], mosi_r[1]};
                    bit_cnt <= bit_cnt + 1'b1;
                    // 8th rising edge: address byte complete
                    if (bit_cnt == 4'd7) begin
                        is_read  <= rx_byte[6];
                        reg_addr <= {rx_byte[5:0], mosi_r[1]};
                    end
                    // 16th rising edge: data byte complete
                    if (bit_cnt == 4'd15)
                        rx_data <= {rx_byte[6:0], mosi_r[1]};
                end
                // Load MISO on falling edge after address byte received
                if (sclk_fe && bit_cnt == 4'd8)
                    tx_byte <= rd_data;
                else if (sclk_fe && bit_cnt > 4'd8)
                    tx_byte <= {tx_byte[6:0], 1'b0};
            end
        end
    end

    assign miso = tx_byte[7];

    // -------------------------------------------------------------------------
    // CSR register file + HW event latching
    // -------------------------------------------------------------------------
    wire do_write    = csn_rise && !is_read;
    wire write_irq   = do_write && (reg_addr == dma_pkg::REG_IRQ);

    assign irq_clear_pulse_empty = write_irq && rx_data[0];
    assign irq_clear_pulse_error = write_irq && rx_data[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_baseaddr_lo  <= '0;
            reg_baseaddr_hi  <= '0;
            reg_ringlen      <= '0;
            reg_tail         <= '0;
            reg_ctrl         <= '0;
            reg_irq_empty    <= '0;
            reg_irq_error    <= '0;
            reg_status_error <= '0;
        end else begin
            // HW events (set sticky bits)
            if (ring_mgr.irq_empty_set) reg_irq_empty   <= 1'b1;
            if (ring_mgr.error_set) begin
                reg_irq_error    <= 1'b1;
                reg_status_error <= 1'b1;
            end

            // SPI write commit
            if (do_write) begin
                case (reg_addr)
                    dma_pkg::REG_BASEADDR_LO: reg_baseaddr_lo <= rx_data;
                    dma_pkg::REG_BASEADDR_HI: reg_baseaddr_hi <= rx_data;
                    dma_pkg::REG_RINGLEN:     reg_ringlen     <= rx_data;
                    dma_pkg::REG_TAIL:        reg_tail        <= rx_data;
                    dma_pkg::REG_CTRL:        reg_ctrl        <= {5'd0, rx_data[2:0]};
                    dma_pkg::REG_IRQ: begin
                        if (rx_data[0]) reg_irq_empty   <= 1'b0;
                        if (rx_data[1]) begin
                            reg_irq_error    <= 1'b0;
                            reg_status_error <= 1'b0;
                        end
                    end
                    default: ;
                endcase
            end

            // Soft reset (CTRL[1]) clears all config and status
            if (reg_ctrl[1]) begin
                reg_baseaddr_lo  <= '0;
                reg_baseaddr_hi  <= '0;
                reg_ringlen      <= '0;
                reg_tail         <= '0;
                reg_ctrl         <= '0;
                reg_irq_empty    <= '0;
                reg_irq_error    <= '0;
                reg_status_error <= '0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Ring manager outputs
    // -------------------------------------------------------------------------
    assign ring_mgr.baseaddr    = {reg_baseaddr_hi, reg_baseaddr_lo};
    assign ring_mgr.ringlen     = reg_ringlen;
    assign ring_mgr.tail        = reg_tail;
    assign ring_mgr.enable      = reg_ctrl[0];
    assign ring_mgr.reset       = reg_ctrl[1];
    assign ring_mgr.irq_en      = reg_ctrl[2];
    assign ring_mgr.error_clear = write_irq && rx_data[1];

endmodule
