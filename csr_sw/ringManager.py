from descriptor import descriptor


class ringManager:
    """
    Software-side descriptor ring buffer.

    The ring has `capacity` slots. SW adds descriptors at the head;
    the DMA engine consumes them from the tail.

        head: next empty slot     (SW advances after enqueue)
        tail: oldest pending slot (DMA advances after complete)
    """

    def __init__(self, capacity=16):
        if capacity < 2:
            raise ValueError("Ring capacity must be at least 2")
        self.capacity     = capacity
        self._ring        = [None] * capacity
        self.head         = 0
        self.tail         = 0
        self._in_progress = False  # True while tail descriptor is being transferred

    # producer

    def enqueue(self, start_address: int, burst_length: int, datasize: int):
        """
        Add a new descriptor to the ring.
        Returns the descriptor object, or raises OverflowError if the ring is full.
        """
        if self.is_full():
            raise OverflowError("Descriptor ring is full")
        desc = descriptor(start_address, burst_length, datasize)
        self._ring[self.head] = desc
        self.head = (self.head + 1) % self.capacity
        return desc

    # DMA engine-side (consumer)

    def peek_next(self):
        """Return the next pending descriptor without consuming it, or None if empty."""
        if self.is_empty():
            return None
        return self._ring[self.tail]

    def start_next(self):
        """
        Mark the tail descriptor as in-progress and return it.
        Returns None if the ring is empty or a transfer is already in progress.
        """
        if self.is_empty() or self._in_progress:
            return None
        self._in_progress = True
        return self._ring[self.tail]

    def complete(self):
        """
        Finish the current in-progress transfer and advance the tail.
        Returns the completed descriptor.
        """
        if not self._in_progress:
            raise RuntimeError("No transfer in progress to complete")
        desc = self._ring[self.tail]
        self.tail = (self.tail + 1) % self.capacity
        self._in_progress = False
        return desc

    # State queries

    def is_empty(self):
        return self.head == self.tail

    def is_full(self):
        return (self.head + 1) % self.capacity == self.tail

    def pending_count(self):
        return (self.head - self.tail) % self.capacity

    def __repr__(self):
        return (f"ringManager(capacity={self.capacity}, "
                f"head={self.head}, tail={self.tail}, "
                f"pending={self.pending_count()}, "
                f"in_progress={self._in_progress})")