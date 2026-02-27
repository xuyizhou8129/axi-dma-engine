class CSR:
    # Register offset definitions (matching spec)
    CTRL_REG       = 0x00
    SRC_ADDR_REG   = 0x04
    DST_ADDR_REG   = 0x08
    LENGTH_REG     = 0x0C
    STATUS_REG     = 0x10
    IRQ_STATUS_REG = 0x14
    IRQ_ENABLE_REG = 0x18

    # CTRL bit positions
    START_BIT  = 0
    DIR_BIT    = 1

    # STATUS bit positions
    BUSY_BIT   = 0
    DONE_BIT   = 1
    ERROR_BIT  = 2

    # IRQ_STATUS / IRQ_ENABLE bit positions
    IRQ_DONE_BIT  = 0
    IRQ_ERROR_BIT = 1

    def __init__(self):
        self.registers = {
            self.CTRL_REG:       0,
            self.SRC_ADDR_REG:   0,
            self.DST_ADDR_REG:   0,
            self.LENGTH_REG:     0,
            self.STATUS_REG:     0,
            self.IRQ_STATUS_REG: 0,
            self.IRQ_ENABLE_REG: 0,
        }
        # Values latched at START (used by DMA engine)
        self._latched_src = 0
        self._latched_dst = 0
        self._latched_len = 0
        self._latched_dir = 0

    def write_register(self, offset, data):
        if offset not in self.registers:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")

        if offset == self.STATUS_REG:
            # STATUS is read-only, ignore writes
            return

        elif offset == self.IRQ_STATUS_REG:
            # W1C: clear bits where data has 1s
            cleared_bits = self.registers[offset] & data
            self.registers[offset] &= ~data & 0xFFFFFFFF
            # Clearing IRQ_STATUS[0] also clears STATUS DONE bit
            if cleared_bits & (1 << self.IRQ_DONE_BIT):
                self.registers[self.STATUS_REG] &= ~(1 << self.DONE_BIT)
            # Clearing IRQ_STATUS[1] also clears STATUS ERROR bit
            if cleared_bits & (1 << self.IRQ_ERROR_BIT):
                self.registers[self.STATUS_REG] &= ~(1 << self.ERROR_BIT)

        elif offset == self.CTRL_REG:
            self.registers[offset] = data
            if data & (1 << self.START_BIT):
                self._handle_start()

        else:
            self.registers[offset] = data

    def read_register(self, offset):
        if offset not in self.registers:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")
        return self.registers[offset]

    # helpers

    def _handle_start(self):
        src    = self.registers[self.SRC_ADDR_REG]
        dst    = self.registers[self.DST_ADDR_REG]
        length = self.registers[self.LENGTH_REG]

        # Alignment check: addresses and length must be 4-byte aligned, length non-zero
        misaligned = (src & 0x3) or (dst & 0x3) or (length & 0x3) or (length == 0)

        # Self-clear the START bit regardless
        self.registers[self.CTRL_REG] &= ~(1 << self.START_BIT)

        if misaligned:
            self._set_error()
            return

        # Latch transfer parameters for the DMA engine
        self._latched_src = src
        self._latched_dst = dst
        self._latched_len = length
        self._latched_dir = (self.registers[self.CTRL_REG] >> self.DIR_BIT) & 0x1

        # Assert BUSY
        self.registers[self.STATUS_REG] |= (1 << self.BUSY_BIT)

    def _set_error(self):
        self.registers[self.STATUS_REG] &= ~(1 << self.BUSY_BIT)
        self.registers[self.STATUS_REG] |= (1 << self.ERROR_BIT)
        self.registers[self.IRQ_STATUS_REG] |= (1 << self.IRQ_ERROR_BIT)

    # DMA engine callbacks

    def signal_done(self):
        """Called by the DMA engine when a transfer completes successfully."""
        self.registers[self.STATUS_REG] &= ~(1 << self.BUSY_BIT)
        self.registers[self.STATUS_REG] |= (1 << self.DONE_BIT)
        self.registers[self.IRQ_STATUS_REG] |= (1 << self.IRQ_DONE_BIT)

    def signal_error(self):
        """Called by the DMA engine when a transfer fails."""
        self._set_error()

    def get_transfer_params(self):
        """Returns the latched (src, dst, length, direction) for the DMA engine."""
        return self._latched_src, self._latched_dst, self._latched_len, self._latched_dir

    # accessors
    def is_busy(self):
        return bool(self.registers[self.STATUS_REG] & (1 << self.BUSY_BIT))

    def set_irq_status_bits(self, bits):
        self.registers[self.IRQ_STATUS_REG] |= bits