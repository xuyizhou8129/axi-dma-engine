import serial
import struct
import time
import sys
import os
import zlib

# Firmware Protocol Definitions matches protocol.h
PACKET_SYNC_WORD  = 0xDEADBEEF
CMD_WRITE_SRAM    = 0x01
CMD_WRITE_SYSMEM  = 0x02
CMD_WRITE_CSR     = 0x03
CMD_RUN_DMA       = 0x04
CMD_REQ_RESULTS   = 0x05
CMD_READ_SRAM     = 0x06
CMD_READ_SYSMEM   = 0x07
CMD_CRC_SRAM      = 0x08
CMD_CRC_SYSMEM    = 0x09

CMD_ACK           = 0xAA
CMD_NACK          = 0xEE

PORT = 'COM5'
BAUD = 9600

# stim.txt test parameters (must match stim.txt)
STIM_SRC_SYSMEM_ADDR = 0x00000040
STIM_DST_SRAM_ADDR   = 0x00000100
STIM_TRANSFER_WORDS  = 1
STIM_EXPECTED_DATA   = [0xCAFECAFE]


def wait_for_ack(ser):
    """Scan for SYNC word then return True if ACK, False on NACK or timeout."""
    sync_val = 0
    while True:
        b = ser.read(1)
        if not b:
            print("Timeout waiting for ACK")
            return False
        sync_val = ((sync_val >> 8) | (b[0] << 24)) & 0xFFFFFFFF
        if sync_val == PACKET_SYNC_WORD:
            ack = ser.read(1)[0]
            if ack == CMD_ACK:
                return True
            print(f"Received NACK: {hex(ack)}")
            return False


def build_packet(opcode, address, payload=bytes()):
    # format: <I (4 byte sync LittleEndian), B (1 byte opcode), I (4 byte addr), I (4 byte length)
    header = struct.pack('<IBII', PACKET_SYNC_WORD, opcode, address, len(payload))
    return header + payload


def read_memory(ser, opcode, addr):
    """Send a single-word read command; return the u32 value or None on failure."""
    ser.write(build_packet(opcode, addr))
    if wait_for_ack(ser):
        data = ser.read(4)
        if len(data) == 4:
            return struct.unpack('<I', data)[0]
        print("  -> FAILED: short read on data bytes")
    return None


def request_crc(ser, opcode, addr, byte_len):
    """Request CRC32 over [addr, addr+byte_len); return u32 CRC or None on failure."""
    payload = struct.pack('<I', byte_len)
    ser.write(build_packet(opcode, addr, payload))
    if wait_for_ack(ser):
        crc_bytes = ser.read(4)
        if len(crc_bytes) == 4:
            return struct.unpack('<I', crc_bytes)[0]
        print("  -> FAILED: short read on CRC bytes")
    return None


def compute_crc32(words):
    """CRC32-IEEE (zlib) of a list of u32s packed little-endian — matches firmware."""
    data = struct.pack('<' + 'I' * len(words), *words)
    return zlib.crc32(data) & 0xFFFFFFFF


def parse_stimulus(filename, ser, csr_base_addr=0x80000000):
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            parts = line.split()
            if parts[0] == 'csr_write':
                offset = int(parts[1], 16)
                value  = int(parts[2], 16)
                addr   = csr_base_addr + offset
                payload = struct.pack('<I', value)

                print(f"Sending CSR Write: Addr {hex(addr)}, Val {hex(value)}")
                ser.write(build_packet(CMD_WRITE_CSR, addr, payload))
                if wait_for_ack(ser):
                    print("  -> ACK'd")
                else:
                    print("  -> FAILED")
                    sys.exit(1)

            elif parts[0] in ('sysmem_write', 'sram_write'):
                addr    = int(parts[1], 16)
                value   = int(parts[2], 16)
                payload = struct.pack('<I', value)
                opcode  = CMD_WRITE_SYSMEM if parts[0] == 'sysmem_write' else CMD_WRITE_SRAM

                print(f"Sending {parts[0]}: Addr {hex(addr)}, Val {hex(value)}")
                ser.write(build_packet(opcode, addr, payload))
                if wait_for_ack(ser):
                    print("  -> ACK'd")
                else:
                    print("  -> FAILED")
                    sys.exit(1)

            elif parts[0] in ('sysmem_read', 'sram_read'):
                addr   = int(parts[1], 16)
                opcode = CMD_READ_SYSMEM if parts[0] == 'sysmem_read' else CMD_READ_SRAM

                print(f"Sending {parts[0]}: Addr {hex(addr)}")
                val = read_memory(ser, opcode, addr)
                if val is not None:
                    print(f"  -> SUCCESS: Read Value = {hex(val)}")
                else:
                    print("  -> FAILED ACK")
                    sys.exit(1)


