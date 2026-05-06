#include "xparameters.h"
#include "xuartlite_l.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "protocol.h"

#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR

#define MEM_ACCESS_CTRL_BASE  0x60000000
#define CSR_ACCESS_BASE       0x80000000

// Register offsets
#define REG_INIT_ADDR  0x00
#define REG_INIT_DATA  0x04
#define REG_SRAM_WR    0x08
#define REG_SRAM_RD    0x0C
#define REG_MEM_WR     0x10
#define REG_MEM_RD     0x14
#define REG_RDATA      0x18
#define REG_INIT_DONE  0x1C

#define CSR_BASEADDR_OFF   0x00
#define CSR_RINGLEN_OFF    0x04
#define CSR_HEAD_OFF       0x08
#define CSR_TAIL_OFF       0x0C
#define CSR_CTRL_OFF       0x10
#define CSR_STATUS_OFF     0x14
#define CSR_IRQ_STATUS_OFF 0x18
#define CSR_IRQ_CLEAR_OFF  0x2C

// Control bits
#define CTRL_ENABLE  (1u << 0)
#define CTRL_RESET   (1u << 1)
#define CTRL_IRQ_EN  (1u << 2)

// Status bits
#define STATUS_BUSY_BIT       (1u << 0)
#define STATUS_RING_EMPTY_BIT (1u << 1)
#define STATUS_ERROR_BIT      (1u << 2)

// IRQ bits
#define IRQ_EMPTY_BIT (1u << 0)
#define IRQ_ERROR_BIT (1u << 1)

// Direction flags
#define DIR_SRAM_TO_SYSMEM 0u
#define DIR_SYSMEM_TO_SRAM 1u

#define REG_WRITE(offset, val) Xil_Out32(MEM_ACCESS_CTRL_BASE + (offset), (val))
#define REG_READ(offset) Xil_In32(MEM_ACCESS_CTRL_BASE + (offset))

// State machine for UART parsing
typedef enum {
    STATE_WAIT_SYNC,
    STATE_READ_HEADER,
    STATE_READ_PAYLOAD,
    STATE_PROCESS
} ParserState;

// Test result structure
typedef struct {
    u8 test_id;
    u8 passed;
    u32 expected;
    u32 got;
} TestResult;

// Blocking UART I/O
u8 uart_read_byte() {
    while (XUartLite_IsReceiveEmpty(UART_BASEADDR));
    return XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
}

void uart_write_byte(u8 data) {
    while (XUartLite_IsTransmitFull(UART_BASEADDR));
    XUartLite_WriteReg(UART_BASEADDR, XUL_TX_FIFO_OFFSET, data);
}

void uart_write_u32(u32 data) {
    uart_write_byte((u8)(data & 0xFF));
    uart_write_byte((u8)((data >> 8) & 0xFF));
    uart_write_byte((u8)((data >> 16) & 0xFF));
    uart_write_byte((u8)((data >> 24) & 0xFF));
}

u32 uart_read_u32() {
    u32 val = 0;
    val |= (u32)uart_read_byte();
    val |= ((u32)uart_read_byte() << 8);
    val |= ((u32)uart_read_byte() << 16);
    val |= ((u32)uart_read_byte() << 24);
    return val;
}

void send_ack(u8 ack_type) {
    uart_write_u32(PACKET_SYNC_WORD);
    uart_write_byte(ack_type);
}

// Memory access helpers
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

// DMA wait function
int wait_for_dma_done(u32 timeout) {
    while (timeout--) {
        u32 status = csr_read(CSR_STATUS_OFF);
        if (status & STATUS_ERROR_BIT) {
            return 0;
        }
        if (((status & STATUS_RING_EMPTY_BIT) != 0u) && ((status & STATUS_BUSY_BIT) == 0u)) {
            return 1;
        }
    }
    return 0;
}

// Reset DMA
void reset_dma(void) {
    csr_write(CSR_CTRL_OFF, CTRL_RESET);
    csr_write(CSR_CTRL_OFF, 0);
}

// Send test result over UART
void send_test_result(u8 test_id, u8 passed, u32 expected, u32 got) {
    uart_write_u32(PACKET_SYNC_WORD);
    uart_write_byte(CMD_REQ_RESULTS);
    uart_write_byte(test_id);
    uart_write_byte(passed);
    uart_write_u32(expected);
    uart_write_u32(got);
}

// ==============================================================================
// TEST IMPLEMENTATIONS
// ==============================================================================

