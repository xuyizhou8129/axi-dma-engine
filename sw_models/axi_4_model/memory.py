import struct

class SystemMemory:
    def __init__(self, size_bytes: int):
        self.size = size_bytes
        # 32-bit word array
        self.mem = [0] * (size_bytes // 4)

    def read_word(self, byte_addr: int):
        if byte_addr % 4 != 0:
            raise ValueError("Memory: Unaligned read")
        idx = byte_addr // 4
        if idx >= len(self.mem) or idx < 0:
            raise ValueError("Memory: read out of bounds")
        return self.mem[idx]

    def write_word(self, byte_addr: int, word32: int):
        if byte_addr % 4 != 0:
            raise ValueError("Memory: Unaligned write")
        idx = byte_addr // 4
        if idx >= len(self.mem) or idx < 0:
            raise ValueError("Memory: write out of bounds")
        self.mem[idx] = word32 & 0xFFFFFFFF


class SRAMController:
    # Mimics SRAM memory array + controller logic
    def __init__(self, size_bytes: int):
        self.size = size_bytes
        self.mem = [0] * (size_bytes // 4)

    def process_instruction(self, instruction, data_mover_fifo_rx=None, data_mover_fifo_tx=None):
        base_addr = instruction.base_address
        length = instruction.burst_size

        if instruction.is_read:
            # We are reading from SRAM and sending into Data Mover tx
            for i in range(length):
                addr = base_addr + (i * 4)
                idx = addr // 4
                val = self.mem[idx]
                data_mover_fifo_rx.enqueue(val)
        else:
            # We are writing to SRAM from Data Mover rx
            for i in range(length):
                addr = base_addr + (i * 4)
                idx = addr // 4
                val = data_mover_fifo_tx.dequeue()
                self.mem[idx] = val & 0xFFFFFFFF
