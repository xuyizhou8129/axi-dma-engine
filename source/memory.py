class SystemMemory:
    """Word-oriented backing store: mem[i] is one 32-bit word."""

    def __init__(self, size: int):
        if size <= 0:
            raise ValueError("SystemMemory size must be positive")
        self.size = size
        self.mem = [0] * size