// Test 1: Basic SRAM to SysMem
void test_1_basic_sram_to_sysmem() {
    reset_dma();
    
    const u32 ring_base = 0x20;
    const u32 desc_src = 0x30;
    const u32 desc_dst = 0x40;
    const u32 desc_len = 1;
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    const u32 expected_data = 0xCAFE1234;
    
    sram_write(desc_src, expected_data);
    
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(1, 0, expected_data, 0xDEADBEEF);
        return;
    }
    
    u32 got = sysmem_read(desc_dst);
    send_test_result(1, (got == expected_data), expected_data, got);
}

// Test 2: SysMem to SRAM
void test_2_sysmem_to_sram() {
    reset_dma();
    
    const u32 ring_base = 0x50;
    const u32 desc_src = 0x60;
    const u32 desc_dst = 0x70;
    const u32 desc_len = 1;
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    const u32 expected_data = 0xDEADBEEF;
    
    sysmem_write(desc_src, expected_data);
    
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SYSMEM_TO_SRAM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(2, 0, expected_data, 0xDEADBEEF);
        return;
    }
    
    u32 got = sram_read(desc_dst);
    send_test_result(2, (got == expected_data), expected_data, got);
}

// Test 3: Multiple Descriptors
void test_3_multiple_descriptors() {
    reset_dma();
    
    const u32 ring_base = 0x80;
    const u32 ring_len = 4;
    const u32 desc_size = 0x10;
    
    const u32 desc1_src = 0x100;
    const u32 desc1_dst = 0x110;
    const u32 data1 = 0x11111111;
    
    const u32 desc2_src = 0x120;
    const u32 desc2_dst = 0x130;
    const u32 data2 = 0x22222222;
    
    const u32 desc3_src = 0x140;
    const u32 desc3_dst = 0x150;
    const u32 data3 = 0x33333333;
    
    sram_write(desc1_src, data1);
    sram_write(desc2_src, data2);
    sram_write(desc3_src, data3);
    
    sysmem_write(ring_base + 0x00, desc1_src);
    sysmem_write(ring_base + 0x04, desc1_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    sysmem_write(ring_base + desc_size + 0x00, desc2_src);
    sysmem_write(ring_base + desc_size + 0x04, desc2_dst);
    sysmem_write(ring_base + desc_size + 0x08, 1);
    sysmem_write(ring_base + desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    sysmem_write(ring_base + 2*desc_size + 0x00, desc3_src);
    sysmem_write(ring_base + 2*desc_size + 0x04, desc3_dst);
    sysmem_write(ring_base + 2*desc_size + 0x08, 1);
    sysmem_write(ring_base + 2*desc_size + 0x0C, DIR_SRAM_TO_SYSMEM);
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 3);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(3, 0, data1, 0);
        return;
    }
    
    u32 got1 = sysmem_read(desc1_dst);
    u32 got2 = sysmem_read(desc2_dst);
    u32 got3 = sysmem_read(desc3_dst);
    
    u8 all_pass = (got1 == data1) && (got2 == data2) && (got3 == data3);
    send_test_result(3, all_pass, data1, got1);
}

// Test 4: Ring Wrapping
void test_4_ring_wrapping() {
    reset_dma();
    
    const u32 ring_base = 0x200;
    const u32 ring_len = 3;
    const u32 desc_size = 0x10;
    
    const u32 data_pattern[] = {0x11223344, 0x55667788, 0x99AABBCC};
    const u32 src_bases[] = {0x300, 0x310, 0x320};
    const u32 dst_bases[] = {0x400, 0x410, 0x420};
    
    for (int i = 0; i < 3; i++) {
        sram_write(src_bases[i], data_pattern[i]);
    }
    
    for (int i = 0; i < 3; i++) {
        u32 offset = ring_base + i * desc_size;
        sysmem_write(offset + 0x00, src_bases[i]);
        sysmem_write(offset + 0x04, dst_bases[i]);
        sysmem_write(offset + 0x08, 1);
        sysmem_write(offset + 0x0C, DIR_SRAM_TO_SYSMEM);
    }
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 0);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    csr_write(CSR_TAIL_OFF, 1);
    
    u32 wait_count = 100000;
    while (wait_count--) {
        u32 head = csr_read(CSR_HEAD_OFF);
        u32 status = csr_read(CSR_STATUS_OFF);
        if ((head >= 1) && ((status & STATUS_BUSY_BIT) == 0u)) {
            break;
        }
    }
    
    csr_write(CSR_TAIL_OFF, 2);
    csr_write(CSR_TAIL_OFF, 0);
    csr_write(CSR_TAIL_OFF, 1);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(4, 0, data_pattern[0], 0);
        return;
    }
    
    u32 got0 = sysmem_read(dst_bases[0]);
    u32 got1 = sysmem_read(dst_bases[1]);
    u32 got2 = sysmem_read(dst_bases[2]);
    
    u8 all_pass = (got0 == data_pattern[0]) && (got1 == data_pattern[1]) && (got2 == data_pattern[2]);
    send_test_result(4, all_pass, data_pattern[0], got0);
}

