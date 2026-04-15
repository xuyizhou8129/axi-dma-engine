"""
Local BRAM backing store for sram_controller (software model).

Word-oriented: mem[i] is one 32-bit word, same layout as SystemMemory.
Default depth matches dma_pkg::BRAM_SIZE.
"""

# rtl/dma_pkg.sv
BRAM_SIZE = 1024


class SRAM:
    """Local SRAM/BRAM image used with SRAMController (list of 32-bit words)."""

    def __init__(self, size=None):
        if size is None:
            size = BRAM_SIZE
        if size <= 0:
            raise ValueError("SRAM size must be positive")
        self.size = size
        self.mem = [0] * size
