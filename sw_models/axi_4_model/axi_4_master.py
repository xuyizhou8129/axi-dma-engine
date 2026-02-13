import memory
from memory import SystemMemory
import fifo_queue
from fifo_queue import FIFOQueue

class AXI4Master:
    #/*Key questions: How close are we to hardware?*/
    def __init__(self, memory: SystemMemory, df_read_fifo: FIFOQueue, df_write_fifo: FIFOQueue, dm_read_fifo: FIFOQueue, dm_write_fifo: FIFOQueue):
        self.memory = memory
        self.df_read_fifo = df_read_fifo
        self.df_write_fifo = df_write_fifo
        self.dm_read_fifo = dm_read_fifo
        self.dm_write_fifo = dm_write_fifo
        
    def read_memory(self, start_addr, burst_length, datasize, target_fifo: FIFOQueue):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI read out of bounds")

        for addr in range(start_addr, end_addr):
            target_fifo.enqueue(self.memory.mem[addr])
  
  
    def write_memory(self, start_addr, burst_length, datasize, source_fifo: FIFOQueue):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI write out of bounds")

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


