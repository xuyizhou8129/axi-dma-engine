#include "xparameters.h"
#include "xuartlite_l.h"
#include "xil_io.h"
#include "protocol.h"

#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR

typedef enum {
    STATE_WAIT_SYNC,
    STATE_READ_HEADER,
    STATE_READ_PAYLOAD,
    STATE_PROCESS
} ParserState;

/* Blocking 1-byte UART read (polling) */
u8 uart_read_byte(void) {
    while (XUartLite_IsReceiveEmpty(UART_BASEADDR));
    return XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
}

/* Blocking 1-byte UART write */
void uart_write_byte(u8 data) {
    while (XUartLite_IsTransmitFull(UART_BASEADDR));
    XUartLite_WriteReg(UART_BASEADDR, XUL_TX_FIFO_OFFSET, data);
}

/* Read a 32-bit little-endian word from UART (LSB first on the wire) */
u32 uart_read_u32_le(void) {
    u32 v  = (u32)uart_read_byte();
    v     |= (u32)uart_read_byte() << 8;
    v     |= (u32)uart_read_byte() << 16;
    v     |= (u32)uart_read_byte() << 24;
    return v;
}

/* Write a 32-bit little-endian word to UART (LSB first on the wire) */
void uart_write_u32(u32 data) {
    uart_write_byte((u8)(data        & 0xFF));
    uart_write_byte((u8)((data >> 8)  & 0xFF));
    uart_write_byte((u8)((data >> 16) & 0xFF));
    uart_write_byte((u8)((data >> 24) & 0xFF));
}

void send_ack(u8 ack_type) {
    uart_write_u32(PACKET_SYNC_WORD);
    uart_write_byte(ack_type);
}

int main(void) {
    ParserState state = STATE_WAIT_SYNC;
<<<<<<< HEAD
    u32 sync_buffer = 0;
    
    u8  opcode = 0;
    u32 dest_addr = 0;
    u32 payload_len = 0;
    u8  payload_buf[1024];

#define REG_WRITE(offset, val) Xil_Out32(MEM_ACCESS_CTRL_BASE + (offset), (val))
#define REG_READ(offset)       Xil_In32(MEM_ACCESS_CTRL_BASE + (offset))
=======
    u32 sync_buffer  = 0;
    u8  opcode       = 0;
    u32 dest_addr    = 0;
    u32 payload_len  = 0;
    u32 payload_word = 0;   /* first 4 payload bytes assembled LE */
>>>>>>> 76c35e0b14a19b51598ce22c78f9ff98337c1626

    while (1) {
        switch (state) {

            case STATE_WAIT_SYNC: {
                u8 b = uart_read_byte();
                sync_buffer = (sync_buffer >> 8) | ((u32)b << 24);
                if (sync_buffer == PACKET_SYNC_WORD) {
                    state = STATE_READ_HEADER;
                }
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
                    if (i < 4) {
                        payload_word |= ((u32)b) << (8 * i);
                    }
                }
                state = STATE_PROCESS;
                break;

            case STATE_PROCESS:
                switch (opcode) {

                    /* All three writes collapse to the same MMIO. The host's
                     * dest_addr already lands in the correct AXI region —
                     * the opcode split is informational only. */
                    case CMD_WRITE_SRAM:
                    case CMD_WRITE_SYSMEM:
                    case CMD_WRITE_CSR:
                        if (payload_len >= 4) {
                            Xil_Out32(dest_addr, payload_word);
                            send_ack(CMD_ACK);
                        } else {
                            send_ack(CMD_NACK);
                        }
                        break;

                    /* HW handles the run; ack immediately. */
                    case CMD_RUN_DMA:
                        send_ack(CMD_ACK);
                        break;

                    /* Single-word readback at the given AXI address. */
                    case CMD_READ_SRAM:
                    case CMD_READ_SYSMEM: {
                        u32 val = Xil_In32(dest_addr);
                        send_ack(CMD_ACK);
                        uart_write_u32(val);
                        break;
                    }
<<<<<<< HEAD
                    xil_printf("Wrote CSR 0x%08x\r\n", dest_addr);
                    send_ack(CMD_ACK);
                } 
                else if (opcode == CMD_RUN_DMA) {
                    xil_printf("Triggering DMA...\r\n");

                    // Set enable bit, preserving other CTRL bits (e.g. irq_en)
                    u32 ctrl = Xil_In32(CSR_ACCESS_BASE + CSR_REG_CTRL);
                    Xil_Out32(CSR_ACCESS_BASE + CSR_REG_CTRL, ctrl | CTRL_ENABLE);

                    // Poll STATUS until not busy or error, with timeout (~100ms at 100MHz)
                    u32 status = 0;
                    u32 i;
                    for (i = 0; i < 10000000; i++) {
                        status = Xil_In32(CSR_ACCESS_BASE + CSR_REG_STATUS);
                        if (!(status & STATUS_BUSY) || (status & STATUS_ERROR))
                            break;
                    }

                    if ((status & STATUS_ERROR) || i >= 10000000) {
                        xil_printf("DMA failed: status=0x%08x\r\n", status);
                        send_ack(CMD_NACK);
                    } else {
                        xil_printf("DMA done: status=0x%08x\r\n", status);
                        send_ack(CMD_ACK);
                    }
=======

                    /* TODO: CSR / range readback + CRC32. NACK for now so
                     * the host fails loudly rather than silently. */
                    case CMD_REQ_RESULTS:
                    default:
                        send_ack(CMD_NACK);
                        break;
>>>>>>> 76c35e0b14a19b51598ce22c78f9ff98337c1626
                }

                sync_buffer = 0;
                state       = STATE_WAIT_SYNC;
                break;
        }
    }

    return 0;
}
