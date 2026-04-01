# Ben
''' Description: The data mover itself contains a smaller data buffer
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
'''
import descriptor

class DataMover:
    def __init__(self, descriptor_fetcher, axi4_master, sram_controller, data_fifo)
        self.descriptor_fetcher = descriptor_fetcher
        self.axi4_master = axi4_master
        self.sram_controller = sram_controller
        self.data_fifo = data_fifo
    
    def read_from_axi4_master(self, start_addr, burst_length, data_size):
        pass

    def read_from_sram_controller(self, start_addr, burst_length, data_size):
        pass

    def write_to_axi4_master(self, start_addr, burst_length, data_size):
        pass

    def write_to_sram_controller(self, start_addr, burst_length, data_size):
        pass