// Test 5: Large Burst
void test_5_large_burst() {
    reset_dma();
    
    const u32 ring_base = 0x500;
    const u32 desc_src = 0x600;
    const u32 desc_dst = 0x700;
    const u32 desc_len = 4;
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;
    
    const u32 data_values[] = {0xAAAA0000, 0xBBBB1111, 0xCCCC2222, 0xDDDD3333};
    
    for (int i = 0; i < 4; i++) {
        sram_write(desc_src + (i * 4), data_values[i]);
    }
    
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, tail_after_enqueue);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(5, 0, data_values[0], 0);
        return;
    }
    
    u8 all_pass = 1;
    u32 first_mismatch = 0;
    for (int i = 0; i < 4; i++) {
        u32 got = sysmem_read(desc_dst + (i * 4));
        if (got != data_values[i]) {
            all_pass = 0;
            first_mismatch = got;
            break;
        }
    }
    
    send_test_result(5, all_pass, data_values[0], first_mismatch);
}

// Test 6: Data Patterns
void test_6_data_patterns() {
    reset_dma();
    
    const u32 ring_base = 0x800;
    const u32 ring_len = 5;
    const u32 desc_size = 0x10;
    
    const u32 patterns[] = {0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555, 0x12345678};
    const u32 src_bases[] = {0x900, 0x910, 0x920, 0x930, 0x940};
    const u32 dst_bases[] = {0x950, 0x960, 0x970, 0x980, 0x990};
    
    for (int i = 0; i < 5; i++) {
        sram_write(src_bases[i], patterns[i]);
    }
    
    for (int i = 0; i < 5; i++) {
        u32 offset = ring_base + i * desc_size;
        sysmem_write(offset + 0x00, src_bases[i]);
        sysmem_write(offset + 0x04, dst_bases[i]);
        sysmem_write(offset + 0x08, 1);
        sysmem_write(offset + 0x0C, DIR_SRAM_TO_SYSMEM);
    }
    
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    csr_write(CSR_TAIL_OFF, 5);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(6, 0, patterns[0], 0);
        return;
    }
    
    u8 all_pass = 1;
    u32 first_mismatch = 0;
    for (int i = 0; i < 5; i++) {
        u32 got = sysmem_read(dst_bases[i]);
        if (got != patterns[i]) {
            all_pass = 0;
            first_mismatch = got;
            break;
        }
    }
    
    send_test_result(6, all_pass, patterns[0], first_mismatch);
}

// Test 7: Status and IRQ
void test_7_status_and_irq() {
    reset_dma();
    
    const u32 ring_base = 0xA00;
    const u32 desc_src = 0xB00;
    const u32 desc_dst = 0xB10;
    const u32 ring_len = 2;
    const u32 data = 0xABCDEF00;
    
    sram_write(desc_src, data);
    
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, 1);
    sysmem_write(ring_base + 0x0C, DIR_SRAM_TO_SYSMEM);
    REG_WRITE(REG_INIT_DONE, 1);
    
    csr_write(CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    csr_write(CSR_BASEADDR_OFF, ring_base);
    csr_write(CSR_RINGLEN_OFF, ring_len);
    
    u32 status_before = csr_read(CSR_STATUS_OFF);
    
    csr_write(CSR_TAIL_OFF, 1);
    csr_write(CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);
    
    if (!wait_for_dma_done(1000000)) {
        send_test_result(7, 0, status_before, 0xDEAD);
        return;
    }
    
    u32 status_after = csr_read(CSR_STATUS_OFF);
    u32 irq_status = csr_read(CSR_IRQ_STATUS_OFF);
    u32 head = csr_read(CSR_HEAD_OFF);
    u32 tail = csr_read(CSR_TAIL_OFF);
    
    u8 status_check = ((status_after & STATUS_RING_EMPTY_BIT) != 0u) && 
                      ((status_after & STATUS_ERROR_BIT) == 0u) &&
                      ((irq_status & IRQ_EMPTY_BIT) != 0u) &&
                      (head == tail);
    
    send_test_result(7, status_check, status_before, status_after);
}

