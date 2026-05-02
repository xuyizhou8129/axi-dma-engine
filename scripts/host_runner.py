import serial
import struct
import time
import sys

# Firmware Protocol Definitions matches protocol.h
PACKET_SYNC_WORD = 0xDEADBEEF
CMD_WRITE_SRAM   = 0x01
CMD_WRITE_SYSMEM = 0x02
CMD_WRITE_CSR    = 0x03
CMD_RUN_DMA      = 0x04
CMD_REQ_RESULTS  = 0x05

CMD_ACK          = 0xAA
CMD_NACK         = 0xEE

PORT = 'COM5'
BAUD = 9600

# Wait for 5 byte ACK (SYNC + ACK byte)
def wait_for_ack(ser):
    sync_val = 0
    while True:
        # crude sync scanner for ack
        b = ser.read(1)
        if not b:
            print("Timeout waiting for ACK")
            return False
        
        sync_val = ((sync_val >> 8) | (b[0] << 24)) & 0xFFFFFFFF
        if sync_val == PACKET_SYNC_WORD:
            ack = ser.read(1)[0]
            if ack == CMD_ACK:
                return True
            else:
                print(f"Received NACK: {hex(ack)}")
                return False

def build_packet(opcode, address, payload=bytes()):
    # format: <I (4 byte sync LitteEndian), B (1 byte opcode), I (4 byte addr), I (4 byte length)
    header = struct.pack('<IBII', PACKET_SYNC_WORD, opcode, address, len(payload))
    return header + payload

def parse_stimulus(filename, ser, csr_base_addr=0x40000000):
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            parts = line.split()
            if parts[0] == 'csr_write':
                # e.g., csr_write 00 00000000
                offset = int(parts[1], 16)
                value = int(parts[2], 16)
                addr = csr_base_addr + offset
                # 32-bit payload little endian
                payload = struct.pack('<I', value)
                
                print(f"Sending CSR Write: Addr {hex(addr)}, Val {hex(value)}")
                pkt = build_packet(CMD_WRITE_CSR, addr, payload)
                ser.write(pkt)
                
                if wait_for_ack(ser):
                    print("  -> ACK'd")
                else:
                    print("  -> FAILED")
                    sys.exit(1)

def main():
    try:
        ser = serial.Serial(PORT, BAUD, timeout=2)
        print("Connected to FPGA.")
    except Exception as e:
        print(f"Error opening port: {e}")
        return

    # Sleep to allow firmware to startup if reset
    time.sleep(1)
    
    # Optional: Read off the "Firmware Ready" message
    print(ser.read_all().decode(errors='ignore'))

    # Parse and send stim.txt
    print("Parsing and sending stim.txt...")
    parse_stimulus('stim.txt', ser)
    
    # Tell DMA to run
    print("\nSending RUN DMA Command...")
    ser.write(build_packet(CMD_RUN_DMA, 0x00000000))
    if wait_for_ack(ser):
         print("  -> DMA Trigger ACK'd")
         
    ser.close()

if __name__ == '__main__':
    main()