class IRQ:
    """
    Software clears interrupts by writing 1 to IRQ_STATUS (W1C via CSR).
    """

    def __init__(self, csr):
        self.csr = csr

    def irq_done(self):
        irq_status = self.csr.read_register(self.csr.IRQ_STATUS_REG)
        irq_enable = self.csr.read_register(self.csr.IRQ_ENABLE_REG)
        done_set = (irq_status >> self.csr.IRQ_DONE_BIT) & 1
        done_en  = (irq_enable >> self.csr.IRQ_DONE_BIT) & 1
        return bool(done_set and done_en)

    def irq_error(self):
        irq_status = self.csr.read_register(self.csr.IRQ_STATUS_REG)
        irq_enable = self.csr.read_register(self.csr.IRQ_ENABLE_REG)
        return bool((irq_status >> self.csr.IRQ_ERROR_BIT) & 1) and \
               bool((irq_enable >> self.csr.IRQ_ERROR_BIT) & 1)

    def any_pending(self):
        return self.irq_done or self.irq_error