import axi_4_model
from descriptor import descriptor

"""
    Description: The Descriptor Fetcher acts as the bridge between the Ring Manager
    and the Data Mover.
    
    Functionalities:
    - Receives a memory index (rm_address) from the Ring Manager.
    - Performs a multi-word burst read from System Memory via the AXI4 Master.
    - Decodes raw 32-bit memory words into a structured Descriptor object.
    - Output: A Descriptor object containing start_addr, burst_len, and data_size.
"""

class descriptor_fetcher:
    def __init__(self, AXI4Master):

        self.axi4 = AXI4Master # connnection to the AXI4 Master
        
    # df_read(self, rm_address)
    # rm_address: Starting index in SystemMemory provided by ring manager
    def df_read(self, rm_address):
        # assuming each index holds one 32-bit word
        # assuming each field (start_address, burst_length, datasize) is a 32-bit word
        raw_words = self.axi4.memory[rm_address : rm_address + 3]

        word_start_address = raw_words[0]
        word_burst_length = raw_words[1]
        word_datasize = raw_words[2]

        new_descriptor = descriptor(
            start_address = word_start_address,
            burst_length = word_burst_length,
            datasize = word_datasize
        )

        return new_descriptor
        

    