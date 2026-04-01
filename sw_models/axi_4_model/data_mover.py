from structs import Instruction

class DataMover:
    """
    Sits between Descriptor Fetcher (DF) and memory-side clients.
    Decodes oneDescriptor into two Instruction streams.
    Tracks completions and tells Ring Manager when a transaction is done.
    """
    def __init__(self, df_dm_fifo, axi_inst_fifo, sram_inst_fifo, ring_manager):
        self.df_dm_fifo = df_dm_fifo       # Input from DF
        self.axi_inst_fifo = axi_inst_fifo # Output to AXI Master
        self.sram_inst_fifo = sram_inst_fifo # Output to SRAM Controller
        self.ring_manager = ring_manager
        
        self.pending_transactions = 0

    def update(self):
        # Read from DF and issue instructions
        if not self.df_dm_fifo.is_empty():
            if not self.axi_inst_fifo.is_full() and not self.sram_inst_fifo.is_full():
                desc = self.df_dm_fifo.dequeue()
                
                # Direction: 1 = System -> SRAM, 0 = SRAM -> System
                if desc.direction == 1:
                    # Sys -> SRAM: AXI Master reads SysMem -> SRAM writes SRAM
                    axi_inst = Instruction(desc.src_addr, desc.length, is_read=True, is_sram=False)
                    sram_inst = Instruction(desc.dst_addr, desc.length, is_read=False, is_sram=True)
                else:
                    # SRAM -> Sys: SRAM reads SRAM -> AXI Master writes SysMem
                    sram_inst = Instruction(desc.src_addr, desc.length, is_read=True, is_sram=True)
                    axi_inst = Instruction(desc.dst_addr, desc.length, is_read=False, is_sram=False)
                
                # Issue
                self.axi_inst_fifo.enqueue(axi_inst)
                self.sram_inst_fifo.enqueue(sram_inst)
                
                self.pending_transactions += 1

    def mark_done(self):
        """
        Called by the writer (either AXI Master or SRAM Controller) when 
        its burst instruction completes.
        """
        if self.pending_transactions > 0:
            self.pending_transactions -= 1
            self.ring_manager.mark_completed()
