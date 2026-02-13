class FIFOQueue:
    def __init__(self, id, queue_length: int):
        if queue_length <= 0:
            raise ValueError("FIFO queue_length must be positive")
        
        self.id = id
        self.queue_length = queue_length
        self.buffer = []
    
    def is_empty(self):
        return len(self.buffer) == 0
    
    def is_full(self):
        return len(self.buffer) == self.queue_length

    def enqueue(self, value):
        if self.is_full():
            raise RuntimeError(f"{self.id} FIFO overflow")
        self.buffer.append(value)

    def dequeue(self):
        if self.is_empty():
            raise RuntimeError(f"{self.id} FIFO empty")
        return self.buffer.pop(0)

    def clear(self):
        self.buffer.clear()

    def __len__(self):
        return len(self.buffer)
