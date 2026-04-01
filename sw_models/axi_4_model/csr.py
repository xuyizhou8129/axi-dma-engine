class CSR:
    BASEADDR_REG    = 0x00
    RINGLEN_REG     = 0x04
    HEAD_REG        = 0x08
    TAIL_REG        = 0x0C
    CTRL_REG        = 0x10
    STATUS_REG      = 0x14
    IRQ_STATUS_REG  = 0x18
    IRQ_CLEAR_REG   = 0x2C

    # CTRL BITS
    CTRL_ENABLE_BIT = 0
    CTRL_RESET_BIT  = 1
    CTRL_IRQ_EN_BIT = 2

    # STATUS BITS
    STATUS_BUSY_BIT = 0
    STATUS_RING_EMPTY_BIT = 1
    STATUS_ERROR_BIT = 2

    # IRQ BITS
    IRQ_EMPTY_BIT = 0
    IRQ_ERROR_BIT = 1

    def __init__(self):
        self.registers = {
            self.BASEADDR_REG: 0,
            self.RINGLEN_REG: 0,
            self.HEAD_REG: 0,
            self.TAIL_REG: 0,
            self.CTRL_REG: 0,
            self.STATUS_REG: 0,
            self.IRQ_STATUS_REG: 0,
            self.IRQ_CLEAR_REG: 0,
        }

    def write_register(self, offset, data):
        if offset in [self.HEAD_REG, self.STATUS_REG, self.IRQ_STATUS_REG]:
            # Read only from CPU perspective, ignored
            return
        
        if offset == self.IRQ_CLEAR_REG:
            # W1C logic
            if (data & (1 << self.IRQ_EMPTY_BIT)):
                self.registers[self.IRQ_STATUS_REG] &= ~(1 << self.IRQ_EMPTY_BIT)
            if (data & (1 << self.IRQ_ERROR_BIT)):
                self.registers[self.IRQ_STATUS_REG] &= ~(1 << self.IRQ_ERROR_BIT)
                # clear error status bit too
                self.registers[self.STATUS_REG] &= ~(1 << self.STATUS_ERROR_BIT)
            return

        if offset == self.TAIL_REG:
            # Software writes tail. Wrap modulo
            ring_len = self.registers[self.RINGLEN_REG]
            if ring_len > 0:
                self.registers[self.TAIL_REG] = data % ring_len
            else:
                self.registers[self.TAIL_REG] = data
            return

        self.registers[offset] = data

    def read_register(self, offset):
        if offset not in self.registers:
            raise ValueError(f"Invalid CSR offset: 0x{offset:02X}")
        return self.registers[offset]

    # Hardware (DMA) methods
    def get_baseaddr(self):
        return self.registers[self.BASEADDR_REG]

    def get_ringlen(self):
        return self.registers[self.RINGLEN_REG]

    def get_head(self):
        return self.registers[self.HEAD_REG]

    def set_head(self, val):
        self.registers[self.HEAD_REG] = val

    def get_tail(self):
        return self.registers[self.TAIL_REG]

    def is_enabled(self):
        return bool(self.registers[self.CTRL_REG] & (1 << self.CTRL_ENABLE_BIT))

    def set_status_busy(self, val: bool):
        if val:
            self.registers[self.STATUS_REG] |= (1 << self.STATUS_BUSY_BIT)
        else:
            self.registers[self.STATUS_REG] &= ~(1 << self.STATUS_BUSY_BIT)

    def set_status_error(self):
        self.registers[self.STATUS_REG] |= (1 << self.STATUS_ERROR_BIT)
        self.registers[self.IRQ_STATUS_REG] |= (1 << self.IRQ_ERROR_BIT)

    def set_empty_irq(self):
        self.registers[self.IRQ_STATUS_REG] |= (1 << self.IRQ_EMPTY_BIT)
        self.registers[self.STATUS_REG] |= (1 << self.STATUS_RING_EMPTY_BIT)
    
    def clear_empty_status(self):
        self.registers[self.STATUS_REG] &= ~(1 << self.STATUS_RING_EMPTY_BIT)
    
    def is_reset(self):
        return bool(self.registers[self.CTRL_REG] & (1 << self.CTRL_RESET_BIT))
