import memory
from memory import SystemMemory

class AXI4Master:
    #/*Key questions: How close are we to hardware?*/
    def __init__(self, memory: SystemMemory):
        self.memory = memory
        self.read_buffer = []
        self.write_buffer = []

    # add fifo data structure
    # fixed size read/write buffer
    # reset the buffers
        
    def read_memory(self, start_addr, burst_length, datasize):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size: # out of bounds check
            raise ValueError("AXI read out of b33unds")
        
        self.read_buffer.clear()   # clear FIRST
        for i in range(start_addr, end_addr): # byte by byte we read form data 
            self.read_buffer.append(self.memory.mem[i])
  
    def write_memory(self, start_addr, burst_length, datasize):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if len(self.write_buffer) != total_num_bytes:
            raise ValueError("Write buffer size mismatch")
        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI write out of bounds")

        for i in range(total_num_bytes):
            self.memory.mem[start_addr + i] = self.write_buffer[i]
        self.write_buffer = []

    def write_a_byte(self, addr, value):
        if addr < 0 or addr >= self.memory.size:
            raise ValueError("AXI write out of bounds")
        self.memory.mem[addr] = value
    
    def read_a_byte(self, addr):
        if addr < 0 or addr >= self.memory.size:
            raise ValueError("AXI read out of bounds")
        return self.memory.mem[addr]
