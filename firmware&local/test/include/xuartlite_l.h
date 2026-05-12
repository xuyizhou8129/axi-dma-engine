#ifndef XUARTLITE_L_H
#define XUARTLITE_L_H

#include "xil_types.h"

#define XUL_RX_FIFO_OFFSET    0x00
#define XUL_TX_FIFO_OFFSET    0x04
#define XUL_STATUS_REG_OFFSET 0x08

int  XUartLite_IsReceiveEmpty(unsigned long base);
int  XUartLite_IsTransmitFull(unsigned long base);
u32  XUartLite_ReadReg(unsigned long base, unsigned long offset);
void XUartLite_WriteReg(unsigned long base, unsigned long offset, u32 data);

#endif
