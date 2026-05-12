#ifndef MOCKS_H
#define MOCKS_H

#include <setjmp.h>
#include <stdint.h>

typedef struct {
    int      is_write;   /* 1 = Xil_Out32, 0 = Xil_In32 */
    uint32_t addr;
    uint32_t val;
} mmio_op_t;

void  mocks_reset(void);

void  mock_rx_push_byte(uint8_t b);
void  mock_rx_push_bytes(const uint8_t *bytes, int n);
int   mock_rx_empty(void);

const uint8_t* mock_tx_buf(void);
int            mock_tx_len(void);

/* Generic AXI MMIO map (CSR, etc.). */
void  mock_mmio_preset(uint32_t addr, uint32_t val);

/* Programmable read sequence for one address (e.g. CSR.STATUS = BUSY, BUSY, 0). */
void  mock_set_read_sequence(uint32_t addr, const uint32_t *vals, int n);

/* mem_access_ctrl shim emulation: SRAM and SYSMEM backing stores. The shim's
 * REG_INIT_ADDR/REG_INIT_DATA + WR/RD strobes route through these arrays so
 * tests can preset memory and read back what the firmware wrote. */
void     mock_set_sram_word(uint32_t byte_addr, uint32_t val);
void     mock_set_sysmem_word(uint32_t byte_addr, uint32_t val);
uint32_t mock_get_sram_word(uint32_t byte_addr);
uint32_t mock_get_sysmem_word(uint32_t byte_addr);

extern jmp_buf rx_starved_jmp;
extern int     rx_starved_armed;

extern mmio_op_t mmio_log[];
extern int       mmio_log_len;

#endif
