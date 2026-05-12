"""
Descriptor Fetcher (software model): pushes a handle into the DF→AXI FIFO; the
AXI4 master reads the descriptor from system memory and pushes the packed
128-bit descriptor into the AXI→DF callback FIFO.
"""

from fifo_queue import FIFOQueue
from descriptor import Descriptor


def pack_handle(addr, len_beats):
    return (addr & 0xFFFFFFFF) | ((len_beats & 0xFF) << 32)


class DescriptorFetcher:
    def __init__(self, fifo_handle_to_axi, fifo_desc_from_axi):
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
