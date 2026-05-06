#include "xil_printf.h"
#include "xil_io.h"

// Test read and write to sram and sysmem from microblaze

// Replace with the base address from Vivado Address Editor
#define MEM_ACCESS_CTRL_BASE  0x60000000

// Register offsets (from mem_access_ctrl.sv)
#define REG_INIT_ADDR  0x00
#define REG_INIT_DATA  0x04
#define REG_SRAM_WR    0x08
#define REG_SRAM_RD    0x0C
#define REG_MEM_WR     0x10
#define REG_MEM_RD     0x14
#define REG_RDATA      0x18
#define REG_INIT_DONE  0x1C

#define REG_WRITE(offset, val) \
    Xil_Out32(MEM_ACCESS_CTRL_BASE + (offset), (val))

#define REG_READ(offset) \
    Xil_In32(MEM_ACCESS_CTRL_BASE + (offset))

// Write one word to sys_mem at the given byte address
void sysmem_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_MEM_WR, 1);
}

// Read one word from sys_mem at the given byte address
u32 sysmem_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_MEM_RD, 1);
    return REG_READ(REG_RDATA);
}

int main() {
    xil_printf("=== sys_mem read/write test ===\r\n");

    int pass = 1;
    int num_words = 16;

    // Write phase
    xil_printf("Writing %d words...\r\n", num_words);
    for (int i = 0; i < num_words; i++) {
        u32 byte_addr = i * 4;
        u32 data = 0xA0000000 | i;
        sysmem_write(byte_addr, data);
        xil_printf("  write [0x%08X] = 0x%08X\r\n", byte_addr, data);
    }

    // Read back and verify
    xil_printf("Reading back...\r\n");
    for (int i = 0; i < num_words; i++) {
        u32 byte_addr = i * 4;
        u32 expected = 0xA0000000 | i;
        u32 actual = sysmem_read(byte_addr);

        if (actual == expected) {
            xil_printf("  [0x%08X] PASS: 0x%08X\r\n", byte_addr, actual);
        } else {
            xil_printf("  [0x%08X] FAIL: expected 0x%08X got 0x%08X\r\n",
                       byte_addr, expected, actual);
            pass = 0;
        }
    }

    if (pass)
        xil_printf("=== ALL PASSED ===\r\n");
    else
        xil_printf("=== FAILURES DETECTED ===\r\n");

    return 0;
}
