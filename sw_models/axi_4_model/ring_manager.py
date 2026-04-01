from csr import CSR
from structs import Handle

class RingManager:
    def __init__(self, csr: CSR, handle_fifo):
        self.csr = csr
        self.handle_fifo = handle_fifo
        self.owner_bits = []
        self.capacity = 0
        self.fetch_head = 0

    def sync_capacity(self):
        new_len = self.csr.get_ringlen()
        if new_len > self.capacity:
            self.owner_bits.extend([1] * (new_len - self.capacity))
            self.capacity = new_len
        elif new_len < self.capacity:
            self.owner_bits = self.owner_bits[:new_len]
            self.capacity = new_len

    def update(self):
        if not self.csr.is_enabled():
            return
            
        self.sync_capacity()
        if self.capacity == 0:
            return

        tail = self.csr.get_tail()

        # If DMA owns the fetch_head slot (meaning 0)
        if self.owner_bits[self.fetch_head] == 0 and self.fetch_head != tail:
            if not self.handle_fifo.is_full():
                base_addr = self.csr.get_baseaddr()
                desc_addr = base_addr + (self.fetch_head * 16)
                
                handle = Handle(desc_addr, True)
                self.handle_fifo.enqueue(handle)
                
                self.fetch_head = (self.fetch_head + 1) % self.capacity

    def mark_completed(self):
        head_completed = self.csr.get_head()
        self.owner_bits[head_completed] = 1
        new_head = (head_completed + 1) % self.capacity
        self.csr.set_head(new_head)
        
        if new_head == self.csr.get_tail():
            self.csr.set_empty_irq()
