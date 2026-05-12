"""
Data Mover (software model): enqueues AXI instructions (one beat each) and can
preload the MID FIFO for write transactions.
"""

from fifo_queue import FIFOQueue
from axi_4_master import pack_instruction


class DataMover:
    def __init__(self, fifo_instr_to_axi: FIFOQueue, fifo_mid: FIFOQueue):
        self.fifo_instr_to_axi = fifo_instr_to_axi
        self.fifo_mid = fifo_mid

    def submit_read(self, byte_addr, len_beats):
        self.fifo_instr_to_axi.enqueue(pack_instruction(byte_addr, len_beats, is_write=False))

    def submit_write(self, byte_addr, len_beats):
        self.fifo_instr_to_axi.enqueue(pack_instruction(byte_addr, len_beats, is_write=True))

    def preload_write_data(self, words):
        """Push 32-bit words (one per AXI beat) into MID before issuing a write instruction."""
        for w in words:
            self.fifo_mid.enqueue(int(w) & 0xFFFFFFFF)
