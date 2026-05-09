#include "xparameters.h"
#include "xuartlite_l.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "protocol.h"

#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR

/* mem_access_ctrl shim accessors (see firmware/call_back.c). The shim
 * arbitrates MicroBlaze access to SRAM and system memory: write the byte
 * offset to REG_INIT_ADDR, the data to REG_INIT_DATA, then pulse the
 * SRAM_WR / MEM_WR strobe. Reads pulse SRAM_RD / MEM_RD and consume
 * REG_RDATA. REG_INIT_DONE=1 hands memory ownership over to the DMA. */
#define REG_WRITE(offset, val) Xil_Out32(MEM_ACCESS_CTRL_BASE + (offset), (val))
#define REG_READ(offset)       Xil_In32(MEM_ACCESS_CTRL_BASE + (offset))

static void sysmem_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_MEM_WR,    1);
}

static u32 sysmem_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_MEM_RD,    1);
    return REG_READ(REG_RDATA);
}

static void sram_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_SRAM_WR,   1);
}

static u32 sram_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_SRAM_RD,   1);
    return REG_READ(REG_RDATA);
}

/* CRC32-IEEE (zlib-compatible): poly 0xEDB88320 (reflected), init 0xFFFFFFFF,
 * final XOR 0xFFFFFFFF. Matches Python zlib.crc32(...) when bytes are fed in
 * the same order. */
static u32 crc32_table[256];

static void crc32_init_table(void) {
    for (u32 i = 0; i < 256; i++) {
        u32 c = i;
        for (int j = 0; j < 8; j++) {
            c = (c & 1u) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        }
        crc32_table[i] = c;
    }
}

/* Update CRC with one 32-bit word, processed LE byte-first (matches host's
 * struct.pack("<%dI", ...) packing of words to bytes). */
static u32 crc32_word_le(u32 crc, u32 word) {
    u8 b;
    b = (u8)( word        & 0xFF); crc = crc32_table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    b = (u8)((word >>  8) & 0xFF); crc = crc32_table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    b = (u8)((word >> 16) & 0xFF); crc = crc32_table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    b = (u8)((word >> 24) & 0xFF); crc = crc32_table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    return crc;
}

static u32 crc32_sram_range(u32 start_byte_addr, u32 byte_length) {
    u32 crc = 0xFFFFFFFFu;
    u32 word_count = byte_length / 4;
    for (u32 w = 0; w < word_count; w++) {
        crc = crc32_word_le(crc, sram_read(start_byte_addr + w * 4));
    }
    return crc ^ 0xFFFFFFFFu;
}

static u32 crc32_sysmem_range(u32 start_byte_addr, u32 byte_length) {
    u32 crc = 0xFFFFFFFFu;
    u32 word_count = byte_length / 4;
    for (u32 w = 0; w < word_count; w++) {
        crc = crc32_word_le(crc, sysmem_read(start_byte_addr + w * 4));
    }
    return crc ^ 0xFFFFFFFFu;
}

typedef enum {
    STATE_WAIT_SYNC,
    STATE_READ_HEADER,
    STATE_READ_PAYLOAD,
    STATE_PROCESS
} ParserState;

u8 uart_read_byte(void) {
    while (XUartLite_IsReceiveEmpty(UART_BASEADDR));
    return XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
}

void uart_write_byte(u8 data) {
    while (XUartLite_IsTransmitFull(UART_BASEADDR));
    XUartLite_WriteReg(UART_BASEADDR, XUL_TX_FIFO_OFFSET, data);
}

u32 uart_read_u32_le(void) {
    u32 v  = (u32)uart_read_byte();
    v     |= (u32)uart_read_byte() << 8;
    v     |= (u32)uart_read_byte() << 16;
    v     |= (u32)uart_read_byte() << 24;
    return v;
}

