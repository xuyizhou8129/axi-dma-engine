class SRAMController:
    """
    SRAM Controller mimics on-chip SRAM memory array + controller logic.
    It receives Instruction structs from the Data Mover and interacts with
    a shared data FIFO to exchange data with the AXI4 Master.
    """
    def __init__(self, size_bytes: int):
        self.size = size_bytes
        self.mem = [0] * (size_bytes // 4)
        
        # Connections
        self.inst_fifo = None
        self.data_fifo = None
        self.data_mover = None
        
        # State
        self.current_inst = None
        self.words_processed = 0

    def link(self, inst_fifo, data_fifo, data_mover):
        self.inst_fifo = inst_fifo
        self.data_fifo = data_fifo
        self.data_mover = data_mover

    def read_word(self, byte_addr: int):
        if byte_addr % 4 != 0:
            raise ValueError("SRAM: Unaligned read")
        idx = byte_addr // 4
        return self.mem[idx]

    def write_word(self, byte_addr: int, word32: int):
        if byte_addr % 4 != 0:
            raise ValueError("SRAM: Unaligned write")
        idx = byte_addr // 4
        self.mem[idx] = word32 & 0xFFFFFFFF

    def update(self):
        # Fetch new instruction if idle
        if self.current_inst is None and not self.inst_fifo.is_empty():
            self.current_inst = self.inst_fifo.dequeue()
            self.words_processed = 0

        # Execute instruction
        if self.current_inst is not None:
            inst = self.current_inst
            
            if inst.is_read:
                # SRAM -> Data FIFO
                if not self.data_fifo.is_full():
                    addr = inst.base_address + self.words_processed * 4
                    word = self.read_word(addr)
                    self.data_fifo.enqueue(word)
                    self.words_processed += 1
            else:
                # Data FIFO -> SRAM
                if not self.data_fifo.is_empty():
                    word = self.data_fifo.dequeue()
                    addr = inst.base_address + self.words_processed * 4
                    self.write_word(addr, word)
                    self.words_processed += 1
            
            # Check completion
            if self.words_processed == inst.burst_size:
                if not inst.is_read:
                    # Write path signals done to the Data Mover
                    self.data_mover.mark_done()
                self.current_inst = None
