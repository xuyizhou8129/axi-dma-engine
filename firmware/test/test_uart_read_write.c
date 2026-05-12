#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <setjmp.h>

#include "mocks.h"
#include "protocol.h"

int firmware_main(void);

static int total  = 0;
static int passed = 0;

#define ASSERT(cond, msg) do { \
    total++; \
    if (cond) { passed++; } \
    else { printf("    FAIL: %s (line %d)\n", msg, __LINE__); } \
} while (0)

/* ---- helpers ---- */

static void put_u32_le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v        & 0xFF);
    p[1] = (uint8_t)((v >> 8)  & 0xFF);
    p[2] = (uint8_t)((v >> 16) & 0xFF);
    p[3] = (uint8_t)((v >> 24) & 0xFF);
}

static uint32_t get_u32_le(const uint8_t *p) {
    return (uint32_t)p[0]
         | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[3] << 24);
}

static int build_pkt(uint8_t *buf, uint8_t opcode, uint32_t addr,
                     const uint8_t *payload, uint32_t plen) {
    put_u32_le(&buf[0], 0xDEADBEEFu);
    buf[4] = opcode;
    put_u32_le(&buf[5],  addr);
    put_u32_le(&buf[9],  plen);
    if (plen) memcpy(&buf[13], payload, plen);
    return 13 + (int)plen;
}

static void drain(void) {
    rx_starved_armed = 1;
    if (setjmp(rx_starved_jmp) == 0) {
        firmware_main();
    }
    rx_starved_armed = 0;
}

static int last_write_to(uint32_t addr) {
    int found = -1;
    for (int i = 0; i < mmio_log_len; i++) {
        if (mmio_log[i].is_write && mmio_log[i].addr == addr) found = i;
    }
    return found;
}

static int count_reads_of(uint32_t addr) {
    int n = 0;
    for (int i = 0; i < mmio_log_len; i++) {
        if (!mmio_log[i].is_write && mmio_log[i].addr == addr) n++;
    }
    return n;
}

/* Reference CRC32-IEEE (zlib-compatible) — verifies firmware computes the same
 * algorithm. End-to-end zlib compatibility is verified on-FPGA against the host
 * script, not here. */
