// Detailed work flow:
// IF DF_IN_FIFO is not empty:
// 1. Take 1 handle struct from the FIFO
// 2. Decode the handle struct into AXI4 channel language and send to interface,
// the direction of transaction is always reading from the memory
// 3. Detect call back from the interface, grab the data and put it into DF_OUT_FIFO
// ELSE IF DM_IN_FIFO is not empty: (because Descriptor Fetch has pritority)
// 1. Take 1 instruction struct from the FIFO
// If the instruction is a read instruction:
// 1.1 Decode the instruction into AXI4 channel language and send to interface
// 1.2 Detect call back from the interface, grab the data and put it into MID_FIFO
// If the instruction is a write instruction:
// 1.1 Keep checking the MID_FIFO, if it is not empty, then send the data to the interface
//
// NOTES: DM bursts enter s_wait_sram until sram_done is high (SRAM controller finished).
// Descriptor fetch bursts return directly to idle after pushing descriptor payload.
module axi_4_master #(
    parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
    parameter int LEN_WIDTH  = dma_pkg::LEN_WIDTH,
    parameter int DESC_WORDS = dma_pkg::DESC_WORDS,
    parameter int HANDLE_WIDTH = dma_pkg::HANDLE_WIDTH,
    parameter int INSTR_WIDTH  = dma_pkg::INSTR_WIDTH,
    parameter int DESC_WIDTH   = (DESC_WORDS * DATA_WIDTH)
)(
    input  logic clock,
    input  logic reset,

    // Descriptor Fetcher input FIFO (handle)
    output logic                    df_in_rd_en,
    input  logic                    df_in_empty,
    input  logic [HANDLE_WIDTH-1:0] df_in_dout,

    // Descriptor Fetcher callback FIFO (descriptor payload)
    output logic                    df_out_wr_en,
    input  logic                    df_out_full,
    output logic [DESC_WIDTH-1:0]   df_out_din,

    // Data Mover instruction FIFO
    output logic                    dm_in_rd_en,
    input  logic                    dm_in_empty,
    input  logic [INSTR_WIDTH-1:0]  dm_in_dout,

    // Mid FIFO between AXI read path and SRAM-side path
    output logic                    mid_wr_en,
    input  logic                    mid_full,
    output logic [DATA_WIDTH-1:0]   mid_din,
    output logic                    mid_rd_en,
    input  logic                    mid_empty,
    input  logic [DATA_WIDTH-1:0]   mid_dout,

    // High when SRAM controller has finished internal work for the last transaction
    input  logic sram_done,

    // Asserted when the AXI master has finished the AXI-side portion of the current transaction
    output logic axi_done,

    // AXI4 master interface to system memory
    axi_4_if.master axi
);

    localparam int RW_BIT  = dma_pkg::instr_rw_bit(INSTR_WIDTH);
    localparam int LEN_MSB = dma_pkg::instr_len_msb(LEN_WIDTH);
    localparam int LEN_LSB = dma_pkg::INSTR_LEN_LSB;

    typedef enum logic [3:0] {
        s_idle,
        s_df_get,
        s_df_ar,
        s_df_r,
        s_df_push,
        s_dm_get,
        s_dm_rd_ar,
        s_dm_rd_r,
        s_dm_wr_aw,
        s_dm_wr_w,
        s_dm_wr_b,
        s_wait_sram
    } state_types;

    state_types state, state_c;

    logic [ADDR_WIDTH-1:0] cur_addr, cur_addr_c;
    logic [LEN_WIDTH-1:0]  cur_len, cur_len_c;
    logic                  cur_write, cur_write_c;
    logic [LEN_WIDTH-1:0]  beat_idx, beat_idx_c;
    logic [DESC_WIDTH-1:0] desc_buf, desc_buf_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset == 1'b1) begin
            state      <= s_idle;
            cur_addr   <= '0;
            cur_len    <= '0;
            cur_write  <= 1'b0;
            beat_idx   <= '0;
            desc_buf   <= '0;
        end else begin
            state      <= state_c;
            cur_addr   <= cur_addr_c;
            cur_len    <= cur_len_c;
            cur_write  <= cur_write_c;
            beat_idx   <= beat_idx_c;
            desc_buf   <= desc_buf_c;
        end
    end

    always_comb begin
        df_in_rd_en  = 1'b0;
        df_out_wr_en = 1'b0;
        df_out_din   = desc_buf;
        dm_in_rd_en  = 1'b0;
        mid_wr_en    = 1'b0;
        mid_din      = '0;
        mid_rd_en    = 1'b0;
        axi_done     = 1'b0;

        axi.awvalid  = 1'b0;
        axi.awaddr   = cur_addr;
        axi.awlen    = (cur_len == '0) ? '0 : (cur_len - 1'b1);
        axi.wvalid   = 1'b0;
        axi.wdata    = mid_dout;
        axi.wlast    = 1'b0;
        axi.bready   = 1'b0;
        axi.arvalid  = 1'b0;
        axi.araddr   = cur_addr;
        axi.arlen    = (cur_len == '0) ? '0 : (cur_len - 1'b1);
        axi.rready   = 1'b0;

        state_c      = state;
        cur_addr_c   = cur_addr;
        cur_len_c    = cur_len;
        cur_write_c  = cur_write;
        beat_idx_c   = beat_idx;
        desc_buf_c   = desc_buf;

        case (state)
            s_idle: begin
                if (df_in_empty == 1'b0) begin
                    state_c = s_df_get;
                end else if (dm_in_empty == 1'b0) begin
                    state_c = s_dm_get;
                end
            end

            s_df_get: begin
                df_in_rd_en = 1'b1;
                cur_addr_c  = df_in_dout[31:0];
                cur_len_c   = df_in_dout[LEN_MSB:LEN_LSB];
                beat_idx_c  = '0;
                desc_buf_c  = '0;
                state_c     = s_df_ar;
            end

            s_df_ar: begin
                axi.arvalid = 1'b1;
                if (axi.arvalid && axi.arready) begin
                    state_c = s_df_r;
                end
            end

            s_df_r: begin
                axi.rready = 1'b1;
                if (axi.rvalid && axi.rready) begin
                    desc_buf_c[$unsigned(beat_idx)*DATA_WIDTH +: DATA_WIDTH] = axi.rdata;
                    beat_idx_c = beat_idx + 1'b1;
                    if (axi.rlast == 1'b1) begin
                        state_c = s_df_push;
                    end
                end
            end

            s_df_push: begin
                if (df_out_full == 1'b0) begin
                    df_out_wr_en = 1'b1;
                    df_out_din   = desc_buf;
                    state_c      = s_idle;
                end
            end

            s_dm_get: begin
                dm_in_rd_en  = 1'b1;
                cur_addr_c   = dm_in_dout[31:0];
                cur_len_c    = dm_in_dout[LEN_MSB:LEN_LSB];
                cur_write_c  = dm_in_dout[RW_BIT];
                beat_idx_c   = '0;
                if (dm_in_dout[RW_BIT] == 1'b1) begin
                    state_c = s_dm_wr_aw;
                end else begin
                    state_c = s_dm_rd_ar;
                end
            end

            s_dm_rd_ar: begin
                axi.arvalid = 1'b1;
                if (axi.arvalid && axi.arready) begin
                    state_c = s_dm_rd_r;
                end
            end

            s_dm_rd_r: begin
                axi.rready = (mid_full == 1'b0);
                if (axi.rvalid && axi.rready) begin
                    mid_din   = axi.rdata;
                    mid_wr_en = 1'b1;
                    if (axi.rlast == 1'b1) begin
                        state_c = s_wait_sram;
                    end
                end
            end

            s_dm_wr_aw: begin
                axi.awvalid = 1'b1;
                if (axi.awvalid && axi.awready) begin
                    beat_idx_c = '0;
                    state_c = s_dm_wr_w;
                end
            end

            s_dm_wr_w: begin
                if (mid_empty == 1'b0) begin
                    axi.wvalid = 1'b1;
                    axi.wdata  = mid_dout;
                    axi.wlast  = (beat_idx == (cur_len - 1'b1));
                    if (axi.wvalid && axi.wready) begin
                        mid_rd_en = 1'b1;
                        beat_idx_c = beat_idx + 1'b1;
                        if (axi.wlast == 1'b1) begin
                            state_c = s_dm_wr_b;
                        end
                    end
                end
            end

            s_dm_wr_b: begin
                axi.bready = 1'b1;
                if (axi.bvalid && axi.bready) begin
                    state_c = s_wait_sram;
                end
            end

            s_wait_sram: begin
                axi_done = 1'b1;
                if (sram_done == 1'b1) begin
                    state_c = s_idle;
                end
            end

            default: begin
                state_c = s_idle;
            end
        endcase
    end

endmodule