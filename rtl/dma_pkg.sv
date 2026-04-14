// Shared constants and small helpers for the DMA RTL. Compile this file before other rtl/*.sv.
package dma_pkg;

    // -------------------------------------------------------------------------
    // Data-path widths (AXI descriptor / data mover / AXI master)
    // -------------------------------------------------------------------------
    parameter int ADDR_WIDTH    = 32;
    parameter int DATA_WIDTH    = 32;
    parameter int LEN_WIDTH     = 8;
    parameter int DESC_WORDS    = 4;
    parameter int HANDLE_WIDTH  = 40;  // [31:0] addr, [39:32] len (beats)
    parameter int INSTR_WIDTH = 41;  // [31:0] addr, [39:32] len, [40] rw

    // -------------------------------------------------------------------------
    // Ring manager (descriptor ring in host memory)
    // -------------------------------------------------------------------------
    parameter int DESCRIPTOR_SIZE_BYTES = 16;
    parameter int MAX_INFLIGHT          = 4;
    parameter int RING_INDEX_WIDTH      = 3;  // index width when ring is 3-bit (tail/len slices)

    // -------------------------------------------------------------------------
    // Descriptor fetch (SRAM address space check)
    // -------------------------------------------------------------------------
    parameter int MAX_SRAM_ADDR = 2 ** 16 - 1;  // 64 KiB words (legacy bound in descriptor_fetcher)

    // -------------------------------------------------------------------------
    // Default FIFO depths and BRAM (movement_top / bram defaults)
    // -------------------------------------------------------------------------
    parameter int DF_IN_FIFO_Q  = 64;
    parameter int DF_OUT_FIFO_Q = 64;
    parameter int DM_FIFO_Q     = 16;
    parameter int MID_FIFO_Q      = 64;
    parameter int BRAM_SIZE       = 1024;

    // -------------------------------------------------------------------------
    // AXI-Lite CSR (dma csr.sv)
    // -------------------------------------------------------------------------
    parameter int AXIL_ADDR_WIDTH = 32;
    parameter int AXIL_DATA_WIDTH = 32;

    // Byte offsets, 32-bit aligned
    parameter logic [7:0] REG_BASEADDR   = 8'h00;
    parameter logic [7:0] REG_RINGLEN    = 8'h04;
    parameter logic [7:0] REG_HEAD       = 8'h08;
    parameter logic [7:0] REG_TAIL       = 8'h0C;
    parameter logic [7:0] REG_CTRL       = 8'h10;
    parameter logic [7:0] REG_STATUS     = 8'h14;
    parameter logic [7:0] REG_IRQ_STATUS = 8'h18;
    parameter logic [7:0] REG_IRQ_CLEAR  = 8'h2C;

    parameter logic [1:0] AXI_RESP_OKAY   = 2'b00;
    parameter logic [1:0] AXI_RESP_SLVERR = 2'b10;

    // -------------------------------------------------------------------------
    // Instruction bit layout (matches descriptor_fetcher / axi_4_master)
    // ADDR_WIDTH fixed at 32 in handle/instruction packing.
    // -------------------------------------------------------------------------
    parameter int INSTR_LEN_LSB = 32;

    function automatic int unsigned instr_rw_bit(int unsigned instr_w);
        return instr_w - 1;
    endfunction

    function automatic int unsigned instr_len_msb(int unsigned len_w);
        return 32 + len_w - 1;
    endfunction

endpackage
