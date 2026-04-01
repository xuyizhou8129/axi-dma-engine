class Descriptor:
    def __init__(self, src_addr: int, dst_addr: int, length: int, flags: int):
        self.src_addr = src_addr
        self.dst_addr = dst_addr
        self.length = length
        self.flags = flags

    @property
    def direction(self):
        # 1 = Sys->SRAM, 0 = SRAM->Sys
        return self.flags & 1

    def __repr__(self):
        return f"Descriptor(src={self.src_addr}, dst={self.dst_addr}, len={self.length}, dir={self.direction})"

class Handle:
    def __init__(self, base_address: int, valid: bool):
        self.base_address = base_address
        self.valid = valid
        self.descriptor_size = 4  # 4 words

    def __repr__(self):
        return f"Handle(addr={self.base_address}, valid={self.valid})"


class Instruction:
    def __init__(self, base_address: int, burst_size: int, is_read: bool, is_sram: bool):
        self.base_address = base_address
        self.burst_size = burst_size
        self.is_read = is_read
        self.is_sram = is_sram # Used internally for tracking purpose

    def __repr__(self):
        t = "Read " if self.is_read else "Write"
        d = "SRAM" if self.is_sram else "AXI4"
        return f"Instruction({t} from {d} @ 0x{self.base_address:X} len={self.burst_size})"
