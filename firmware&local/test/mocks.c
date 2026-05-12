#include <setjmp.h>
#include <stdint.h>
#include <string.h>

#include "xil_types.h"
#include "xuartlite_l.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "protocol.h"
#include "mocks.h"

#define RX_CAP        4096
#define TX_CAP        4096
#define MMIO_LOG_CAP  256
#define MMIO_MEM_CAP  256
#define READ_SEQ_CAP  16
#define BACKING_WORDS 2048

static uint8_t rx_buf[RX_CAP];
static int     rx_head;
static int     rx_tail;

static uint8_t tx_buf_storage[TX_CAP];
static int     tx_len_storage;

mmio_op_t mmio_log[MMIO_LOG_CAP];
int       mmio_log_len;

typedef struct { uint32_t addr; uint32_t val; int valid; } mmio_cell_t;
static mmio_cell_t mmio_mem[MMIO_MEM_CAP];

static int      read_seq_active;
static uint32_t read_seq_addr;
static uint32_t read_seq_vals[READ_SEQ_CAP];
static int      read_seq_len;
static int      read_seq_idx;

/* mem_access_ctrl shim simulation. */
static uint32_t sram_words[BACKING_WORDS];
static uint32_t sysmem_words[BACKING_WORDS];
static uint32_t shim_init_addr;
static uint32_t shim_init_data;
static uint32_t shim_rdata;

jmp_buf rx_starved_jmp;
int     rx_starved_armed;

void mocks_reset(void) {
    rx_head = rx_tail = 0;
    tx_len_storage = 0;
    mmio_log_len = 0;
    memset(mmio_mem,    0, sizeof(mmio_mem));
    rx_starved_armed = 0;
    read_seq_active = 0;
    read_seq_idx = 0;
    read_seq_len = 0;
    memset(sram_words,    0, sizeof(sram_words));
    memset(sysmem_words,  0, sizeof(sysmem_words));
    shim_init_addr = 0;
    shim_init_data = 0;
    shim_rdata     = 0;
}

void mock_rx_push_byte(uint8_t b) {
    if (rx_tail - rx_head < RX_CAP) {
        rx_buf[rx_tail++ % RX_CAP] = b;
    }
}

void mock_rx_push_bytes(const uint8_t *bytes, int n) {
    for (int i = 0; i < n; i++) mock_rx_push_byte(bytes[i]);
}

int mock_rx_empty(void) { return rx_head == rx_tail; }

const uint8_t* mock_tx_buf(void) { return tx_buf_storage; }
int            mock_tx_len(void) { return tx_len_storage; }

void mock_mmio_preset(uint32_t addr, uint32_t val) {
    for (int i = 0; i < MMIO_MEM_CAP; i++) {
        if (mmio_mem[i].valid && mmio_mem[i].addr == addr) {
            mmio_mem[i].val = val;
            return;
        }
        if (!mmio_mem[i].valid) {
            mmio_mem[i].addr  = addr;
            mmio_mem[i].val   = val;
            mmio_mem[i].valid = 1;
            return;
        }
    }
}

void mock_set_read_sequence(uint32_t addr, const uint32_t *vals, int n) {
    if (n > READ_SEQ_CAP) n = READ_SEQ_CAP;
    read_seq_active = 1;
    read_seq_addr   = addr;
    read_seq_len    = n;
    read_seq_idx    = 0;
    for (int i = 0; i < n; i++) read_seq_vals[i] = vals[i];
}

void mock_set_sram_word(uint32_t byte_addr, uint32_t val) {
    uint32_t idx = byte_addr / 4;
    if (idx < BACKING_WORDS) sram_words[idx] = val;
}

void mock_set_sysmem_word(uint32_t byte_addr, uint32_t val) {
    uint32_t idx = byte_addr / 4;
    if (idx < BACKING_WORDS) sysmem_words[idx] = val;
}

uint32_t mock_get_sram_word(uint32_t byte_addr) {
    uint32_t idx = byte_addr / 4;
    return (idx < BACKING_WORDS) ? sram_words[idx] : 0;
}

uint32_t mock_get_sysmem_word(uint32_t byte_addr) {
    uint32_t idx = byte_addr / 4;
    return (idx < BACKING_WORDS) ? sysmem_words[idx] : 0;
}

/* --- Xilinx HAL stubs --- */

