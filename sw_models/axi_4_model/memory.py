class SystemMemory:
    def __init__(self, size):
        self.mem = []*size # memory is just an array

    def read(self, addr, size):
        return self.mem[addr:addr+size] # indexes into array returns values

    def write(self, addr, data):
        self.mem[addr:addr+len(data)] = data # indexes into start address and writes data there