class SystemMemory:
    def __init__(self, size):
        self.size = size
        self.mem = []*size # memory is just an array of WORDS, size_of(mem[0]) = 0
