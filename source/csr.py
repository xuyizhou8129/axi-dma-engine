"""
Software model of csr.sv.
Register map matches dma_pkg.sv / csr.sv exactly.
No AXI handshaking needed; reads/writes are instantaneous.
"""


class CSR:
    # Register offsets (byte-addressed, matches dma_pkg.sv)
    REG_BASEADDR   = 0x00
    REG_RINGLEN    = 0x04
    REG_HEAD       = 0x08  # read-only (driven by ring_manager HW)
    REG_TAIL       = 0x0C
    REG_CTRL       = 0x10  # [0]=ENABLE, [1]=RESET, [2]=IRQ_EN
    REG_STATUS     = 0x14  # [0]=busy, [1]=ring_empty, [2]=error (read-only)
    REG_IRQ_STATUS = 0x18  # [0]=irq_empty, [1]=irq_error (W1C via REG_IRQ_CLEAR)
    REG_IRQ_CLEAR  = 0x2C  # write-1-to-clear: [0]=clear irq_empty, [1]=clear irq_error

    # CTRL bit positions
    ENABLE_BIT = 0
    RESET_BIT  = 1
    IRQ_EN_BIT = 2

    # STATUS bit positions
    BUSY_BIT       = 0
    RING_EMPTY_BIT = 1
    ERROR_BIT      = 2

    # IRQ_STATUS bit positions
    IRQ_EMPTY_BIT = 0
    IRQ_ERROR_BIT = 1

    def __init__(self):
        self._regs = {
            self.REG_BASEADDR:   0,
            self.REG_RINGLEN:    0,
            self.REG_HEAD:       0,
            self.REG_TAIL:       0,
            self.REG_CTRL:       0,
            self.REG_STATUS:     0,
            self.REG_IRQ_STATUS: 0,
            self.REG_IRQ_CLEAR:  0,
        }
        # Ring manager handle for the error_clear pulse (mirrors
        # csr.sv -> ring_mgr.error_clear). Set via attach_ring_manager().
        self._ring_mgr = None

    def attach_ring_manager(self, ring_mgr):
        """Wire the ring manager so IRQ_CLEAR[1] generates the error_clear pulse."""
        self._ring_mgr = ring_mgr

    def write(self, offset, data):
        if offset == self.REG_HEAD or offset == self.REG_STATUS:
            return  # read-only; ignore writes
        elif offset == self.REG_IRQ_CLEAR:
            # W1C: clear corresponding IRQ_STATUS bits
            if data & (1 << self.IRQ_EMPTY_BIT):
                self._regs[self.REG_IRQ_STATUS] &= ~(1 << self.IRQ_EMPTY_BIT)
            if data & (1 << self.IRQ_ERROR_BIT):
                self._regs[self.REG_IRQ_STATUS] &= ~(1 << self.IRQ_ERROR_BIT)
                self._regs[self.REG_STATUS]      &= ~(1 << self.ERROR_BIT)
                # Mirrors ring_mgr_error_clear pulse (csr.sv:368).
                if self._ring_mgr is not None:
                    self._ring_mgr.clear_error()
        elif offset == self.REG_CTRL:
            self._regs[self.REG_CTRL] = data & 0x7  # only bits [2:0] are used
        else:
            self._regs[offset] = data & 0xFFFFFFFF

    def read(self, offset):
        return self._regs.get(offset, 0)

    # -------------------------------------------------------------------------
    # Hardware update hooks — called by the ring_manager model to reflect
    # status that the HW drives on the interface (ring_mgr.head, .busy, etc.)
    # -------------------------------------------------------------------------

    def hw_set_head(self, head):
        self._regs[self.REG_HEAD] = head & 0xFFFFFFFF

    def hw_set_busy(self, busy):
        if busy:
            self._regs[self.REG_STATUS] |= (1 << self.BUSY_BIT)
        else:
            self._regs[self.REG_STATUS] &= ~(1 << self.BUSY_BIT)

    def hw_set_ring_empty(self, empty):
        if empty:
            self._regs[self.REG_STATUS] |= (1 << self.RING_EMPTY_BIT)
        else:
            self._regs[self.REG_STATUS] &= ~(1 << self.RING_EMPTY_BIT)

    def hw_set_error(self):
        """Called by ring_manager on df_error (error_set pulse)."""
        self._regs[self.REG_STATUS]     |= (1 << self.ERROR_BIT)
        self._regs[self.REG_IRQ_STATUS] |= (1 << self.IRQ_ERROR_BIT)

    def hw_set_empty_irq(self):
        """Called by ring_manager on non-empty→empty transition (irq_empty_set pulse)."""
        self._regs[self.REG_IRQ_STATUS] |= (1 << self.IRQ_EMPTY_BIT)

    # -------------------------------------------------------------------------
    # Convenience accessors used by ring_manager model
    # -------------------------------------------------------------------------

    def is_enabled(self):
        return bool(self._regs[self.REG_CTRL] & (1 << self.ENABLE_BIT))

    def is_reset(self):
        return bool(self._regs[self.REG_CTRL] & (1 << self.RESET_BIT))

    def irq_en(self):
        return bool(self._regs[self.REG_CTRL] & (1 << self.IRQ_EN_BIT))

    def baseaddr(self):
        return self._regs[self.REG_BASEADDR]

    def ringlen(self):
        return self._regs[self.REG_RINGLEN]

    def tail(self):
        return self._regs[self.REG_TAIL]
