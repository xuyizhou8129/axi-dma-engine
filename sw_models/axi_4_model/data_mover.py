# Ben
"""Description: The data mover itself contains a smaller data buffer
Functionalities:
- Read data from AXI4 Master:
input: start_addr, burst_length, data_size
output: data (as an array)

- Read data from SRAM Controller:
input: start_addr, burst_length, data_size
output: data (as an array)

- Write data to AXI4 Master (which talks to system memory):
input: start_addr, burst_length, data_size
output: flag (int for now)

- Write data to SRAM Controller:
input: start_addr, burst_length, data_size
output: flag (int for now)
"""

from axi_4_master import AXI4Master
from sram_controller import SRAMController
from fifo_queue import FIFOQueue


class DataMover:
    def __init__(
        self,
        axi4: AXI4Master,
        sram: SRAMController,
        dm_write_fifo: FIFOQueue
    ):
        self.axi4 = axi4
        self.sram = sram
        self.dm_write_fifo = dm_write_fifo

    def read_from_axi4_master(self, start_addr, burst_length, data_size):
        word_start_address = self.axi4.fifo_to_df.dequeue()
        word_burst_length = self.axi4.fifo_to_df.dequeue()
        word_datasize = self.axi4.fifo_to_df.dequeue()

    def read_from_sram_controller(self, start_addr, burst_length, data_size):
        # data_size is in bits; must be byte-multiple
        if data_size % 8 != 0:
            raise ValueError("data_size must be a multiple of 8 bits (1 byte)")

        address = start_addr
        for _ in range(burst_length):
            self.sram.enqueue_read(address=address, size_bits=data_size)
            address += data_size // 8  # advance by bytes per beat

    def write_to_axi4_master(self, start_addr, burst_length, data_size):
        pass

    def write_to_sram_controller(self, start_addr, burst_length, data_size):
        pass
