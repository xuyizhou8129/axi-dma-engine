import axi-lite
from axi-lite import AxiLite

class CSR:
    def __init__(self, axi_lite: AxiLite):
        #register representation via array
        self.csr = [0]*32 
        self.axi_lite = axi_lite
        



    def 
    def set_status(new_status):
        self.status = new_status

    def get_status():
        return self.status
    
    
