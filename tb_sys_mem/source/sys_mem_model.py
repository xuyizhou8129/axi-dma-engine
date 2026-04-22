"""
sys_mem software model: word-addressed memory backing an AXI4 slave.
Byte address is right-shifted by 2 to get the word index (32-bit words).
"""


class SysMemModel:
    def __init__(self, mem_words=256):
        self.mem_words = mem_words
        self.mem = {}

    def write(self, byte_addr, data):
        word_addr = (byte_addr >> 2) & 0xFFFFFFFF
        if word_addr < self.mem_words:
            self.mem[word_addr] = data & 0xFFFFFFFF

    def read(self, byte_addr):
        word_addr = (byte_addr >> 2) & 0xFFFFFFFF
        if word_addr < self.mem_words:
            return self.mem.get(word_addr, 0)
        return 0

    def read_burst(self, byte_addr, arlen):
        """Return arlen+1 words starting at byte_addr (AXI arlen = beats - 1)."""
        return [self.read(byte_addr + i * 4) for i in range(arlen + 1)]
