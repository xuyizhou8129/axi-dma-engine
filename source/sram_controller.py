"""
Software model of sram_controller.sv.

Processes one instruction at a time from the DM instruction FIFO (same encoding
as axi_4_master.py).  Mirrors the SRAM controller's two FSM paths:

  READ  (rw=0): read words from local SRAM → push to MID FIFO
  WRITE (rw=1): pop words from MID FIFO   → write to local SRAM

Instruction encoding (41 bits, matching axi_4_master.py / RTL):
  [31:0]  byte address
  [39:32] num beats (words)
  [40]    rw  (1=write to SRAM, 0=read from SRAM)
"""

from fifo_queue import FIFOQueue 
LEN_LSB = 32
RW_BIT  = 40


class SRAMController:
    def __init__(self, sram_mem, dm_in_fifo: FIFOQueue, mid_fifo: FIFOQueue):
        """
        sram_mem  : list of 32-bit words (BRAM backing store)
        dm_in_fifo: FIFOQueue of 41-bit instructions from the data mover
        mid_fifo  : shared FIFOQueue between AXI master and SRAM controller
        """
        self.sram  = sram_mem
        self.dm_in = dm_in_fifo
        self.mid   = mid_fifo

    def process_one(self):
        """
        Process one instruction from dm_in_fifo.
        Returns True if an instruction was processed, False if the FIFO was empty.
        """
        if self.dm_in.is_empty():
            return False

        instr     = self.dm_in.dequeue()
        byte_addr = instr & 0xFFFFFFFF
        num_beats = (instr >> LEN_LSB) & 0xFF
        is_write  = bool((instr >> RW_BIT) & 1)
        word_idx  = byte_addr >> 2

        if is_write:
            # Pop from MID FIFO → write to SRAM
            for i in range(num_beats):
                data = self.mid.dequeue()
                self.sram[word_idx + i] = data & 0xFFFFFFFF
        else:
            # Read from SRAM → push to MID FIFO
            for i in range(num_beats):
                self.mid.enqueue(self.sram[word_idx + i] & 0xFFFFFFFF)

        return True

    @property
    def idle(self):
        return self.dm_in.is_empty()
