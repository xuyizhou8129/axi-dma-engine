#include "xil_printf.h"
#include "xil_io.h"

// Test read and write to sram and sysmem from microblaze

// Replace with the base address from Vivado Address Editor
#define MEM_ACCESS_CTRL_BASE  0x60000000
#define CSR_ACCESS_BASE 0x80000000

// Register offsets (from mem_access_ctrl.sv)
#define REG_INIT_ADDR  0x00
#define REG_INIT_DATA  0x04
#define REG_SRAM_WR    0x08
#define REG_SRAM_RD    0x0C
#define REG_MEM_WR     0x10
#define REG_MEM_RD     0x14
#define REG_RDATA      0x18
#define REG_INIT_DONE  0x1C

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


#define HEADER_SIZE 13


//Reg write is only used for sys_mem and sram
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

// Write one word to SRAM at the given byte address
void sram_write(u32 byte_addr, u32 data) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_INIT_DATA, data);
    REG_WRITE(REG_SRAM_WR, 1);
}

// Read one word from SRAM at the given byte address
u32 sram_read(u32 byte_addr) {
    REG_WRITE(REG_INIT_ADDR, byte_addr);
    REG_WRITE(REG_SRAM_RD, 1);
    return REG_READ(REG_RDATA);
}

int main() {
    //Workflow:
    //We first write arbitrary numbers in sys_mem and sram


    // One descriptor in Ring
    // Ring Base: 0X20
    // DIR: SRAM to sys-mem
    // Len = 1
    // Source addr = 0X30
    // Destination addr = 0X30
    
    //Then we write arbitrary values into the CSR

    //Wait for the done 
    
    //Check a specific line in SysMem/SRAM to see if it is expected
    // CSR register offsets (dma_pkg::REG_* in rtl/csr.sv)
    const u32 CSR_BASEADDR_OFF   = 0x00;
    const u32 CSR_RINGLEN_OFF    = 0x04;
    const u32 CSR_HEAD_OFF       = 0x08;
    const u32 CSR_TAIL_OFF       = 0x0C;
    const u32 CSR_CTRL_OFF       = 0x10;
    const u32 CSR_STATUS_OFF     = 0x14;
    const u32 CSR_IRQ_STATUS_OFF = 0x18;
    const u32 CSR_IRQ_CLEAR_OFF  = 0x2C;

    // CTRL bits
    const u32 CTRL_ENABLE = (1u << 0);
    const u32 CTRL_IRQ_EN = (1u << 2);

    // STATUS bits
    const u32 STATUS_BUSY_BIT       = (1u << 0);
    const u32 STATUS_RING_EMPTY_BIT = (1u << 1);
    const u32 STATUS_ERROR_BIT      = (1u << 2);

    // IRQ_STATUS bits
    const u32 IRQ_EMPTY_BIT = (1u << 0);
    const u32 IRQ_ERROR_BIT = (1u << 1);

    // Descriptor/ring setup from the comments above
    const u32 ring_base = 0x20;
    const u32 desc_src  = 0x30;
    const u32 desc_dst  = 0x30;
    const u32 desc_len  = 1;
    const u32 desc_dir  = 0; // 0 = SRAM -> SysMem (docs/descriptor_struct.md)

    // Ring length must be >= 2 to represent one queued descriptor (head != tail)
    const u32 ring_len = 2;
    const u32 tail_after_enqueue = 1;

    const u32 expected_data = 0xCAFE1234;
    const u32 initial_dst_data = 0xDEADBEEF;

    int pass = 1;
    u32 status;
    u32 timeout = 1000000;
    u32 mem_probe_wr, mem_probe_rd;
    u32 csr_probe_wr, csr_probe_rd;

    xil_printf("=== DMA callback workflow test ===\r\n");

    // Early MMIO probe: catches wrong base addresses quickly.
    mem_probe_wr = 0xA5A50020;
    REG_WRITE(REG_INIT_ADDR, mem_probe_wr);
    mem_probe_rd = REG_READ(REG_INIT_ADDR);

    csr_probe_wr = 0x5A5A0020;
    Xil_Out32(CSR_ACCESS_BASE + CSR_BASEADDR_OFF, csr_probe_wr);
    csr_probe_rd = Xil_In32(CSR_ACCESS_BASE + CSR_BASEADDR_OFF);

    xil_printf("MMIO probe mem_access_ctrl: wrote 0x%08X read 0x%08X\r\n", mem_probe_wr, mem_probe_rd);
    xil_printf("MMIO probe csr          : wrote 0x%08X read 0x%08X\r\n", csr_probe_wr, csr_probe_rd);

    if ((mem_probe_rd != mem_probe_wr) || (csr_probe_rd != csr_probe_wr)) {
        xil_printf("MMIO mapping mismatch. Check MEM_ACCESS_CTRL_BASE/CSR_ACCESS_BASE against Vivado Address Editor and BSP xparameters.h\r\n");
        return 1;
    }

    // 1) Write arbitrary numbers in sys_mem and sram
    sram_write(desc_src, expected_data);
    sysmem_write(desc_dst, initial_dst_data);
    xil_printf("Init SRAM[0x%08X]=0x%08X, SYSMEM[0x%08X]=0x%08X\r\n",
               desc_src, expected_data, desc_dst, initial_dst_data);

    // 2) One descriptor in ring at base 0x20
    //    [0x00]=SRC, [0x04]=DST, [0x08]=LEN, [0x0C]=FLAGS(DIR)
    sysmem_write(ring_base + 0x00, desc_src);
    sysmem_write(ring_base + 0x04, desc_dst);
    sysmem_write(ring_base + 0x08, desc_len);
    sysmem_write(ring_base + 0x0C, desc_dir);
    REG_WRITE(REG_INIT_DONE, 1);

    xil_printf("Descriptor @0x%08X: SRC=0x%08X DST=0x%08X LEN=%u DIR=%u\r\n",
               ring_base, desc_src, desc_dst, desc_len, desc_dir);
    xil_printf("INIT_DONE asserted\r\n");

    // 3) Program CSR and kick DMA
    Xil_Out32(CSR_ACCESS_BASE + CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);
    Xil_Out32(CSR_ACCESS_BASE + CSR_BASEADDR_OFF, ring_base);
    Xil_Out32(CSR_ACCESS_BASE + CSR_RINGLEN_OFF, ring_len);
    Xil_Out32(CSR_ACCESS_BASE + CSR_TAIL_OFF, tail_after_enqueue);
    Xil_Out32(CSR_ACCESS_BASE + CSR_CTRL_OFF, CTRL_ENABLE | CTRL_IRQ_EN);

    xil_printf("CSR: BASE=0x%08X RINGLEN=%u TAIL=%u CTRL=0x%08X\r\n",
               ring_base, ring_len, tail_after_enqueue, CTRL_ENABLE | CTRL_IRQ_EN);

    // 4) Wait for done (ring empty and not busy), or stop on error/timeout
    while (timeout--) {
        status = Xil_In32(CSR_ACCESS_BASE + CSR_STATUS_OFF);
        if (status & STATUS_ERROR_BIT) {
            xil_printf("DMA ERROR: STATUS=0x%08X IRQ_STATUS=0x%08X\r\n",
                       status, Xil_In32(CSR_ACCESS_BASE + CSR_IRQ_STATUS_OFF));
            pass = 0;
            break;
        }
        if (((status & STATUS_RING_EMPTY_BIT) != 0u) && ((status & STATUS_BUSY_BIT) == 0u)) {
            break;
        }
    }

    if (timeout == 0) {
        xil_printf("TIMEOUT waiting for DMA done. STATUS=0x%08X HEAD=%u TAIL=%u\r\n",
                   Xil_In32(CSR_ACCESS_BASE + CSR_STATUS_OFF),
                   Xil_In32(CSR_ACCESS_BASE + CSR_HEAD_OFF),
                   Xil_In32(CSR_ACCESS_BASE + CSR_TAIL_OFF));
        pass = 0;
    }

    // 5) Verify destination data
    {
        u32 got = sysmem_read(desc_dst);
        if (got != expected_data) {
            xil_printf("FAIL: SYSMEM[0x%08X] expected 0x%08X got 0x%08X\r\n",
                       desc_dst, expected_data, got);
            pass = 0;
        } else {
            xil_printf("PASS: SYSMEM[0x%08X] = 0x%08X\r\n", desc_dst, got);
        }
    }

    // Optional: clear latched IRQ bits
    Xil_Out32(CSR_ACCESS_BASE + CSR_IRQ_CLEAR_OFF, IRQ_EMPTY_BIT | IRQ_ERROR_BIT);

    if (pass)
        xil_printf("=== TEST PASSED ===\r\n");
    else
        xil_printf("=== TEST FAILED ===\r\n");

    return pass ? 0 : 1;
}