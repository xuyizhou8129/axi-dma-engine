import csr
from csr import CSR

class AxiLite:
    def __init__(self, csr: CSR, stream: List[int]):
        self.csr = csr
        self.transferCountRead = 0
        self.transferCountWrite = 0

    def read(self, start_addr=0, end_addr=32):
        if start_addr < 0 or end_addr > 32:
            error("address out of bounds")
        
        transferCountRead += (end_addr - start_addr + 1)

        return self.csr.data[start_addr:end_addr+1]

    def write(self, start_addr=0, end_addr=32, data):
        if not isinstance(data, int):
            error("invalid data")
            return False
        if start_addr < 0 or end_addr > 32:
            error("address out of bounds")
            return False
        
        transferCountWrite += (end_addr - start_addr + 1)
        self.csr.data[start_addr:end_addr+1] = data

        return True