import serial
import time
import sys

# Change this to match your Arty A7's serial port.
# On Linux, Vivado hardware server often uses ttyUSB0 for JTAG, and ttyUSB1 for UART.
PORT = '/dev/ttyUSB1' 
BAUD = 9600

def main():
    try:
        print(f"Connecting to {PORT} at {BAUD} baud...")
        # Open the serial port
        ser = serial.Serial(PORT, BAUD, timeout=3)
        time.sleep(1) # Brief pause to ensure connection stabilizes

        print("Listening for MicroBlaze startup message...")
        # Try to read the initial banner from main3.c
        startup_msg = ser.read(500) # Read up to 500 bytes
        
        if startup_msg:
            print("--- Received from FPGA ---")
            print(startup_msg.decode('utf-8', errors='ignore'))
            print("--------------------------")
        else:
            print("Warning: Did not receive the expected startup message.")
            print("Make sure the FPGA is programmed and the Vitis application is running.")

        # Test the Echo functionality
        test_string = "Ping MicroBlaze"
        test_bytes = test_string.encode('utf-8')
        
        print(f"\nSending test message: '{test_string}'")
        ser.write(test_bytes)

        # Wait for the echo back
        print("Waiting for echo...")
        # Read exactly the number of bytes we sent
        echoed_bytes = ser.read(len(test_bytes))
        
        if echoed_bytes == test_bytes:
            print(f"SUCCESS! MicroBlaze echoed nicely: '{echoed_bytes.decode('utf-8')}'")
            print("The Microblaze and UART link are working perfectly!")
        else:
            print(f"FAILED! Expected '{test_string}', but got: {echoed_bytes}")

        ser.close()

    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        print("Troubleshooting tips:")
        print("1. Check if the port name is correct (e.g., /dev/ttyUSB0, /dev/ttyUSB1).")
        print("2. Ensure you have read/write access to the port (e.g., 'sudo usermod -a -G dialout $USER').")

if __name__ == '__main__':
    main()