// Test 8: Back-to-Back
void test_8_back_to_back() {
    reset_dma();
    
    const u32 ring_base = 0xC00;
    const u32 ring_len = 2;
    const u32 desc1_src = 0xD00;
    const u32 desc1_dst = 0xD10;
    const u32 data1 = 0x11223344;
    
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
        send_test_result(8, 0, data1, 0);
        return;
    }
    
    u32 got1 = sysmem_read(desc1_dst);
    
    // Second transfer
    reset_dma();
    
    const u32 desc2_src = 0xE00;
    const u32 desc2_dst = 0xE10;
    const u32 data2 = 0x55667788;
    
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
        send_test_result(8, 0, data2, 0);
        return;
    }
    
    u32 got2 = sysmem_read(desc2_dst);
    
    u8 both_pass = (got1 == data1) && (got2 == data2);
    send_test_result(8, both_pass, data1, got1);
}

// ==============================================================================
// COMMAND PROCESSOR
// ==============================================================================

void process_command(u8 opcode, u32 dest_addr, u32 payload_len, u8* payload_buf) {
    if (opcode == CMD_WRITE_CSR) {
        if (payload_len == 4) {
            u32 val = ((u32)payload_buf[0]) | ((u32)payload_buf[1] << 8) | 
                      ((u32)payload_buf[2] << 16) | ((u32)payload_buf[3] << 24);
            csr_write(dest_addr, val);
        }
        xil_printf("Wrote CSR 0x%08x\r\n", dest_addr);
        send_ack(CMD_ACK);
    } 
    else if (opcode == CMD_RUN_DMA) {
        xil_printf("Running all tests...\r\n");
        
        test_1_basic_sram_to_sysmem();
        test_2_sysmem_to_sram();
        test_3_multiple_descriptors();
        test_4_ring_wrapping();
        test_5_large_burst();
        test_6_data_patterns();
        test_7_status_and_irq();
        test_8_back_to_back();
        
        send_ack(CMD_ACK);
    }
    else if (opcode == CMD_WRITE_SRAM) {
        if (payload_len == 4) {
            u32 val = ((u32)payload_buf[0]) | ((u32)payload_buf[1] << 8) | 
                      ((u32)payload_buf[2] << 16) | ((u32)payload_buf[3] << 24);
            sram_write(dest_addr, val);
        }
        xil_printf("Wrote SRAM 0x%08x\r\n", dest_addr);
        send_ack(CMD_ACK);
    }
    else if (opcode == CMD_WRITE_SYSMEM) {
        if (payload_len == 4) {
            u32 val = ((u32)payload_buf[0]) | ((u32)payload_buf[1] << 8) | 
                      ((u32)payload_buf[2] << 16) | ((u32)payload_buf[3] << 24);
            sysmem_write(dest_addr, val);
        }
        xil_printf("Wrote SysMem 0x%08x\r\n", dest_addr);
        send_ack(CMD_ACK);
    }
    else if (opcode == CMD_READ_SRAM) {
        u32 val = sram_read(dest_addr);
        xil_printf("Read SRAM 0x%08x = 0x%08x\r\n", dest_addr, val);
        send_ack(CMD_ACK);
        uart_write_u32(val);
    }
    else if (opcode == CMD_READ_SYSMEM) {
        u32 val = sysmem_read(dest_addr);
        xil_printf("Read SysMem 0x%08x = 0x%08x\r\n", dest_addr, val);
        send_ack(CMD_ACK);
        uart_write_u32(val);
    }
    else {
        send_ack(CMD_NACK);
    }
}

// ==============================================================================
// MAIN
// ==============================================================================

int main(void) {
    xil_printf("DMA Engine Comprehensive Test Suite Ready.\r\n");
    xil_printf("Waiting for test commands over UART...\r\n");

    ParserState state = STATE_WAIT_SYNC;
    u32 sync_buffer = 0;
    
    u8  opcode = 0;
    u32 dest_addr = 0;
    u32 payload_len = 0;
    u8  payload_buf[1024];

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
                for (u32 i = 0; i < payload_len; i++) {
                    u8 data = uart_read_byte();
                    if (i < sizeof(payload_buf)) {
                        payload_buf[i] = data;
                    }
                }
                state = STATE_PROCESS;
                break;

            case STATE_PROCESS:
                process_command(opcode, dest_addr, payload_len, payload_buf);
                
                // Reset for next packet
                sync_buffer = 0;
                state = STATE_WAIT_SYNC;
                break;
        }
    }

    return 0;
}
