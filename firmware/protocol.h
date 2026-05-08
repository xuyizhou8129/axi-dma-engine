#ifndef PROTOCOL_H
#define PROTOCOL_H

#include "xil_types.h"

/* Packet Sync Word to recognize the start of a valid packet */
#define PACKET_SYNC_WORD 0xDEADBEEF

/* Base Addresses */
#define MEM_ACCESS_CTRL_BASE  0x60000000
#define CSR_ACCESS_BASE 0x80000000

// Register offsets
#define REG_INIT_ADDR  0x00
#define REG_INIT_DATA  0x04
#define REG_SRAM_WR    0x08
#define REG_SRAM_RD    0x0C
#define REG_MEM_WR     0x10
#define REG_MEM_RD     0x14
#define REG_RDATA      0x18
#define REG_INIT_DONE  0x1C

/* DMA CSR register offsets (from CSR_ACCESS_BASE) */
#define CSR_REG_BASEADDR    0x00
#define CSR_REG_RINGLEN     0x04
#define CSR_REG_HEAD        0x08
#define CSR_REG_TAIL        0x0C
#define CSR_REG_CTRL        0x10
#define CSR_REG_STATUS      0x14
#define CSR_REG_IRQ_STATUS  0x18
#define CSR_REG_IRQ_CLEAR   0x2C

/* CTRL register bits */
#define CTRL_ENABLE   (1u << 0)
#define CTRL_RESET    (1u << 1)
#define CTRL_IRQ_EN   (1u << 2)

/* STATUS register bits */
#define STATUS_BUSY   (1u << 0)
#define STATUS_EMPTY  (1u << 1)
#define STATUS_ERROR  (1u << 2)

/* Opcodes */
#define CMD_WRITE_SRAM    0x01
#define CMD_WRITE_SYSMEM  0x02
#define CMD_WRITE_CSR     0x03
#define CMD_RUN_DMA       0x04
#define CMD_REQ_RESULTS   0x05
#define CMD_READ_SRAM     0x06
#define CMD_READ_SYSMEM   0x07
#define CMD_CRC_SRAM      0x08
#define CMD_CRC_SYSMEM    0x09
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