"""
Descriptor: four 32-bit words packed LSB-first into a 128-bit int (matches Verilog +: order).

Memory layout matches docs/descriptor_struct.md:
  word0 = SRC_ADDR, word1 = DST_ADDR, word2 = LEN, word3 = FLAGS (DIR = FLAGS[0]).
"""

DESC_WORDS = 4
DESC_BITS = DESC_WORDS * 32


class Descriptor:
    def __init__(self, word0, word1, word2, word3):
        self.w0 = word0 & 0xFFFFFFFF
        self.w1 = word1 & 0xFFFFFFFF
        self.w2 = word2 & 0xFFFFFFFF
        self.w3 = word3 & 0xFFFFFFFF

    @classmethod
    def from_packed(cls, packed):
        p = packed & ((1 << DESC_BITS) - 1)
        return cls(
            p & 0xFFFFFFFF,
            (p >> 32) & 0xFFFFFFFF,
            (p >> 64) & 0xFFFFFFFF,
            (p >> 96) & 0xFFFFFFFF,
        )

    def pack(self):
        return (
            self.w0
            | (self.w1 << 32)
            | (self.w2 << 64)
            | (self.w3 << 96)
        ) & ((1 << DESC_BITS) - 1)

    def __repr__(self):
        return "Descriptor(w0=%#010x, w1=%#010x, w2=%#010x, w3=%#010x)" % (
            self.w0,
            self.w1,
            self.w2,
            self.w3,
        )


class descriptor(Descriptor):
    """Legacy alias."""

    def __init__(self, start_address=0, burst_length=0, datasize=0):
        Descriptor.__init__(
            self,
            start_address & 0xFFFFFFFF,
            burst_length & 0xFFFFFFFF,
            datasize & 0xFFFFFFFF,
            0,
        )
