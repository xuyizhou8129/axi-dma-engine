/*
 * esp32_dummy.ino — Mock MicroBlaze firmware for serial_host.py testing
 *
 * Simulates the DMA FPGA binary protocol so serial_host.py can be tested
 * without real hardware. Maintains in-RAM images of system memory, SRAM,
 * and CSR registers and responds to every serial_host.py command with a
 * binary ACK packet.
 *
 * Binary Protocol (matches protocol.h / serial_host.py):
 *
 *   Host → ESP32 packet:
 *     [Sync Word : 4 bytes LE] = 0xDEADBEEF
 *     [Opcode    : 1 byte    ]
 *     [Address   : 4 bytes LE]
 *     [Length    : 4 bytes LE] = payload byte count
 *     [Payload   : Length bytes]
 *
 *   ESP32 → Host ACK:
 *     [Sync Word : 4 bytes LE] = 0xDEADBEEF
 *     [ACK/NACK  : 1 byte    ] = 0xAA (ACK) or 0xEE (NACK)
 *
 *   Opcodes handled:
 *     CMD_WRITE_SRAM   0x01  write payload to sram array
 *     CMD_WRITE_SYSMEM 0x02  write payload to smem array
 *     CMD_WRITE_CSR    0x03  write payload to csr array
 *     CMD_RUN_DMA      0x04  simulate DMA done immediately
 *
 * Wiring:
 *   Connect ESP32 to host via USB cable. Open at 9600 8N1.
 *
 * Flash via Arduino IDE:
 *   Board: "ESP32 Dev Module"
 *   Upload Speed: 921600
 */

#include <Arduino.h>

// Protocol constants — must match protocol.h
#define PACKET_SYNC_WORD  0xDEADBEEFul
#define CMD_WRITE_SRAM    0x01
#define CMD_WRITE_SYSMEM  0x02
#define CMD_WRITE_CSR     0x03
#define CMD_RUN_DMA       0x04
#define CMD_ACK           0xAA
#define CMD_NACK          0xEE

// Memory sizing (matches run_golden.py / dma_pkg.sv defaults)
#define SMEM_WORDS  1024
#define SRAM_WORDS  1024
#define CSR_REGS    16    // covers byte offsets 0x00..0x3C

static uint32_t smem[SMEM_WORDS];
static uint32_t sram_mem[SRAM_WORDS];
static uint32_t csr[CSR_REGS];

// Parser state machine
typedef enum {
    STATE_WAIT_SYNC,
    STATE_READ_HEADER,
    STATE_READ_PAYLOAD,
    STATE_PROCESS
} ParserState;

static ParserState state    = STATE_WAIT_SYNC;
static uint32_t    sync_buf = 0;
static uint8_t     opcode   = 0;
static uint32_t    dest_addr = 0;
static uint32_t    payload_len = 0;
static uint32_t    payload_idx = 0;

// Send binary ACK/NACK: 0xDEADBEEF LE + ack byte
static void send_ack(uint8_t ack_type) {
    uint32_t sw = PACKET_SYNC_WORD;
    Serial.write((uint8_t)(sw        & 0xFF));
    Serial.write((uint8_t)((sw >> 8)  & 0xFF));
    Serial.write((uint8_t)((sw >> 16) & 0xFF));
    Serial.write((uint8_t)((sw >> 24) & 0xFF));
    Serial.write(ack_type);
}

// Read 4 bytes little-endian from serial (blocking)
static uint32_t read_u32_le() {
    while (Serial.available() < 4) {}
    uint32_t v  = (uint32_t)Serial.read();
    v |= (uint32_t)Serial.read() << 8;
    v |= (uint32_t)Serial.read() << 16;
    v |= (uint32_t)Serial.read() << 24;
    return v;
}

// Write one payload byte to the correct array based on opcode
static void write_payload_byte(uint8_t b) {
    uint32_t byte_addr = dest_addr + payload_idx;
    uint32_t word_idx  = (byte_addr >> 2);
    uint8_t  byte_lane = byte_addr & 3;

    switch (opcode) {
        case CMD_WRITE_CSR:
            if (word_idx < CSR_REGS) {
                uint8_t *p = (uint8_t *)&csr[word_idx];
                p[byte_lane] = b;
            }
            break;
        case CMD_WRITE_SYSMEM:
            if (word_idx < SMEM_WORDS) {
                uint8_t *p = (uint8_t *)&smem[word_idx];
                p[byte_lane] = b;
            }
            break;
        case CMD_WRITE_SRAM:
            if (word_idx < SRAM_WORDS) {
                uint8_t *p = (uint8_t *)&sram_mem[word_idx];
                p[byte_lane] = b;
            }
            break;
        default:
            break;
    }
}

void setup() {
    memset(smem,    0, sizeof(smem));
    memset(sram_mem, 0, sizeof(sram_mem));
    memset(csr,     0, sizeof(csr));

    Serial.begin(9600);
    while (!Serial) delay(10);
    Serial.print("# esp32_dummy ready (binary protocol)\r\n");
}

void loop() {
    if (!Serial.available()) return;

    switch (state) {

        case STATE_WAIT_SYNC: {
            uint8_t b = Serial.read();
            sync_buf = (sync_buf >> 8) | ((uint32_t)b << 24);
            if (sync_buf == PACKET_SYNC_WORD) {
                state = STATE_READ_HEADER;
            }
            break;
        }

        case STATE_READ_HEADER: {
            if (Serial.available() < 9) return; // opcode(1) + addr(4) + len(4)
            opcode      = Serial.read();
            dest_addr   = read_u32_le();
            payload_len = read_u32_le();
            payload_idx = 0;

            state = (payload_len > 0) ? STATE_READ_PAYLOAD : STATE_PROCESS;
            break;
        }

        case STATE_READ_PAYLOAD: {
            while (Serial.available() && payload_idx < payload_len) {
                uint8_t b = Serial.read();
                write_payload_byte(b);
                payload_idx++;
            }
            if (payload_idx >= payload_len) {
                state = STATE_PROCESS;
            }
            break;
        }

        case STATE_PROCESS: {
            switch (opcode) {
                case CMD_WRITE_CSR:
                case CMD_WRITE_SYSMEM:
                case CMD_WRITE_SRAM:
                case CMD_RUN_DMA:
                    send_ack(CMD_ACK);
                    break;
                default:
                    send_ack(CMD_NACK);
                    break;
            }
            sync_buf = 0;
            state    = STATE_WAIT_SYNC;
            break;
        }
    }
}
