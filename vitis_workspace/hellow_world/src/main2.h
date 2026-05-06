#ifndef MAIN_H_
#define MAIN_H_

/* Include standard Xilinx libraries */
#include "xparameters.h"  /* Contains all hardware addresses (XPAR_...) */
#include "xgpio.h"        /* Driver for AXI GPIO */
#include "xil_printf.h"   /* Light-weight print for serial terminal */
#include "xil_types.h"    /* Standard types like u32, u16, etc. */

/* * Device IDs: These must match the names in your Vivado Block Design.
 * If you named your GPIO block "axi_gpio_0", the ID is usually:
 * XPAR_AXI_GPIO_0_DEVICE_ID 
 */
#define GPIO_DEVICE_ID  XPAR_GPIO_0_DEVICE_ID 

/* Channel 1 is typically the first interface of a GPIO block */
#define CHANNEL_1       1

/* Bitmask definitions (Example for 4-bit LEDs/Buttons) */
#define MASK_ALL_OUTPUT 0x00  /* 0 = Output */
#define MASK_ALL_INPUT  0xFF  /* 1 = Input  */

/* Function Prototypes */
int  init_hardware(XGpio *GpioInstancePtr);
void run_application_logic(XGpio *GpioInstancePtr);

#endif /* MAIN_H_ */