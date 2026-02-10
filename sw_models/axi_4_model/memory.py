class SystemMemory:
    def __init__(self, size):
        self.mem = bytearray(size)

    def read(self, addr, size):
        return self.mem[addr:addr+size]

    def write(self, addr, data):
        self.mem[addr:addr+len(data)] = data