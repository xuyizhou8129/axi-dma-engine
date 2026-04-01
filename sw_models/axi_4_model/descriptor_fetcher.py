from structs import Descriptor

class DescriptorFetcher:
    """
    Bridges the Ring Manager and Data Mover.
    Receives Handle from RM -> Sends to AXI4 Master.
    Receives words from AXI4 Master -> Decodes to Descriptor -> Sends to Data Mover.
    """
    def __init__(self, rm_handle_fifo, axi_handle_fifo, axi_callback_fifo, df_dm_fifo):
        self.rm_handle_fifo = rm_handle_fifo       # In from Ring Manager
        self.axi_handle_fifo = axi_handle_fifo     # Out to AXI Master
        self.axi_callback_fifo = axi_callback_fifo # In from AXI Master
        self.df_dm_fifo = df_dm_fifo               # Out to Data Mover
        
        self.words_collected = []

    def update(self):
        # 1. Forward handles from RM to AXI Master
        if not self.rm_handle_fifo.is_empty() and not self.axi_handle_fifo.is_full():
            handle = self.rm_handle_fifo.dequeue()
            self.axi_handle_fifo.enqueue(handle)

        # 2. Collect returned descriptor words from AXI Master
        if not self.axi_callback_fifo.is_empty():
            word = self.axi_callback_fifo.dequeue()
            self.words_collected.append(word)
            
            # 4 words = 1 descriptor
            if len(self.words_collected) == 4:
                src = self.words_collected[0]
                dst = self.words_collected[1]
                length = self.words_collected[2]
                flags = self.words_collected[3]
                
                desc = Descriptor(src, dst, length, flags)
                
                # Push to Data Mover
                if not self.df_dm_fifo.is_full():
                    self.df_dm_fifo.enqueue(desc)
                    self.words_collected = []
                else:
                    # Stash it back if DM FIFO is full (simplified handling)
                    self.words_collected.pop() 
                    # Note: in real hardware, this requires backpressure to AXI Master