def verify_dma_result(ser):
    """
    Verify the DMA transfer defined in stim.txt:
      SYSMEM[0x40] (0xCAFECAFE) -> SRAM[0x100]

    Checks:
      1. Single-word readback of SRAM destination.
      2. CRC32 of SRAM destination range vs. Python-computed expected CRC.
      3. CRC32 of SYSMEM source range to confirm source is unchanged.
    """
    expected_crc = compute_crc32(STIM_EXPECTED_DATA)
    byte_len     = STIM_TRANSFER_WORDS * 4
    all_pass     = True

    print("\n--- DMA Verification ---")

    # 1. Readback SRAM destination
    val = read_memory(ser, CMD_READ_SRAM, STIM_DST_SRAM_ADDR)
    if val is None:
        print(f"  [FAIL] SRAM[{hex(STIM_DST_SRAM_ADDR)}]: read failed")
        all_pass = False
    elif val == STIM_EXPECTED_DATA[0]:
        print(f"  [PASS] SRAM[{hex(STIM_DST_SRAM_ADDR)}] = {hex(val)}")
    else:
        print(f"  [FAIL] SRAM[{hex(STIM_DST_SRAM_ADDR)}] = {hex(val)}, expected {hex(STIM_EXPECTED_DATA[0])}")
        all_pass = False

    # 2. CRC check SRAM destination
    fw_crc_dst = request_crc(ser, CMD_CRC_SRAM, STIM_DST_SRAM_ADDR, byte_len)
    if fw_crc_dst is None:
        print(f"  [FAIL] SRAM CRC: request failed")
        all_pass = False
    elif fw_crc_dst == expected_crc:
        print(f"  [PASS] SRAM CRC = {hex(fw_crc_dst)}")
    else:
        print(f"  [FAIL] SRAM CRC = {hex(fw_crc_dst)}, expected {hex(expected_crc)}")
        all_pass = False

    # 3. CRC check SYSMEM source (must be unchanged after DMA)
    fw_crc_src = request_crc(ser, CMD_CRC_SYSMEM, STIM_SRC_SYSMEM_ADDR, byte_len)
    if fw_crc_src is None:
        print(f"  [FAIL] SYSMEM CRC: request failed")
        all_pass = False
    elif fw_crc_src == expected_crc:
        print(f"  [PASS] SYSMEM[{hex(STIM_SRC_SYSMEM_ADDR)}] CRC = {hex(fw_crc_src)} (source intact)")
    else:
        print(f"  [FAIL] SYSMEM[{hex(STIM_SRC_SYSMEM_ADDR)}] CRC = {hex(fw_crc_src)}, expected {hex(expected_crc)}")
        all_pass = False

    print()
    if all_pass:
        print("=== DMA TEST PASSED ===")
    else:
        print("=== DMA TEST FAILED ===")
    return all_pass


def main():
    try:
        ser = serial.Serial(PORT, BAUD, timeout=2)
        print("Connected to FPGA.")
    except Exception as e:
        print(f"Error opening port: {e}")
        return

    # Allow firmware to start up after reset
    time.sleep(1)
    print(ser.read_all().decode(errors='ignore'))

    stim_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stim.txt')
    print(f"Parsing and sending {stim_path}...")
    parse_stimulus(stim_path, ser)

    print("\nSending RUN DMA Command...")
    ser.write(build_packet(CMD_RUN_DMA, 0x00000000))
    if not wait_for_ack(ser):
        print("  -> DMA failed (NACK or timeout)")
        ser.close()
        sys.exit(1)
    print("  -> DMA Trigger ACK'd")

    verify_dma_result(ser)

    ser.close()


if __name__ == '__main__':
    main()
