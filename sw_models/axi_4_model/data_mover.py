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
from sw_models.axi_4_model.sram_controller import SRAMController
from fifo_queue import FIFOQueue
from descriptor import descriptor

ADDRESSBITS = 32
DATASIZEBITS = 3
BUSRSTSIZEBITS = 16

class DataMover:
    def __init__(
        self,
        axi4: AXI4Master,
        sram: SRAMController,
        dm_axi4_write_fifo: FIFOQueue
        dm_sram_write_fifo: FIFOQueue
    ):
        self.axi4 = axi4
        self.sram = sram
        self.dm_axi4_write_fifo = dm_axi4_write_fifo
        self.dm_sram_write_fifo = dm_sram_write_fifo

    def read_from_axi4_master(self, start_addr, burst_length, data_size):
        data = self.axi4.fifo_to_dm.dequeue()  # gets a 32-bit data from axi4 master
        return data
        


    def read_from_sram_controller(self, start_addr, burst_length, data_size):
        data = self.sram.fifo_to_dm.dequeue()  # gets a 32-bit data from sram controller
        return data

    def write_to_axi4_master(self, start_addr, burst_length, data_size):
        raw_data = bin(self.dm_axi4_write_fifo.deque()) #Converts the value gotten in binary
        address = raw_data[:ADDRESSBITS]
        burst_size = raw_data[ADDRESSBITS:ADDRESSBITS+BURSTSIZEBITS]
        data_width = raw_data[ADDRESSBITS+BURSTSIZEBITS : ADDRESSBITS+BURSTSIZEBITS+DATASIZEBITS]

        new_descriptor = descriptor(
            start_address = address,
            burst_length = burst_size,
            datasize = data_width
        )

        return new_descriptor

    def write_to_sram_controller(self, start_addr, burst_length, data_size):
        raw_data = bin(self.dm_sram_write_fifo.deque()) #Converts the value gotten in binary
        address = raw_data[:ADDRESSBITS]
        burst_size = raw_data[ADDRESSBITS:ADDRESSBITS+BURSTSIZEBITS]
        data_width = raw_data[ADDRESSBITS+BURSTSIZEBITS : ADDRESSBITS+BURSTSIZEBITS+DATASIZEBITS]

        new_descriptor = descriptor(
            start_address = address,
            burst_length = burst_size,
            datasize = data_width
        )

        return new_descriptor
