class IRQ:
    def __init__(self, CSR):
        self.done = False
        self.interrupt_enable = False

    def set_interrupt(self):
        self.interrupt_enable = True

    def interrupt(self):
        self.interrupt_enable = False
        CPU_DMA_Interrupt()







    
    
    