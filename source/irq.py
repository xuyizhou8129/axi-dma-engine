"""
Software model of IRQ.sv.
Reads IRQ_STATUS and CTRL.IRQ_EN from CSR to determine if interrupts are pending.
CSR's hw_set_empty_irq() / hw_set_error() set the status bits; W1C via CSR.write(REG_IRQ_CLEAR)
clears them.
"""


class IRQ:
    def __init__(self, csr):
        self.csr = csr

    def is_irq_empty(self):
        """True if empty-IRQ is pending and IRQ_EN is set."""
        status = self.csr.read(self.csr.REG_IRQ_STATUS)
        return bool((status >> self.csr.IRQ_EMPTY_BIT) & 1) and self.csr.irq_en()

    def is_irq_error(self):
        """True if error-IRQ is pending and IRQ_EN is set."""
        status = self.csr.read(self.csr.REG_IRQ_STATUS)
        return bool((status >> self.csr.IRQ_ERROR_BIT) & 1) and self.csr.irq_en()

    def any_pending(self):
        return self.is_irq_empty() or self.is_irq_error()