static uint32_t ref_crc32(const uint8_t *data, int len) {
    static uint32_t table[256];
    static int inited = 0;
    if (!inited) {
        for (int i = 0; i < 256; i++) {
            uint32_t c = (uint32_t)i;
            for (int j = 0; j < 8; j++) {
                c = (c & 1u) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            }
            table[i] = c;
        }
        inited = 1;
    }
    uint32_t crc = 0xFFFFFFFFu;
    for (int i = 0; i < len; i++) {
        crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFFu;
}

/* ---- write/read tests (route through mem_access_ctrl shim) ---- */

static void test_write_csr_basic(void) {
    printf("test_write_csr_basic\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0xCAFEBABEu);
    int n = build_pkt(pkt, CMD_WRITE_CSR, CSR_ACCESS_BASE + 0x10, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    /* CSR is direct MMIO — no shim. */
    ASSERT(mmio_log_len == 1, "exactly one MMIO op");
    ASSERT(mmio_log[0].is_write, "MMIO op is a write");
    ASSERT(mmio_log[0].addr == CSR_ACCESS_BASE + 0x10, "CSR addr matches");
    ASSERT(mmio_log[0].val  == 0xCAFEBABEu, "CSR value matches payload");
    ASSERT(mock_tx_len() == 5, "ACK frame is 5 bytes");
    ASSERT(get_u32_le(mock_tx_buf()) == 0xDEADBEEFu, "ACK sync word");
    ASSERT(mock_tx_buf()[4] == CMD_ACK, "ACK byte = 0xAA");
}

static void test_write_sram_via_shim(void) {
    printf("test_write_sram_via_shim\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0x11223344u);
    int n = build_pkt(pkt, CMD_WRITE_SRAM, 0x100u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mmio_log_len == 3, "shim: 3 MMIO writes (INIT_ADDR, INIT_DATA, SRAM_WR)");
    ASSERT(mmio_log[0].addr == MEM_ACCESS_CTRL_BASE + REG_INIT_ADDR, "first sets INIT_ADDR");
    ASSERT(mmio_log[0].val  == 0x100u, "INIT_ADDR value");
    ASSERT(mmio_log[1].addr == MEM_ACCESS_CTRL_BASE + REG_INIT_DATA, "second sets INIT_DATA");
    ASSERT(mmio_log[1].val  == 0x11223344u, "INIT_DATA value");
    ASSERT(mmio_log[2].addr == MEM_ACCESS_CTRL_BASE + REG_SRAM_WR, "third pulses SRAM_WR");
    ASSERT(mmio_log[2].val  == 1, "SRAM_WR pulse");
    ASSERT(mock_get_sram_word(0x100) == 0x11223344u, "shim wrote SRAM backing");
    ASSERT(mock_tx_buf()[4] == CMD_ACK, "ACK");
}

static void test_write_sysmem_via_shim(void) {
    printf("test_write_sysmem_via_shim\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0xDEADBEEFu);
    int n = build_pkt(pkt, CMD_WRITE_SYSMEM, 0x200u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mmio_log_len == 3, "shim: 3 MMIO writes");
    ASSERT(mmio_log[2].addr == MEM_ACCESS_CTRL_BASE + REG_MEM_WR, "third pulses MEM_WR (sysmem)");
    ASSERT(mock_get_sysmem_word(0x200) == 0xDEADBEEFu, "shim wrote SYSMEM backing");
    ASSERT(mock_tx_buf()[4] == CMD_ACK, "ACK");
}

static void test_read_sram_via_shim(void) {
    printf("test_read_sram_via_shim\n");
    mocks_reset();
    mock_set_sram_word(0x100, 0xFEEDFACEu);
    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_READ_SRAM, 0x100u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mmio_log_len == 3, "shim read: INIT_ADDR write, SRAM_RD pulse, RDATA read");
    ASSERT(mmio_log[0].addr == MEM_ACCESS_CTRL_BASE + REG_INIT_ADDR, "INIT_ADDR set");
    ASSERT(mmio_log[1].addr == MEM_ACCESS_CTRL_BASE + REG_SRAM_RD, "SRAM_RD pulse");
    ASSERT(mmio_log[2].addr == MEM_ACCESS_CTRL_BASE + REG_RDATA, "RDATA read");
    ASSERT(mock_tx_len() == 9, "ACK frame (5) + data (4)");
    ASSERT(mock_tx_buf()[4] == CMD_ACK, "ACK byte");
    ASSERT(get_u32_le(&mock_tx_buf()[5]) == 0xFEEDFACEu, "data echoed LE on wire");
}

static void test_read_sysmem_via_shim(void) {
    printf("test_read_sysmem_via_shim\n");
    mocks_reset();
    mock_set_sysmem_word(0x80, 0x12345678u);
    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_READ_SYSMEM, 0x80u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mmio_log[1].addr == MEM_ACCESS_CTRL_BASE + REG_MEM_RD, "MEM_RD pulse");
    ASSERT(get_u32_le(&mock_tx_buf()[5]) == 0x12345678u, "sysmem read data");
}

/* ---- CMD_RUN_DMA flow ---- */

static void test_run_dma_status_done(void) {
    printf("test_run_dma_status_done\n");
    mocks_reset();
    /* STATUS reads as RING_EMPTY (bit 1) with BUSY=0 → done immediately. */
    mock_mmio_preset(CSR_ACCESS_BASE + CSR_REG_STATUS, STATUS_EMPTY);

    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_RUN_DMA, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mmio_log[0].addr == MEM_ACCESS_CTRL_BASE + REG_INIT_DONE,
           "first MMIO is INIT_DONE (memory handed to DMA)");
    ASSERT(mmio_log[0].val == 1, "INIT_DONE asserted");

    int ctrl_w = last_write_to(CSR_ACCESS_BASE + CSR_REG_CTRL);
    ASSERT(ctrl_w >= 0, "CTRL written");
    ASSERT(mmio_log[ctrl_w].val == CTRL_ENABLE, "ENABLE bit set in CTRL write");
    ASSERT(count_reads_of(CSR_ACCESS_BASE + CSR_REG_STATUS) >= 1, "STATUS polled");

    int tlen = mock_tx_len();
    ASSERT(mock_tx_buf()[tlen - 1] == CMD_ACK, "ACK trailing");
}

static void test_run_dma_preserves_ctrl_bits(void) {
    printf("test_run_dma_preserves_ctrl_bits\n");
    mocks_reset();
    mock_mmio_preset(CSR_ACCESS_BASE + CSR_REG_CTRL,   CTRL_IRQ_EN);
    mock_mmio_preset(CSR_ACCESS_BASE + CSR_REG_STATUS, STATUS_EMPTY);

    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_RUN_DMA, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();

    int ctrl_w = last_write_to(CSR_ACCESS_BASE + CSR_REG_CTRL);
    ASSERT(ctrl_w >= 0, "CTRL written");
    ASSERT(mmio_log[ctrl_w].val == (CTRL_ENABLE | CTRL_IRQ_EN),
           "CTRL preserved IRQ_EN and ORed in ENABLE");
}

static void test_run_dma_busy_then_done(void) {
    printf("test_run_dma_busy_then_done\n");
    mocks_reset();
    uint32_t seq[] = { STATUS_BUSY, STATUS_BUSY, STATUS_EMPTY };
    mock_set_read_sequence(CSR_ACCESS_BASE + CSR_REG_STATUS, seq, 3);

    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_RUN_DMA, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(count_reads_of(CSR_ACCESS_BASE + CSR_REG_STATUS) == 3,
           "STATUS polled 3 times (BUSY, BUSY, EMPTY)");
    int tlen = mock_tx_len();
    ASSERT(mock_tx_buf()[tlen - 1] == CMD_ACK, "ACK once EMPTY clears BUSY");
}

static void test_run_dma_error_status(void) {
    printf("test_run_dma_error_status\n");
    mocks_reset();
    mock_mmio_preset(CSR_ACCESS_BASE + CSR_REG_STATUS, STATUS_ERROR);

    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_RUN_DMA, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();

    int tlen = mock_tx_len();
    ASSERT(mock_tx_buf()[tlen - 1] == CMD_NACK, "ERROR -> NACK");
}

/* ---- CRC32 tests ---- */

static void test_crc_sram_basic(void) {
    printf("test_crc_sram_basic\n");
    mocks_reset();
    uint32_t words[] = {0x12345678u, 0xABCDEF01u, 0xCAFEBABEu, 0xDEADBEEFu};
    for (int i = 0; i < 4; i++) {
        mock_set_sram_word((uint32_t)(i * 4), words[i]);
    }

    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 16u);
    int n = build_pkt(pkt, CMD_CRC_SRAM, 0u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    /* Expected: zlib-compatible CRC over LE-packed words. */
    uint8_t bytes[16];
    for (int i = 0; i < 4; i++) put_u32_le(&bytes[i*4], words[i]);
    uint32_t expected = ref_crc32(bytes, 16);

    ASSERT(mock_tx_len() == 9, "ACK (5) + CRC (4)");
    ASSERT(get_u32_le(mock_tx_buf()) == 0xDEADBEEFu, "ACK sync");
    ASSERT(mock_tx_buf()[4] == CMD_ACK, "ACK byte");
    ASSERT(get_u32_le(&mock_tx_buf()[5]) == expected, "CRC matches reference");
}

static void test_crc_sysmem_basic(void) {
    printf("test_crc_sysmem_basic\n");
    mocks_reset();
    uint32_t words[] = {0x00000001u, 0x00000002u, 0x00000003u};
    for (int i = 0; i < 3; i++) {
        mock_set_sysmem_word((uint32_t)(0x40 + i * 4), words[i]);
    }

    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 12u);
    int n = build_pkt(pkt, CMD_CRC_SYSMEM, 0x40u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    uint8_t bytes[12];
    for (int i = 0; i < 3; i++) put_u32_le(&bytes[i*4], words[i]);
    uint32_t expected = ref_crc32(bytes, 12);

    ASSERT(get_u32_le(&mock_tx_buf()[5]) == expected, "sysmem CRC matches reference");
}

static void test_crc_empty_range(void) {
    printf("test_crc_empty_range\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0u);
    int n = build_pkt(pkt, CMD_CRC_SRAM, 0u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    /* zlib.crc32(b'') == 0 */
    ASSERT(get_u32_le(&mock_tx_buf()[5]) == 0u, "empty range CRC = 0 (zlib compat)");
}

static void test_crc_short_payload_nacks(void) {
    printf("test_crc_short_payload_nacks\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[2] = {0x10, 0x00};
    int n = build_pkt(pkt, CMD_CRC_SRAM, 0u, payload, 2);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mock_tx_buf()[4] == CMD_NACK, "short payload -> NACK");
}

/* ---- protocol framing / dispatch tests (unchanged from before) ---- */

static void test_unknown_opcode_nack(void) {
    printf("test_unknown_opcode_nack\n");
    mocks_reset();
    uint8_t pkt[64];
    int n = build_pkt(pkt, 0xFF, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mock_tx_len() == 5, "NACK frame size");
    ASSERT(mock_tx_buf()[4] == CMD_NACK, "unknown opcode -> NACK");
}

static void test_req_results_nack(void) {
    printf("test_req_results_nack\n");
    mocks_reset();
    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_REQ_RESULTS, 0u, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mock_tx_buf()[4] == CMD_NACK, "REQ_RESULTS -> NACK (TODO)");
}

static void test_garbage_then_packet(void) {
    printf("test_garbage_then_packet\n");
    mocks_reset();
    uint8_t garbage[] = {0x01, 0x02, 0x03, 0x04, 0x55, 0x66};
    mock_rx_push_bytes(garbage, sizeof(garbage));

    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0xAABBCCDDu);
    int n = build_pkt(pkt, CMD_WRITE_SRAM, 0x100u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mock_get_sram_word(0x100) == 0xAABBCCDDu, "packet processed after garbage");
}

static void test_two_packets_back_to_back(void) {
    printf("test_two_packets_back_to_back\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t pl1[4]; put_u32_le(pl1, 0x11111111u);
    uint8_t pl2[4]; put_u32_le(pl2, 0x22222222u);
    int n1 = build_pkt(pkt, CMD_WRITE_SRAM, 0x100u, pl1, 4);
    mock_rx_push_bytes(pkt, n1);
    int n2 = build_pkt(pkt, CMD_WRITE_SRAM, 0x104u, pl2, 4);
    mock_rx_push_bytes(pkt, n2);
    drain();
    ASSERT(mock_get_sram_word(0x100) == 0x11111111u, "first write landed");
    ASSERT(mock_get_sram_word(0x104) == 0x22222222u, "second write landed");
    ASSERT(mock_tx_len() == 10, "two ACK frames = 10 bytes");
}

static void test_partial_sync_recovers(void) {
    printf("test_partial_sync_recovers\n");
    mocks_reset();
    uint8_t partial[] = {0xEF, 0xBE, 0xAD};
    mock_rx_push_bytes(partial, sizeof(partial));

    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0xC0FFEE00u);
    int n = build_pkt(pkt, CMD_WRITE_SRAM, 0x080u, payload, 4);
    mock_rx_push_bytes(pkt, n);
    drain();

    ASSERT(mock_get_sram_word(0x080) == 0xC0FFEE00u, "partial-sync prefix didn't break framing");
}

static void test_addr_endianness(void) {
    printf("test_addr_endianness\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4] = {0,0,0,0};
    int n = build_pkt(pkt, CMD_WRITE_CSR, 0x12345678u, payload, 4);
    ASSERT(pkt[5] == 0x78 && pkt[6] == 0x56 && pkt[7] == 0x34 && pkt[8] == 0x12,
           "host packs addr LE");
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mmio_log[0].addr == 0x12345678u, "firmware reconstructs LE addr");
}

static void test_payload_endianness(void) {
    printf("test_payload_endianness\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[4]; put_u32_le(payload, 0xDEADBEEFu);
    int n = build_pkt(pkt, CMD_WRITE_CSR, CSR_ACCESS_BASE, payload, 4);
    ASSERT(pkt[13] == 0xEF && pkt[14] == 0xBE && pkt[15] == 0xAD && pkt[16] == 0xDE,
           "host packs payload LE");
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mmio_log[0].val == 0xDEADBEEFu, "firmware reconstructs LE payload");
}

static void test_short_payload_nacks(void) {
    printf("test_short_payload_nacks\n");
    mocks_reset();
    uint8_t pkt[64];
    uint8_t payload[2] = {0xAA, 0xBB};
    int n = build_pkt(pkt, CMD_WRITE_CSR, CSR_ACCESS_BASE, payload, 2);
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mmio_log_len == 0, "short payload -> no MMIO");
    ASSERT(mock_tx_buf()[4] == CMD_NACK, "short payload -> NACK");
}

static void test_zero_payload_write_nacks(void) {
    printf("test_zero_payload_write_nacks\n");
    mocks_reset();
    uint8_t pkt[64];
    int n = build_pkt(pkt, CMD_WRITE_CSR, CSR_ACCESS_BASE, NULL, 0);
    mock_rx_push_bytes(pkt, n);
    drain();
    ASSERT(mmio_log_len == 0, "len=0 write -> no MMIO");
    ASSERT(mock_tx_buf()[4] == CMD_NACK, "len=0 write -> NACK");
}

static void test_oversized_payload_drains(void) {
    printf("test_oversized_payload_drains\n");
    mocks_reset();
    uint8_t pkt[128];
    uint8_t payload[8];
    put_u32_le(&payload[0], 0xAABBCCDDu);
    put_u32_le(&payload[4], 0x99999999u);
    int n = build_pkt(pkt, CMD_WRITE_SRAM, 0x100u, payload, 8);
    mock_rx_push_bytes(pkt, n);

    uint8_t pkt2[64];
    uint8_t pl2[4]; put_u32_le(pl2, 0x55555555u);
    int n2 = build_pkt(pkt2, CMD_WRITE_SRAM, 0x104u, pl2, 4);
    mock_rx_push_bytes(pkt2, n2);
    drain();

    ASSERT(mock_get_sram_word(0x100) == 0xAABBCCDDu, "first 4 payload bytes used");
    ASSERT(mock_get_sram_word(0x104) == 0x55555555u, "second packet framing intact");
}

int main(void) {
    test_write_csr_basic();
    test_write_sram_via_shim();
    test_write_sysmem_via_shim();
    test_read_sram_via_shim();
    test_read_sysmem_via_shim();

    test_run_dma_status_done();
    test_run_dma_preserves_ctrl_bits();
    test_run_dma_busy_then_done();
    test_run_dma_error_status();

    test_crc_sram_basic();
    test_crc_sysmem_basic();
    test_crc_empty_range();
    test_crc_short_payload_nacks();

    test_unknown_opcode_nack();
    test_req_results_nack();
    test_garbage_then_packet();
    test_two_packets_back_to_back();
    test_partial_sync_recovers();
    test_addr_endianness();
    test_payload_endianness();
    test_short_payload_nacks();
    test_zero_payload_write_nacks();
    test_oversized_payload_drains();

    printf("\n%d/%d assertions passed\n", passed, total);
    return passed == total ? 0 : 1;
}