void uart_write_u32(u32 data) {
    uart_write_byte((u8)(data         & 0xFF));
    uart_write_byte((u8)((data >>  8) & 0xFF));
    uart_write_byte((u8)((data >> 16) & 0xFF));
    uart_write_byte((u8)((data >> 24) & 0xFF));
}

void send_ack(u8 ack_type) {
    uart_write_u32(PACKET_SYNC_WORD);
    uart_write_byte(ack_type);
}

int main(void) {
    crc32_init_table();
    xil_printf("MicroBlaze DMA Validation Firmware Ready.\r\n");

    ParserState state = STATE_WAIT_SYNC;
    u32 sync_buffer  = 0;

    u8  opcode      = 0;
    u32 dest_addr   = 0;
    u32 payload_len = 0;
    u32 payload_word = 0;
    u8  payload_buf[1024];

    while (1) {
        switch (state) {

            case STATE_WAIT_SYNC: {
                u8 b = uart_read_byte();
                sync_buffer = (sync_buffer >> 8) | ((u32)b << 24);
                if (sync_buffer == PACKET_SYNC_WORD)
                    state = STATE_READ_HEADER;
                break;
            }

            case STATE_READ_HEADER:
                opcode       = uart_read_byte();
                dest_addr    = uart_read_u32_le();
                payload_len  = uart_read_u32_le();
                payload_word = 0;
                state = (payload_len > 0) ? STATE_READ_PAYLOAD : STATE_PROCESS;
                break;

            case STATE_READ_PAYLOAD:
                for (u32 i = 0; i < payload_len; i++) {
                    u8 b = uart_read_byte();
                    if (i < sizeof(payload_buf))
                        payload_buf[i] = b;
                    if (i < 4)
                        payload_word |= ((u32)b) << (8 * i);
                }
                state = STATE_PROCESS;
                break;

            case STATE_PROCESS:
                switch (opcode) {

                    case CMD_WRITE_SRAM:
                        if (payload_len >= 4) {
                            sram_write(dest_addr, payload_word);
                            xil_printf("Wrote 0x%08x to SRAM[0x%08x]\r\n", payload_word, dest_addr);
                            send_ack(CMD_ACK);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;

                    case CMD_WRITE_SYSMEM:
                        if (payload_len >= 4) {
                            sysmem_write(dest_addr, payload_word);
                            xil_printf("Wrote 0x%08x to SYSMEM[0x%08x]\r\n", payload_word, dest_addr);
                            send_ack(CMD_ACK);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;

                    /* CSR is direct AXI-Lite at CSR_ACCESS_BASE; host sends the
                     * absolute address (csr_base + offset) in dest_addr. */
                    case CMD_WRITE_CSR:
                        if (payload_len >= 4) {
                            Xil_Out32(dest_addr, payload_word);
                            xil_printf("Wrote 0x%08x to CSR[0x%08x]\r\n", payload_word, dest_addr);
                            send_ack(CMD_ACK);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;

                    case CMD_RUN_DMA: {
                        /* Reset DMA state so HEAD returns to 0 regardless of previous runs. */
                        Xil_Out32(CSR_ACCESS_BASE + CSR_REG_CTRL, CTRL_RESET);
                        for (volatile u32 d = 0; d < 100; d++);
                        Xil_Out32(CSR_ACCESS_BASE + CSR_REG_CTRL, 0);
                        Xil_Out32(CSR_ACCESS_BASE + CSR_REG_IRQ_CLEAR, 0x3);

                        u32 head_pre = Xil_In32(CSR_ACCESS_BASE + CSR_REG_HEAD);
                        u32 tail_pre = Xil_In32(CSR_ACCESS_BASE + CSR_REG_TAIL);
                        xil_printf("Triggering DMA... HEAD=%d TAIL=%d\r\n", head_pre, tail_pre);

                        if (tail_pre == 0) {
                            xil_printf("DMA ring empty (TAIL=0), nothing to do.\r\n");
                            send_ack(CMD_NACK);
                            break;
                        }

                        /* Hand memory ownership over to the DMA. */
                        REG_WRITE(REG_INIT_DONE, 1);

                        /* Set ENABLE while preserving other CTRL bits (e.g. IRQ_EN). */
                        u32 ctrl = Xil_In32(CSR_ACCESS_BASE + CSR_REG_CTRL);
                        Xil_Out32(CSR_ACCESS_BASE + CSR_REG_CTRL, ctrl | CTRL_ENABLE);

                        /* Wait for DMA to go BUSY before polling for done.
                         * Without this, a stale EMPTY flag causes a false-done. */
                        u32 status = 0;
                        for (u32 j = 0; j < 10000; j++) {
                            status = Xil_In32(CSR_ACCESS_BASE + CSR_REG_STATUS);
                            if ((status & STATUS_BUSY) || (status & STATUS_ERROR)) break;
                        }

                        /* Done = ring empty AND not busy. Bail on error or timeout. */
                        u32 i;
                        for (i = 0; i < 10000000; i++) {
                            status = Xil_In32(CSR_ACCESS_BASE + CSR_REG_STATUS);
                            if (status & STATUS_ERROR) break;
                            if ((status & STATUS_EMPTY) && !(status & STATUS_BUSY)) break;
                        }

                        /* Return memory ownership to the MicroBlaze shim. */
                        REG_WRITE(REG_INIT_DONE, 0);

                        if ((status & STATUS_ERROR) || i >= 10000000) {
                            xil_printf("DMA failed: status=0x%08x\r\n", status);
                            send_ack(CMD_NACK);
                        } else {
                            xil_printf("DMA done: status=0x%08x\r\n", status);
                            send_ack(CMD_ACK);
                        }
                        break;
                    }

                    case CMD_READ_SRAM: {
                        u32 val = sram_read(dest_addr);
                        xil_printf("Read 0x%08x from SRAM[0x%08x]\r\n", val, dest_addr);
                        send_ack(CMD_ACK);
                        uart_write_u32(val);
                        break;
                    }

                    case CMD_READ_SYSMEM: {
                        u32 val = sysmem_read(dest_addr);
                        xil_printf("Read 0x%08x from SYSMEM[0x%08x]\r\n", val, dest_addr);
                        send_ack(CMD_ACK);
                        uart_write_u32(val);
                        break;
                    }

                    /* CRC32 over [dest_addr, dest_addr + payload_word) words.
                     * Returns ACK frame followed by 4-byte LE CRC. */
                    case CMD_CRC_SRAM: {
                        if (payload_len >= 4) {
                            u32 byte_len = payload_word;
                            u32 crc = crc32_sram_range(dest_addr, byte_len);
                            xil_printf("CRC SRAM[0x%08x..+0x%x] = 0x%08x\r\n",
                                       dest_addr, byte_len, crc);
                            send_ack(CMD_ACK);
                            uart_write_u32(crc);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;
                    }

                    case CMD_CRC_SYSMEM: {
                        if (payload_len >= 4) {
                            u32 byte_len = payload_word;
                            u32 crc = crc32_sysmem_range(dest_addr, byte_len);
                            xil_printf("CRC SYSMEM[0x%08x..+0x%x] = 0x%08x\r\n",
                                       dest_addr, byte_len, crc);
                            send_ack(CMD_ACK);
                            uart_write_u32(crc);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;
                    }

                    case CMD_READ_CSR: {
                        u32 val = Xil_In32(dest_addr);
                        xil_printf("Read CSR[0x%08x] = 0x%08x\r\n", dest_addr, val);
                        send_ack(CMD_ACK);
                        uart_write_u32(val);
                        break;
                    }

                    default:
                        send_ack(CMD_NACK);
                        break;
                }

                sync_buffer = 0;
                state       = STATE_WAIT_SYNC;
                break;
        }
    }

    return 0;
}
