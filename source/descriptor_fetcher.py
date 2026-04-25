"""
Descriptor Fetcher (software model): pushes a handle into the DF→AXI FIFO; the
AXI4 master reads the descriptor from system memory and pushes the packed
128-bit descriptor into the AXI→DF callback FIFO.

Mirrors rtl/descriptor_fetcher.sv error handling: every descriptor that comes
back from the AXI read is bounds-checked against MAX_SRAM_ADDR. A bad
descriptor is dropped (never forwarded to the data mover) and a one-shot
df_error pulse is reported to the ring manager.
"""

from fifo_queue import FIFOQueue
from descriptor import Descriptor
from axi_4_master import pack_handle


# Matches dma_pkg::MAX_SRAM_ADDR (2**16 - 1, 64 KiW).
MAX_SRAM_ADDR = (1 << 16) - 1


class DescriptorFetcher:
    def __init__(self, fifo_handle_to_axi: FIFOQueue, fifo_desc_from_axi: FIFOQueue):
        self.fifo_handle_to_axi = fifo_handle_to_axi
        self.fifo_desc_from_axi = fifo_desc_from_axi

    def submit_handle(self, byte_addr, len_beats):
        """Enqueue one handle (one FIFO beat) for the AXI master to fetch a descriptor burst."""
        self.fifo_handle_to_axi.enqueue(pack_handle(byte_addr, len_beats))

    def has_descriptor(self):
        return not self.fifo_desc_from_axi.is_empty()

    def take_descriptor(self):
        """Pop one completed descriptor from the callback FIFO."""
        packed = self.fifo_desc_from_axi.dequeue()
        return Descriptor.from_packed(packed)

    @staticmethod
    def is_descriptor_valid(desc):
        """
        Mirror rtl/descriptor_fetcher.sv SRAM-bounds check.

          dir_bit        = w3[0]                       (1: sys mem -> SRAM)
          sram_byte_addr = dir_bit ? DST_ADDR : SRC_ADDR
          sram_word_idx  = sram_byte_addr >> 2
          len_beats      = LEN[7:0]
          desc_end_addr  = (len == 0) ? sram_word_idx
                                      : sram_word_idx + len_beats - 1
          error          = desc_end_addr > MAX_SRAM_ADDR
        """
        dir_bit = desc.w3 & 1
        sram_byte_addr = desc.w1 if dir_bit else desc.w0
        sram_word_idx = (sram_byte_addr >> 2) & 0xFFFFFFFF
        len_beats = desc.w2 & 0xFF
        if len_beats == 0:
            desc_end_addr = sram_word_idx
        else:
            desc_end_addr = sram_word_idx + len_beats - 1
        return desc_end_addr <= MAX_SRAM_ADDR
