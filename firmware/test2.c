#include "xil_printf.h"
#include "xil_io.h"

// Comprehensive DMA Engine Test Suite
// Tests: basic transfers, multiple descriptors, different directions, data patterns

#define MEM_ACCESS_CTRL_BASE  0x60000000
#define CSR_ACCESS_BASE       0x80000000

// Register offsets (from mem_access_ctrl.sv)
#define REG_INIT_ADDR  0x00
#define REG_INIT_DATA  0x04
#define REG_SRAM_WR    0x08
#define REG_SRAM_RD    0x0C
#define REG_MEM_WR     0x10
#define REG_MEM_RD     0x14
#define REG_RDATA      0x18
#define REG_INIT_DONE  0x1C

// CSR register offsets (from dma_pkg::REG_* in rtl/csr.sv)
#define CSR_BASEADDR_OFF   0x00
#define CSR_RINGLEN_OFF    0x04
#define CSR_HEAD_OFF       0x08
#define CSR_TAIL_OFF       0x0C
#define CSR_CTRL_OFF       0x10
#define CSR_STATUS_OFF     0x14
#define CSR_IRQ_STATUS_OFF 0x18
#define CSR_IRQ_CLEAR_OFF  0x2C

// CTRL bits
#define CTRL_ENABLE  (1u << 0)
#define CTRL_RESET   (1u << 1)
#define CTRL_IRQ_EN  (1u << 2)

// STATUS bits
#define STATUS_BUSY_BIT       (1u << 0)
#define STATUS_RING_EMPTY_BIT (1u << 1)
#define STATUS_ERROR_BIT      (1u << 2)

// IRQ_STATUS bits
#define IRQ_EMPTY_BIT (1u << 0)
#define IRQ_ERROR_BIT (1u << 1)

// Descriptor direction flags
#define DIR_SRAM_TO_SYSMEM 0u
#define DIR_SYSMEM_TO_SRAM 1u

#define REG_WRITE(offset, val) Xil_Out32(MEM_ACCESS_CTRL_BASE + (offset), (val))
#define REG_READ(offset) Xil_In32(MEM_ACCESS_CTRL_BASE + (offset))

// Helper functions
void sysmem_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_MEM_WR, 1);
}

u32 sysmem_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_MEM_RD, 1);
    return REG_READ(REG_RDATA);
}

void sram_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_SRAM_WR, 1);
}

u32 sram_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_SRAM_RD, 1);
    return REG_READ(REG_RDATA);
}

void csr_write(u32 offset, u32 data) {
    Xil_Out32(CSR_ACCESS_BASE + offset, data);
}

u32 csr_read(u32 offset) {
    return Xil_In32(CSR_ACCESS_BASE + offset);
}

// Wait for DMA completion
int wait_for_dma_done(u32 timeout) {
    while (timeout--) {
        u32 status = csr_read(CSR_STATUS_OFF);
        if (status & STATUS_ERROR_BIT) {
            xil_printf("  DMA ERROR: STATUS=0x%08X IRQ_STATUS=0x%08X\r\n",
                       status, csr_read(CSR_IRQ_STATUS_OFF));
            return 0;
        }
        if (((status & STATUS_RING_EMPTY_BIT) != 0u) && ((status & STATUS_BUSY_BIT) == 0u)) {
            return 1;
        }
    }
    xil_printf("  TIMEOUT waiting for DMA done\r\n");
    return 0;
}

// Reset DMA engine
void reset_dma(void) {
    csr_write(CSR_CTRL_OFF, CTRL_RESET);
    csr_write(CSR_CTRL_OFF, 0);
}

