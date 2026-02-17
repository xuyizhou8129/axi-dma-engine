from memory import SystemMemory
from fifo_queue import FIFOQueue
from data_mover import DataMover
from descriptor_fetcher import DescriptorFetcher

class AXI4Master:
    #/*Key questions: How close are we to hardware?*/
    def __init__(self, memory: SystemMemory, fifo_to_df: FIFOQueue, fifo_to_dm: FIFOQueue, dm: DataMover, df: DescriptorFetcher):
        self.memory = memory
        self.fifo_to_df = fifo_to_df
        self.fifo_to_dm = fifo_to_dm
        # self.dm = dm
        # self.df = df
        #self.fifo_from_dm = dm.data_fifo
        self.fifo_from_dm = dm.dm_fifo_to_axi
        self.fifo_from_df = df.df_fifo_to_axi # fifo from df to AXI

    def read_memory(self, start_addr, burst_length, datasize, target_fifo: FIFOQueue = None, target="dm"):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI read out of bounds")

        if target_fifo is None:
            if target == "df":
                target_fifo = self.fifo_to_df
            elif target == "dm":
                target_fifo = self.fifo_to_dm
            else:
                raise ValueError("Invalid AXI read target, use 'df' or 'dm'")

        for addr in range(start_addr, end_addr):
            target_fifo.enqueue(self.memory.mem[addr])
  
  
    def write_memory(self, start_addr, burst_length, datasize, source_fifo: FIFOQueue = None, source="dm"):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI write out of bounds")

        if source_fifo is None:
            if source == "dm":
                source_fifo = self.fifo_from_dm
            elif source == "df":
                source_fifo = self.fifo_from_df
            else:
                raise ValueError("Invalid AXI write source, use 'dm' or 'df'")

        if source_fifo is None:
            raise ValueError("AXI write source FIFO is not connected")

        if len(source_fifo) != total_num_bytes: # we wait for axi4 to write it into memory
            raise ValueError("FIFO size mismatch for AXI write")

        for addr in range(start_addr, end_addr):
            self.memory.mem[addr] = source_fifo.dequeue()


    # def write_a_byte(self, addr, value):
    #     if addr < 0 or addr >= self.memory.size:
    #         raise ValueError("AXI write out of bounds")
    #     self.memory.mem[addr] = value
    
    # def read_a_byte(self, addr):
    #     if addr < 0 or addr >= self.memory.size:
    #         raise ValueError("AXI read out of bounds")
    #     return self.memory.mem[addr]
