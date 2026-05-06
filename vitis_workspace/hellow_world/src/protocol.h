#ifndef PROTOCOL_H
#define PROTOCOL_H

#include "xil_types.h"

/* Packet Sync Word to recognize the start of a valid packet */
#define PACKET_SYNC_WORD 0xDEADBEEF

/* Opcodes */
#define CMD_WRITE_SRAM    0x01
#define CMD_WRITE_SYSMEM  0x02
#define CMD_WRITE_CSR     0x03
#define CMD_RUN_DMA       0x04
#define CMD_REQ_RESULTS   0x05
#define CMD_READ_SRAM     0x06
#define CMD_READ_SYSMEM   0x07
#define CMD_ACK           0xAA
#define CMD_NACK          0xEE

/* 
 * Binary Header Format (Total 13 Bytes)
 * [Sync Word : 4 bytes]
 * [Opcode    : 1 byte ]
 * [Address   : 4 bytes]
 * [Length    : 4 bytes] - Length of payload
 */
#define HEADER_SIZE 13

#endif // PROTOCOL_H