// Test 1: Basic SRAM to SysMem Transfer (same as call_back.c)
int test_basic_sram_to_sysmem(void) {
    xil_printf("\n=== TEST 1: Basic SRAM to SysMem Transfer ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x20;
    const u32 desc_src = 0x30;
    const u32 desc_dst = 0x40;
    const u32 desc_len = 1;
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    const u32 expected_data = 0xCAFE1234;
    
    // Write source data to SRAM
    sram_write(desc_src, expected_data);
    xil_printf("  Wrote SRAM[0x%08X] = 0x%08X\r\n", desc_src, expected_data);
    
    // Write descriptor
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure and start DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify data
    u32 got = sysmem_read(desc_dst);
    if (got != expected_data) {
        xil_printf("  FAIL: SYSMEM[0x%08X] expected 0x%08X got 0x%08X\r\n",
                   desc_dst, expected_data, got);
        return 0;
    }
    
    xil_printf("  PASS: Data verified 0x%08X\r\n", got);
    return 1;
}

// Test 2: Reverse Direction (SysMem to SRAM)
int test_sysmem_to_sram(void) {
    xil_printf("\n=== TEST 2: SysMem to SRAM Transfer ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x50;
    const u32 desc_src = 0x60;
    const u32 desc_dst = 0x70;
    const u32 desc_len = 1;
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    const u32 expected_data = 0xDEADBEEF;
    
    // Write source data to SysMem
    sysmem_write(desc_src, expected_data);
    xil_printf("  Wrote SYSMEM[0x%08X] = 0x%08X\r\n", desc_src, expected_data);
    
    // Write descriptor with DIR=1 (SysMem to SRAM)
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SYSMEM_TO_SRAM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure and start DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify data in SRAM
    u32 got = sram_read(desc_dst);
    if (got != expected_data) {
        xil_printf("  FAIL: SRAM[0x%08X] expected 0x%08X got 0x%08X\r\n",
                   desc_dst, expected_data, got);
        return 0;
    }
    
    xil_printf("  PASS: Data verified 0x%08X\r\n", got);
    return 1;
}

// Test 3: Multiple Descriptors in Ring
int test_multiple_descriptors(void) {
    xil_printf("\n=== TEST 3: Multiple Descriptors ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x80;
    const u32 ring_len = 4;
    const u32 desc_size = 0x10;
    
    // Descriptor 1: SRAM[0x100] -> SYSMEM[0x110]
    const u32 desc1_src = 0x100;
    const u32 desc1_dst = 0x110;
    const u32 data1 = 0x11111111;
    
    // Descriptor 2: SRAM[0x120] -> SYSMEM[0x130]
    const u32 desc2_src = 0x120;
    const u32 desc2_dst = 0x130;
    const u32 data2 = 0x22222222;
    
    // Descriptor 3: SRAM[0x140] -> SYSMEM[0x150]
    const u32 desc3_src = 0x140;
    const u32 desc3_dst = 0x150;
    const u32 data3 = 0x33333333;
    
    // Initialize source data
    sram_write(desc1_src, data1);
    sram_write(desc2_src, data2);
    sram_write(desc3_src, data3);
    xil_printf("  Wrote SRAM source data\r\n");
    
    // Write descriptors to ring
    // Desc 1
    sysmem_write(ring_base + 0x00, desc1_src);
    sysmem_write(ring_base + 0x04, desc1_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    // Desc 2
    sysmem_write(ring_base + desc_size + 0x00, desc2_src);
    sysmem_write(ring_base + desc_size + 0x04, desc2_dst);
    sysmem_write(ring_base + desc_size + 0x08, 1);
    sysmem_write(ring_base + desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    // Desc 3
    sysmem_write(ring_base + 2*desc_size + 0x00, desc3_src);
    sysmem_write(ring_base + 2*desc_size + 0x04, desc3_dst);
    sysmem_write(ring_base + 2*desc_size + 0x08, 1);
    sysmem_write(ring_base + 2*desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure and start DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 3);  // Enqueue 3 descriptors
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify all data
    u32 got1 = sysmem_read(desc1_dst);
    u32 got2 = sysmem_read(desc2_dst);
    u32 got3 = sysmem_read(desc3_dst);
    
    int pass = 1;
    if (got1 != data1) {
        xil_printf("  FAIL: Desc1 expected 0x%08X got 0x%08X\r\n", data1, got1);
        pass = 0;
    }
    if (got2 != data2) {
        xil_printf("  FAIL: Desc2 expected 0x%08X got 0x%08X\r\n", data2, got2);
        pass = 0;
    }
    if (got3 != data3) {
        xil_printf("  FAIL: Desc3 expected 0x%08X got 0x%08X\r\n", data3, got3);
        pass = 0;
    }
    
    if (pass) {
        xil_printf("  PASS: All 3 descriptors verified\r\n");
    }
    return pass;
}

// Test 4: Ring Wrapping/Modulo Behavior
int test_ring_wrapping(void) {
    xil_printf("\n=== TEST 4: Ring Wrapping ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x200;
    const u32 ring_len = 3;  // Small ring to force wrapping
    const u32 desc_size = 0x10;
    
    // Descriptor indices: 0, 1, 2, 0 (wraps), 1
    const u32 data_pattern[] = {0x11223344, 0x55667788, 0x99AABBCC, 0xDDEEFF00, 0x12345678};
    const u32 src_bases[] = {0x300, 0x310, 0x320};
    const u32 dst_bases[] = {0x400, 0x410, 0x420};
    
    // Write initial data to SRAM
    for (int i = 0; i < 3; i++) {
        sram_write(src_bases[i], data_pattern[i]);
    }
    xil_printf("  Initialized source data\r\n");
    
    // Descriptor 0
    sysmem_write(ring_base + 0x00, src_bases[0]);
    sysmem_write(ring_base + 0x04, dst_bases[0]);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    // Descriptor 1
    sysmem_write(ring_base + desc_size + 0x00, src_bases[1]);
    sysmem_write(ring_base + desc_size + 0x04, dst_bases[1]);
    sysmem_write(ring_base + desc_size + 0x08, 1);
    sysmem_write(ring_base + desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    // Descriptor 2
    sysmem_write(ring_base + 2*desc_size + 0x00, src_bases[2]);
    sysmem_write(ring_base + 2*desc_size + 0x04, dst_bases[2]);
    sysmem_write(ring_base + 2*desc_size + 0x08, 1);
    sysmem_write(ring_base + 2*desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 0);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Enqueue first descriptor
    csr_write(CSR_TAIL_OFF, 1);
    
    // Wait a bit, then enqueue more
    u32 wait_count = 100000;
    while (wait_count--) {
        u32 head = csr_read(CSR_HEAD_OFF);
        u32 status = csr_read(CSR_STATUS_OFF);
        if ((head >= 1) && ((status & STATUS_BUSY_BIT) == 0u)) {
            break;
        }
    }
    
    // Enqueue remaining descriptors (wrapping)
    csr_write(CSR_TAIL_OFF, 2);
    csr_write(CSR_TAIL_OFF, 0);  // Wraps to descriptor 0
    csr_write(CSR_TAIL_OFF, 1);  // Wraps to descriptor 1
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify data
    int pass = 1;
    u32 got0 = sysmem_read(dst_bases[0]);
    u32 got1 = sysmem_read(dst_bases[1]);
    u32 got2 = sysmem_read(dst_bases[2]);
    
    if (got0 != data_pattern[0]) {
        xil_printf("  FAIL: Ring[0] expected 0x%08X got 0x%08X\r\n", data_pattern[0], got0);
        pass = 0;
    }
    if (got1 != data_pattern[1]) {
        xil_printf("  FAIL: Ring[1] expected 0x%08X got 0x%08X\r\n", data_pattern[1], got1);
        pass = 0;
    }
    if (got2 != data_pattern[2]) {
        xil_printf("  FAIL: Ring[2] expected 0x%08X got 0x%08X\r\n", data_pattern[2], got2);
        pass = 0;
    }
    
    if (pass) {
        xil_printf("  PASS: Ring wrapping verified\r\n");
    }
    return pass;
}

// Test 5: Larger Burst Transfers
int test_large_burst(void) {
    xil_printf("\n=== TEST 5: Larger Burst Transfer ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x500;
    const u32 desc_src = 0x600;
    const u32 desc_dst = 0x700;
    const u32 desc_len = 4;  // Transfer 4 words
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    
    const u32 data_values[] = {0xAAAA0000, 0xBBBB1111, 0xCCCC2222, 0xDDDD3333};
    
    // Write source data (4 consecutive words)
    for (int i = 0; i < 4; i++) {
        sram_write(desc_src + (i * 4), data_values[i]);
    }
    xil_printf("  Wrote 4 words to SRAM\r\n");
    
    // Write descriptor
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure and start DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify all data
    int pass = 1;
    for (int i = 0; i < 4; i++) {
        u32 got = sysmem_read(desc_dst + (i * 4));
        if (got != data_values[i]) {
            xil_printf("  FAIL: Word %d expected 0x%08X got 0x%08X\r\n", i, data_values[i], got);
            pass = 0;
        }
    }
    
    if (pass) {
        xil_printf("  PASS: All 4 words verified\r\n");
    }
    return pass;
}

// Test 6: Various Data Patterns
int test_data_patterns(void) {
    xil_printf("\n=== TEST 6: Various Data Patterns ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0x800;
    const u32 ring_len = 5;
    const u32 desc_size = 0x10;
    
    // Test patterns: 0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555, 0x12345678
    const u32 patterns[] = {0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555, 0x12345678};
    const u32 src_bases[] = {0x900, 0x910, 0x920, 0x930, 0x940};
    const u32 dst_bases[] = {0x950, 0x960, 0x970, 0x980, 0x990};
    
    // Write source data
    for (int i = 0; i < 5; i++) {
        sram_write(src_bases[i], patterns[i]);
    }
    xil_printf("  Initialized 5 test patterns\r\n");
    
    // Write descriptors
    for (int i = 0; i < 5; i++) {
        u32 offset = ring_base + i * desc_size;
        sysmem_write(offset + 0x00, src_bases[i]);
        sysmem_write(offset + 0x04, dst_bases[i]);
        sysmem_write(offset + 0x08, 1);
        sysmem_write(offset + 0x0C, DIR_SRAM_TO_SYSMEM);
    }
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure and start DMA
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 5);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Verify all patterns
    int pass = 1;
    for (int i = 0; i < 5; i++) {
        u32 got = sysmem_read(dst_bases[i]);
        if (got != patterns[i]) {
            xil_printf("  FAIL: Pattern %d expected 0x%08X got 0x%08X\r\n", i, patterns[i], got);
            pass = 0;
        }
    }
    
    if (pass) {
        xil_printf("  PASS: All 5 patterns verified\r\n");
    }
    return pass;
}

// Test 7: Status and IRQ Verification
int test_status_and_irq(void) {
    xil_printf("\n=== TEST 7: Status and IRQ Verification ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0xA00;
    const u32 desc_src = 0xB00;
    const u32 desc_dst = 0xB10;
    const u32 ring_len = 2;
    const u32 data = 0xABCDEF00;
    
    // Write source data
    sram_write(desc_src, data);
    
    // Write descriptor
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    // Configure DMA with IRQ enabled
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    
    // Check initial status (should be empty)
    u32 status_before = csr_read(CSR_STATUS_OFF);
    xil_printf("  Initial status: 0x%08X\r\n", status_before);
    
    if ((status_before & STATUS_RING_EMPTY_BIT) == 0u) {
        xil_printf("  FAIL: Ring should be empty initially\r\n");
        return 0;
    }
    
    // Start DMA
    csr_write(CSR_TAIL_OFF, 1);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    // Check status (should show busy or non-empty)
    u32 status_during = csr_read(CSR_STATUS_OFF);
    xil_printf("  Status during: 0x%08X\r\n", status_during);
    
    // Wait for completion
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    // Check final status
    u32 status_after = csr_read(CSR_STATUS_OFF);
    u32 irq_status = csr_read(CSR_IRQ_STATUS_OFF);
    u32 head = csr_read(CSR_HEAD_OFF);
    u32 tail = csr_read(CSR_TAIL_OFF);
    
    xil_printf("  Final status: 0x%08X, IRQ_STATUS: 0x%08X\r\n", status_after, irq_status);
    xil_printf("  HEAD: %u, TAIL: %u\r\n", head, tail);
    
    int pass = 1;
    
    // Should be empty after completion
    if ((status_after & STATUS_RING_EMPTY_BIT) == 0u) {
        xil_printf("  FAIL: Ring should be empty after completion\r\n");
        pass = 0;
    }
    
    // Should not have error
    if ((status_after & STATUS_ERROR_BIT) != 0u) {
        xil_printf("  FAIL: Error bit should not be set\r\n");
        pass = 0;
    }
    
    // IRQ_EMPTY should be set
    if ((irq_status & IRQ_EMPTY_BIT) == 0u) {
        xil_printf("  FAIL: IRQ_EMPTY should be set\r\n");
        pass = 0;
    }
    
    // HEAD should equal TAIL
    if (head != tail) {
        xil_printf("  FAIL: HEAD should equal TAIL when ring is empty (HEAD=%u, TAIL=%u)\r\n", head, tail);
        pass = 0;
    }
    
    if (pass) {
        xil_printf("  PASS: Status and IRQ verified\r\n");
    }
    return pass;
}

// Test 8: Back-to-back Transfers
int test_back_to_back(void) {
    xil_printf("\n=== TEST 8: Back-to-Back Transfers ===\r\n");
    
    reset_dma();
    
    const u32 ring_base = 0xC00;
    const u32 ring_len = 2;
    
    // First transfer
    const u32 desc1_src = 0xD00;
    const u32 desc1_dst = 0xD10;
    const u32 data1 = 0x11223344;
    
    // Initialize first transfer
    sram_write(desc1_src, data1);
    sysmem_write(ring_base + 0x00, desc1_src);
    sysmem_write(ring_base + 0x04, desc1_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 1);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    u32 got1 = sysmem_read(desc1_dst);
    if (got1 != data1) {
        xil_printf("  FAIL: Transfer 1 expected 0x%08X got 0x%08X\r\n", data1, got1);
        return 0;
    }
    xil_printf("  First transfer verified\r\n");
    
    // Reset for second transfer
    reset_dma();
    
    const u32 desc2_src = 0xE00;
    const u32 desc2_dst = 0xE10;
    const u32 data2 = 0x55667788;
    
    // Initialize second transfer
    sram_write(desc2_src, data2);
    sysmem_write(ring_base + 0x00, desc2_src);
    sysmem_write(ring_base + 0x04, desc2_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 1);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        return 0;
    }
    
    u32 got2 = sysmem_read(desc2_dst);
    if (got2 != data2) {
        xil_printf("  FAIL: Transfer 2 expected 0x%08X got 0x%08X\r\n", data2, got2);
        return 0;
    }
    
    xil_printf("  PASS: Both back-to-back transfers verified\r\n");
    return 1;
}

// Main test runner
int main(void) {
    int total_tests = 0;
    int passed_tests = 0;
    
    xil_printf("\n========================================\r\n");
    xil_printf("   DMA ENGINE COMPREHENSIVE TEST SUITE\r\n");
    xil_printf("========================================\r\n");
    
    // Early MMIO probe
    u32 mem_probe_wr = 0xA5A50020;
    REG_WRITE(REG_INIT_ADDR, mem_probe_wr);
    u32 mem_probe_rd = REG_READ(REG_INIT_ADDR);
    
    u32 csr_probe_wr = 0x5A5A0020;
    csr_write(CSR_BASEADDR_OFF, csr_probe_wr);
    u32 csr_probe_rd = csr_read(CSR_BASEADDR_OFF);
    
    xil_printf("MMIO probe mem_access_ctrl: wrote 0x%08X read 0x%08X\r\n", mem_probe_wr, mem_probe_rd);
    xil_printf("MMIO probe csr             : wrote 0x%08X read 0x%08X\r\n", csr_probe_wr, csr_probe_rd);
    
    if ((mem_probe_rd != mem_probe_wr) || (csr_probe_rd != csr_probe_wr)) {
        xil_printf("ERROR: MMIO mapping mismatch. Check base addresses.\r\n");
        return 1;
    }
    
    // Run all tests
    total_tests++;
    if (test_basic_sram_to_sysmem()) passed_tests++;
    
    total_tests++;
    if (test_sysmem_to_sram()) passed_tests++;
    
    total_tests++;
    if (test_multiple_descriptors()) passed_tests++;
    
    total_tests++;
    if (test_ring_wrapping()) passed_tests++;
    
    total_tests++;
    if (test_large_burst()) passed_tests++;
    
    total_tests++;
    if (test_data_patterns()) passed_tests++;
    
    total_tests++;
    if (test_status_and_irq()) passed_tests++;
    
    total_tests++;
    if (test_back_to_back()) passed_tests++;
    
    // Final summary
    xil_printf("\n========================================\r\n");
    xil_printf("        TEST SUMMARY\r\n");
    xil_printf("========================================\r\n");
    xil_printf("Total Tests : %d\r\n", total_tests);
    xil_printf("Passed      : %d\r\n", passed_tests);
    xil_printf("Failed      : %d\r\n", total_tests - passed_tests);
    
    if (passed_tests == total_tests) {
        xil_printf("\n=== ALL TESTS PASSED ===\r\n");
        return 0;
    } else {
        xil_printf("\n=== SOME TESTS FAILED ===\r\n");
        return 1;
    }
}
