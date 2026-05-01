/*
 * esp32_dummy.ino — Mock MicroBlaze firmware for serial_host.py testing
 *
 * Simulates the DMA FPGA protocol so serial_host.py can be tested without
 * real hardware. The ESP32 maintains in-RAM images of system memory, SRAM,
 * and CSR registers and responds to every serial_host.py command.
 *
 * Protocol (matches serial_host.py docstring exactly):
 *   Host → ESP32: "W XXXXXXXX YYYYYYYY\n"       CSR write
 *   Host → ESP32: "R XXXXXXXX\n"                CSR read
 *   Host → ESP32: "SMEM_W XXXXXXXX YYYYYYYY\n"  system-memory word write
 *   Host → ESP32: "SRAM_W XXXXXXXX YYYYYYYY\n"  SRAM word write
 *   Host → ESP32: "SMEM_CRC\n"                  CRC32 of all smem words
 *   Host → ESP32: "SRAM_CRC\n"                  CRC32 of all sram words
 *   ESP32 → Host: "OK\n"                        ack for any write
 *   ESP32 → Host: "DATA YYYYYYYY\n"             CSR read response
 *   ESP32 → Host: "CRC YYYYYYYY\n"              CRC response
 *
 * CRC32 matches Python's zlib.crc32 (CRC-32/ISO-HDLC, poly 0xEDB88320).
 * Words are packed little-endian before hashing, same as serial_host.py.
 *
 * STATUS register (0x14) behaviour:
 *   Returns 0x00000002 (ring_empty=1, busy=0) immediately so wait_done()
 *   terminates on the first poll. This is intentional: the ESP32 has no real
 *   DMA engine, so we signal "done" right away to let the host finish.
 *
 * Wiring:
 *   Connect the ESP32 to the host via its USB cable (built-in USB-UART).
 *   Open at 115200 8N1.
 *
 * Flash via Arduino IDE:
 *   Board: "ESP32 Dev Module" (or your specific variant)
 *   Upload Speed: 921600
 */

#include <Arduino.h>

// Memory sizing (matches run_golden.py / dma_pkg.sv defaults)
#define SMEM_WORDS  1024
#define SRAM_WORDS  1024
#define CSR_REGS    16    // 16 x 32-bit slots covering byte offsets 0x00..0x3C

static uint32_t smem[SMEM_WORDS];
static uint32_t sram_mem[SRAM_WORDS];
static uint32_t csr[CSR_REGS];

// CSR byte-offset → array index
#define CSR_IDX(byte_off)  ((byte_off) >> 2)

// STATUS register (offset 0x14, index 5):
//   bit1 = ring_empty, bit0 = busy
// We pre-set ring_empty=1 so wait_done() passes on the first poll.
#define CSR_STATUS_IDX   5
#define CSR_STATUS_DONE  0x00000002u   // ring_empty=1, busy=0

// CRC32 — matches Python zlib.crc32 (CRC-32/ISO-HDLC)
// Initial value 0, input/output reflected, final XOR 0xFFFFFFFF.
static uint32_t crc32_update(uint32_t crc, const uint8_t *buf, size_t len) {
    crc = ~crc;
    while (len--) {
        crc ^= *buf++;
        for (int i = 0; i < 8; i++)
            crc = (crc >> 1) ^ (0xEDB88320u & (~(crc & 1) + 1));
    }
    return ~crc;
}

static uint32_t words_crc32(const uint32_t *words, size_t n) {
    // Pack as little-endian bytes, same as struct.pack("<NI", ...) in Python
    uint32_t crc = 0;
    for (size_t i = 0; i < n; i++) {
        uint8_t le[4] = {
            (uint8_t)(words[i]       ),
            (uint8_t)(words[i] >>  8 ),
            (uint8_t)(words[i] >> 16 ),
            (uint8_t)(words[i] >> 24 ),
        };
        crc = crc32_update(crc, le, 4);
    }
    return crc;
}

// Helpers
static uint32_t word_at_byte(const uint32_t *arr, size_t arr_words,
                              uint32_t byte_addr) {
    uint32_t idx = byte_addr >> 2;
    if (idx >= arr_words) return 0;
    return arr[idx];
}

