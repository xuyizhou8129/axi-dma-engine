from csr import CSR

class AxiLite:
    def __init__(self, csr: CSR):
        self.csr = csr
        self.read_transaction_count = 0
        self.write_transaction_count = 0

    def read(self, addr):
        self.read_transaction_count += 1
        return self.csr.read(addr)

    def write(self, addr, data):
        self.write_transaction_count += 1
        self.csr.write(addr, data)