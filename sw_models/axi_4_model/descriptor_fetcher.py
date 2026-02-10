import axi_4_model

class descriptor_fetcher:
    def __init__(self, descriptor, AXI4Master):

        self.descriptor = descriptor # descriptor from ring manager

        self.AXI4Master = AXI4Master # connnection to the AXI4 Master

        self.data = AXI4Master.read_buffer
        

    def df_read(self):
        return self.data

    