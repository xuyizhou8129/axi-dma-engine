from axi_4_master import AXI4Master
from descriptor import descriptor
from fifo_queue import FIFOQueue


"""
    Description: The Descriptor Fetcher acts as the bridge between the Ring Manager
    and the Data Mover.
    
    Functionalities:
    - Receives a memory index (rm_address) from the Ring Manager.
    - Performs a multi-word burst read from System Memory via the AXI4 Master.
    - Decodes raw 32-bit memory words into a structured Descriptor object.
    - Output: A Descriptor object containing start_addr, burst_len, and data_size.
"""

class DescriptorFetcher:
    def __init__(self, axi4: AXI4Master, df_write_fifo: FIFOQueue):

        self.axi4 = axi4 # connnection to the AXI4 Master
        self.df_write_fifo = df_write_fifo
        
    # df_read(self, rm_address)
    # rm_address: Starting index in SystemMemory provided by ring manager
    def df_read(self):
        # each index holds one 32-bit word
        # each field (start_address, burst_length, datasize) is a 32-bit word

        word_start_address = self.axi4.df_write_fifo.dequeue()
        word_burst_length = self.axi4.df_write_fifo.dequeue()
        word_datasize = self.axi4.df_write_fifo.dequeue()

        new_descriptor = descriptor(
            start_address = word_start_address,
            burst_length = word_burst_length,
            datasize = word_datasize
        )
        return new_descriptor
    
    def df_write(self, rm_address):

        self.df_write_fifo.enqueue(rm_address)



        
        

    