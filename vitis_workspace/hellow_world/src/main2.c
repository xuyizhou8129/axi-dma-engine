#include "main2.h"

int main() {
    XGpio Gpio; // Instance of the GPIO driver
    int status;

    xil_printf("--- MicroBlaze System Starting ---\r\n");

    /* Step 1: Initialize the Hardware */
    status = init_hardware(&Gpio);
    if (status != XST_SUCCESS) {
        xil_printf("GPIO Initialization Failed!\r\n");
        return XST_FAILURE;
    }

    xil_printf("Hardware Initialized. Entering Main Loop...\r\n");

    /* Step 2: Run Application Logic */
    run_application_logic(&Gpio);

    return 0; // Should never reach here
}

/**
 * @brief  Initializes the AXI GPIO peripheral.
 * @param  GpioInstancePtr Pointer to the driver instance.
 * @return XST_SUCCESS if successful, XST_FAILURE otherwise.
 */
int init_hardware(XGpio *GpioInstancePtr) {
    int status;

    /* Initialize the GPIO driver */
    status = XGpio_Initialize(GpioInstancePtr, GPIO_DEVICE_ID);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /* Set the direction for the pins: 0 for Output, 1 for Input */
    XGpio_SetDataDirection(GpioInstancePtr, CHANNEL_1, MASK_ALL_OUTPUT);

    return XST_SUCCESS;
}

/**
 * @brief  Example logic to toggle LEDs.
 */
void run_application_logic(XGpio *GpioInstancePtr) {
    u32 led_val = 0x01;

    while (1) {
        /* Write value to the GPIO channel */
        XGpio_DiscreteWrite(GpioInstancePtr, CHANNEL_1, led_val);

        /* Print current status to UART */
        xil_printf("LED Value: 0x%02X\r\n", (unsigned int)led_val);

        /* Simple software delay loop (Non-precise) */
        for (volatile int i = 0; i < 1000000; i++);

        /* Rotate bit to the left (Shift) */
        if (led_val == 0x08) {
            led_val = 0x01;
        } else {
            led_val <<= 1;
        }
    }
}