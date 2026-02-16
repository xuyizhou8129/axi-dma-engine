class SystemMemory:
    # each index holds one 32-bit word
    def __init__(self, size):
        self.size = size
        self.mem = []*size # memory is just an array
