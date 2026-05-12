#include "xparameters.h"
#include "xuartlite_l.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "protocol.h"

#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR

// State machine for UART parsing
typedef enum {
    STATE_WAIT_SYNC,
    STATE_READ_HEADER,
    STATE_READ_PAYLOAD,
    STATE_PROCESS
} ParserState;

// Simple blocking read for 1 byte over UART (Polling)
u8 uart_read_byte() {
    while (XUartLite_IsReceiveEmpty(UART_BASEADDR));
    return XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
}

// Simple blocking write for 1 byte over UART
void uart_write_byte(u8 data) {
    while (XUartLite_IsTransmitFull(UART_BASEADDR));
    XUartLite_WriteReg(UART_BASEADDR, XUL_TX_FIFO_OFFSET, data);
}

// Write a 32-bit word (Little Endian over the wire)
void uart_write_u32(u32 data) {
    uart_write_byte((u8)(data & 0xFF));
    uart_write_byte((u8)((data >> 8) & 0xFF));
    uart_write_byte((u8)((data >> 16) & 0xFF));
    uart_write_byte((u8)((data >> 24) & 0xFF));
}

void send_ack(u8 ack_type) {
    uart_write_u32(PACKET_SYNC_WORD);
    uart_write_byte(ack_type);
}

int main() {
    xil_printf("MicroBlaze DMA Validation Firmware Ready.\r\n");

    ParserState state = STATE_WAIT_SYNC;
    u32 sync_buffer = 0;
    
    u8  opcode = 0;
    u32 dest_addr = 0;
    u32 payload_len = 0;
    
    // We'll read the payload directly to memory, but for CSRs it's small.
    // For large SRAM blocks, payload_len can be large, so we will stream it directly.

    while (1) {
        switch (state) {
            case STATE_WAIT_SYNC:
                sync_buffer = (sync_buffer >> 8) | ((u32)uart_read_byte() << 24);
                if (sync_buffer == PACKET_SYNC_WORD) {
                    state = STATE_READ_HEADER;
                }
                break;

            case STATE_READ_HEADER:
                opcode = uart_read_byte();
                
                dest_addr = uart_read_byte();
                dest_addr |= ((u32)uart_read_byte() << 8);
                dest_addr |= ((u32)uart_read_byte() << 16);
                dest_addr |= ((u32)uart_read_byte() << 24);
                
                payload_len = uart_read_byte();
                payload_len |= ((u32)uart_read_byte() << 8);
                payload_len |= ((u32)uart_read_byte() << 16);
                payload_len |= ((u32)uart_read_byte() << 24);
                
                if (payload_len > 0) {
                    state = STATE_READ_PAYLOAD;
                } else {
                    state = STATE_PROCESS;
                }
                break;

            case STATE_READ_PAYLOAD:
                // Stream the payload directly to the desired address over AXI
                // (Assumes AXI masters are configured correctly in Vivado)
                for (u32 i = 0; i < payload_len; i++) {
                    u8 data = uart_read_byte();
                    // Basic safeguard to write bytes
                    // (For 32-bit registers, we assume the host sends multiples of 4)
                    Xil_Out8(dest_addr + i, data); 
                }
                state = STATE_PROCESS;
                break;

            case STATE_PROCESS:
                if (opcode == CMD_WRITE_CSR) {
                    xil_printf("Wrote CSR 0x%08x\r\n", dest_addr);
                    send_ack(CMD_ACK);
                } 
                else if (opcode == CMD_RUN_DMA) {
                    xil_printf("Triggering DMA...\r\n");
                    // TODO: Polling loop for DMA done or Interrupt wait
                    send_ack(CMD_ACK); 
                }
                else if (opcode == CMD_WRITE_SRAM) {
                    xil_printf("Wrote SRAM block at 0x%08x\r\n", dest_addr);
                    send_ack(CMD_ACK);
                }
                else if (opcode == CMD_WRITE_SYSMEM) {
                    xil_printf("Wrote System Memory block at 0x%08x\r\n", dest_addr);
                    send_ack(CMD_ACK);
                }
                else {
                    send_ack(CMD_NACK); // Unknown command
                }
                
                // Reset for next packet
                sync_buffer = 0;
                state = STATE_WAIT_SYNC;
                break;
        }
    }

    return 0;
}