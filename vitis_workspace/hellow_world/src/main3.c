#include "xparameters.h"
#include "xuartlite_l.h"
#include "xil_printf.h"

/* 
 * This address depends on your Vivado block design. 
 * XPAR_UARTLITE_0_BASEADDR is the default for an AXI Uartlite IP.
 */
#define UART_BASEADDR XPAR_UARTLITE_0_BASEADDR

int main() {
    /* Print a startup message over UART */
    xil_printf("\r\n--- MicroBlaze Hello-World & UART Test ---\r\n");
    xil_printf("If you see this, the MicroBlaze is running successfully!\r\n");
    xil_printf("Type characters in your serial terminal. The MicroBlaze will echo them back:\r\n");

    /* Infinite loop to test basic processor execution and UART RX/TX */
    while (1) {
        /* Check if there is data in the Receive FIFO */
        if (!XUartLite_IsReceiveEmpty(UART_BASEADDR)) {
            /* Read a byte from UART */
            u8 recv_byte = XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
            
            /* Echo the exact same byte back to the Host */
            XUartLite_WriteReg(UART_BASEADDR, XUL_TX_FIFO_OFFSET, recv_byte);
        }
    }

    return 0;
}
