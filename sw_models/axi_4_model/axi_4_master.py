class AXI4Master:
    """
    AXI4 Master implements the system-memory side.
    Arbitrates Handle priorities over Instruction traffic.
    Exchanges data via shared data FIFO with SRAM.
    """
    def __init__(self, memory, handle_fifo, inst_fifo, callback_fifo, data_fifo, data_mover):
        self.memory = memory
        
        # Connections
        self.handle_fifo = handle_fifo       # From DF (highest priority)
        self.inst_fifo = inst_fifo           # From Data Mover
        self.callback_fifo = callback_fifo   # To DF
        self.data_fifo = data_fifo           # Shared with SRAM
        self.data_mover = data_mover
        
        # State
        self.current_inst = None
        self.words_processed = 0

    def update(self):
        # Arbitrate Handles First
        if not self.handle_fifo.is_empty():
            # If callback FIFO isn't full enough for 4 words, wait
            if len(self.callback_fifo) + 4 <= self.callback_fifo.queue_length:
                handle = self.handle_fifo.dequeue()
                # Read 4 words from sys mem for the descriptor
                for i in range(4):
                    word = self.memory.read_word(handle.base_address + i*4)
                    self.callback_fifo.enqueue(word)
                return # Descriptor fetch takes up this cycle block

        # Otherwise Process Data Mover instructions
        if self.current_inst is None and not self.inst_fifo.is_empty():
            self.current_inst = self.inst_fifo.dequeue()
            self.words_processed = 0

        # Execute data mover instruction
        if self.current_inst is not None:
            inst = self.current_inst
            
            if inst.is_read:
                # SysMem -> Data FIFO
                if not self.data_fifo.is_full():
                    addr = inst.base_address + self.words_processed * 4
                    word = self.memory.read_word(addr)
                    self.data_fifo.enqueue(word)
                    self.words_processed += 1
            else:
                # Data FIFO -> SysMem
                if not self.data_fifo.is_empty():
                    word = self.data_fifo.dequeue()
                    addr = inst.base_address + self.words_processed * 4
                    self.memory.write_word(addr, word)
                    self.words_processed += 1
            
            # Check completion
            if self.words_processed == inst.burst_size:
                if not inst.is_read:
                    # Write path signals done to Data Mover
                    self.data_mover.mark_done()
                self.current_inst = None
