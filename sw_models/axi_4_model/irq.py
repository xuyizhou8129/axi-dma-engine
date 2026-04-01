from csr import CSR

class IRQ:
    def __init__(self, csr: CSR):
        self.csr = csr

    def get_irq_empty(self):
        ctrl = self.csr.read_register(CSR.CTRL_REG)
        irq_en = (ctrl >> CSR.CTRL_IRQ_EN_BIT) & 1
        
        irq_status = self.csr.read_register(CSR.IRQ_STATUS_REG)
        empty_flag = (irq_status >> CSR.IRQ_EMPTY_BIT) & 1
        return bool(empty_flag and irq_en)

    def get_irq_error(self):
        ctrl = self.csr.read_register(CSR.CTRL_REG)
        irq_en = (ctrl >> CSR.CTRL_IRQ_EN_BIT) & 1
        
        irq_status = self.csr.read_register(CSR.IRQ_STATUS_REG)
        error_flag = (irq_status >> CSR.IRQ_ERROR_BIT) & 1
        return bool(error_flag and irq_en)
