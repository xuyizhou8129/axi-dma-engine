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
    def __init__(self, axi4: AXI4Master, df_fifo_to_axi: FIFOQueue):

        self.axi4 = axi4 # connnection to the AXI4 Master
        self.df_fifo_to_axi = df_fifo_to_axi
        
    # df_read(self, rm_address)
    # rm_address: Starting index in SystemMemory provided by ring manager

    def df_read(self):
        # each index holds 43-bits
        # bits[31:0]: start_address
        # bits[39:32]: burst_length
        # bits[42:40]: datasize

        raw_bits = self.axi4.fifo_to_df.dequeue()

        descrip_start_address = raw_bits & 0xFFFFFFFF
        descrip_burst_length = (raw_bits >> 32) & 0xFF
        descrip_datasize = (raw_bits >> 40) & 0x7

        new_descriptor = descriptor(
            start_address = descrip_start_address,
            burst_length = descrip_burst_length,
            datasize = descrip_datasize
        )
        return new_descriptor
    
    def df_write(self, rm_address):
        self.df_fifo_to_axi.enqueue(rm_address)



        
        

    