int XUartLite_IsReceiveEmpty(unsigned long base) {
    (void)base;
    if (mock_rx_empty()) {
        if (rx_starved_armed) longjmp(rx_starved_jmp, 1);
        return 1;
    }
    return 0;
}

int XUartLite_IsTransmitFull(unsigned long base) {
    (void)base;
    return 0;
}

u32 XUartLite_ReadReg(unsigned long base, unsigned long offset) {
    (void)base; (void)offset;
    if (mock_rx_empty()) {
        if (rx_starved_armed) longjmp(rx_starved_jmp, 1);
        return 0;
    }
    return rx_buf[rx_head++ % RX_CAP];
}

void XUartLite_WriteReg(unsigned long base, unsigned long offset, u32 data) {
    (void)base;
    if (offset == XUL_TX_FIFO_OFFSET && tx_len_storage < TX_CAP) {
        tx_buf_storage[tx_len_storage++] = (uint8_t)data;
    }
}

void Xil_Out32(unsigned long addr, u32 data) {
    if (mmio_log_len < MMIO_LOG_CAP) {
        mmio_log[mmio_log_len].is_write = 1;
        mmio_log[mmio_log_len].addr     = (uint32_t)addr;
        mmio_log[mmio_log_len].val      = data;
        mmio_log_len++;
    }

    /* mem_access_ctrl shim emulation. */
    if (addr == MEM_ACCESS_CTRL_BASE + REG_INIT_ADDR) { shim_init_addr = data; return; }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_INIT_DATA) { shim_init_data = data; return; }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_SRAM_WR) {
        if (data) {
            uint32_t idx = shim_init_addr / 4;
            if (idx < BACKING_WORDS) sram_words[idx] = shim_init_data;
        }
        return;
    }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_MEM_WR) {
        if (data) {
            uint32_t idx = shim_init_addr / 4;
            if (idx < BACKING_WORDS) sysmem_words[idx] = shim_init_data;
        }
        return;
    }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_SRAM_RD) {
        if (data) {
            uint32_t idx = shim_init_addr / 4;
            shim_rdata = (idx < BACKING_WORDS) ? sram_words[idx] : 0;
        }
        return;
    }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_MEM_RD) {
        if (data) {
            uint32_t idx = shim_init_addr / 4;
            shim_rdata = (idx < BACKING_WORDS) ? sysmem_words[idx] : 0;
        }
        return;
    }
    if (addr == MEM_ACCESS_CTRL_BASE + REG_INIT_DONE) {
        return;  /* tracked via mmio_log */
    }

    /* Generic MMIO map (CSR, etc.). */
    for (int i = 0; i < MMIO_MEM_CAP; i++) {
        if (mmio_mem[i].valid && mmio_mem[i].addr == addr) {
            mmio_mem[i].val = data;
            return;
        }
        if (!mmio_mem[i].valid) {
            mmio_mem[i].addr  = addr;
            mmio_mem[i].val   = data;
            mmio_mem[i].valid = 1;
            return;
        }
    }
}

u32 Xil_In32(unsigned long addr) {
    uint32_t val = 0;

    if (addr == MEM_ACCESS_CTRL_BASE + REG_RDATA) {
        val = shim_rdata;
    }
    else if (read_seq_active && addr == read_seq_addr) {
        int idx = (read_seq_idx < read_seq_len) ? read_seq_idx : (read_seq_len - 1);
        val = read_seq_vals[idx];
        if (read_seq_idx < read_seq_len) read_seq_idx++;
    }
    else {
        for (int i = 0; i < MMIO_MEM_CAP; i++) {
            if (mmio_mem[i].valid && mmio_mem[i].addr == addr) {
                val = mmio_mem[i].val;
                break;
            }
        }
    }

    if (mmio_log_len < MMIO_LOG_CAP) {
        mmio_log[mmio_log_len].is_write = 0;
        mmio_log[mmio_log_len].addr     = (uint32_t)addr;
        mmio_log[mmio_log_len].val      = val;
        mmio_log_len++;
    }
    return val;
}

/* No-op printf so firmware debug strings don't pollute the protocol TX during
 * tests. The host's sync scanner handles ASCII pollution on the real wire. */
int xil_printf(const char *fmt, ...) {
    (void)fmt;
    return 0;
}
