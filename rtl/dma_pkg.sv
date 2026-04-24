package dma_pkg;

    // -------------------------------------------------------------------------
    // Data-path widths
    // -------------------------------------------------------------------------
    parameter int ADDR_WIDTH   = 16;
    parameter int DATA_WIDTH   = 16;
    parameter int LEN_WIDTH    = 8;
    parameter int DESC_WORDS   = 4;

    // Derived widths (depend on ADDR_WIDTH / LEN_WIDTH — must follow them)
    parameter int HANDLE_WIDTH = ADDR_WIDTH + LEN_WIDTH;      // 24
    parameter int INSTR_WIDTH  = ADDR_WIDTH + LEN_WIDTH + 1;  // 25

    // -------------------------------------------------------------------------
    // Ring manager
    // -------------------------------------------------------------------------
    parameter int DESCRIPTOR_SIZE_BYTES = DESC_WORDS * (DATA_WIDTH / 8);  // 8
    parameter int MAX_INFLIGHT          = 1;

    // -------------------------------------------------------------------------
    // FIFO depths
    // -------------------------------------------------------------------------
    parameter int DF_IN_FIFO_Q  = 4;
    parameter int DF_OUT_FIFO_Q = 4;
    parameter int DM_FIFO_Q     = 4;

    // -------------------------------------------------------------------------
    // SPI CSR register byte addresses (7-bit)
    // -------------------------------------------------------------------------
    parameter logic [6:0] REG_BASEADDR_LO = 7'h00;  // r/w  base address [7:0]
    parameter logic [6:0] REG_BASEADDR_HI = 7'h01;  // r/w  base address [15:8]
    parameter logic [6:0] REG_RINGLEN     = 7'h02;  // r/w  ring length (# descriptors)
    parameter logic [6:0] REG_TAIL        = 7'h03;  // r/w  tail pointer (SW advances)
    parameter logic [6:0] REG_CTRL        = 7'h04;  // r/w  [0]=enable [1]=reset [2]=irq_en
    parameter logic [6:0] REG_HEAD        = 7'h05;  // r/o  head pointer (HW advances)
    parameter logic [6:0] REG_STATUS      = 7'h06;  // r/o  [0]=busy [1]=ring_empty [2]=error
    parameter logic [6:0] REG_IRQ         = 7'h07;  // r/o status; w=W1C clear

    parameter logic [1:0] AXI_RESP_OKAY   = 2'b00;
    parameter logic [1:0] AXI_RESP_SLVERR = 2'b10;

    // -------------------------------------------------------------------------
    // Instruction bit layout (replaces the old instr_rw_bit / instr_len_msb functions)
    // -------------------------------------------------------------------------
    parameter int INSTR_LEN_LSB = ADDR_WIDTH;                      // 16
    parameter int INSTR_LEN_MSB = ADDR_WIDTH + LEN_WIDTH - 1;     // 23
    parameter int INSTR_RW_BIT  = INSTR_WIDTH - 1;                // 24

endpackage