static void set_word_at_byte(uint32_t *arr, size_t arr_words,
                              uint32_t byte_addr, uint32_t val) {
    uint32_t idx = byte_addr >> 2;
    if (idx < arr_words) arr[idx] = val;
}

// Command handler
static void handle_command(const String &line) {
    // Tokenise (up to 3 tokens)
    String tok[3];
    int    ntok = 0;
    int    pos  = 0;
    while (pos < (int)line.length() && ntok < 3) {
        while (pos < (int)line.length() && line[pos] == ' ') pos++;
        int start = pos;
        while (pos < (int)line.length() && line[pos] != ' ') pos++;
        if (pos > start) tok[ntok++] = line.substring(start, pos);
    }
    if (ntok == 0) return;

    String cmd = tok[0];
    cmd.toUpperCase();

    if (cmd == "W" && ntok == 3) {
        uint32_t addr = (uint32_t)strtoul(tok[1].c_str(), nullptr, 16);
        uint32_t data = (uint32_t)strtoul(tok[2].c_str(), nullptr, 16);
        uint32_t idx  = addr >> 2;
        if (idx < CSR_REGS) csr[idx] = data;
        Serial.println("OK");

    } else if (cmd == "R" && ntok == 2) {
        uint32_t addr = (uint32_t)strtoul(tok[1].c_str(), nullptr, 16);
        uint32_t idx  = addr >> 2;
        uint32_t val  = (idx < CSR_REGS) ? csr[idx] : 0;
        // STATUS (0x14) always reads as "done" regardless of what was written
        if (addr == 0x14) val = CSR_STATUS_DONE;
        char buf[32];
        snprintf(buf, sizeof(buf), "DATA %08lx", (unsigned long)val);
        Serial.println(buf);

    } else if (cmd == "SMEM_W" && ntok == 3) {
        uint32_t addr = (uint32_t)strtoul(tok[1].c_str(), nullptr, 16);
        uint32_t data = (uint32_t)strtoul(tok[2].c_str(), nullptr, 16);
        set_word_at_byte(smem, SMEM_WORDS, addr, data);
        Serial.println("OK");

    } else if (cmd == "SRAM_W" && ntok == 3) {
        uint32_t addr = (uint32_t)strtoul(tok[1].c_str(), nullptr, 16);
        uint32_t data = (uint32_t)strtoul(tok[2].c_str(), nullptr, 16);
        set_word_at_byte(sram_mem, SRAM_WORDS, addr, data);
        Serial.println("OK");

    } else if (cmd == "SMEM_CRC" && ntok == 1) {
        uint32_t crc_val = words_crc32(smem, SMEM_WORDS);
        char buf[24];
        snprintf(buf, sizeof(buf), "CRC %08lx", (unsigned long)crc_val);
        Serial.println(buf);

    } else if (cmd == "SRAM_CRC" && ntok == 1) {
        uint32_t crc_val = words_crc32(sram_mem, SRAM_WORDS);
        char buf[24];
        snprintf(buf, sizeof(buf), "CRC %08lx", (unsigned long)crc_val);
        Serial.println(buf);

    } else if (cmd == "RESET" && ntok == 1) {
        // Clear all memory and CSR state between test scenarios
        memset(smem,     0, sizeof(smem));
        memset(sram_mem, 0, sizeof(sram_mem));
        memset(csr,      0, sizeof(csr));
        Serial.println("OK");

    } else {
        // Unknown command — send ERR so the host gets a clear failure
        Serial.print("ERR unknown: ");
        Serial.println(line);
    }
}

// Arduino entry points
void setup() {
    memset(smem,    0, sizeof(smem));
    memset(sram_mem, 0, sizeof(sram_mem));
    memset(csr,     0, sizeof(csr));

    Serial.begin(115200);
    // Wait for USB-UART to enumerate (important on native-USB ESP32-S2/S3)
    while (!Serial) delay(10);
    Serial.println("# esp32_dummy ready");
}

void loop() {
    if (Serial.available()) {
        String line = Serial.readStringUntil('\n');
        line.trim();
        if (line.length() > 0)
            handle_command(line);
    }
}
