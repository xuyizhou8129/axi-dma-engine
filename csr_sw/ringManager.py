from descriptor import Descriptor

class ringManager:
    """
    Software-side descriptor ring buffer.

    The ring has `capacity` slots. SW adds descriptors at the head;
    the DMA engine consumes them from the tail.

        head: next empty slot (SW advances after enqueue)
        tail: oldest pending descriptor (DMA/SW advances after completion)
    """

    def __init__(self, capacity=16):
        if capacity < 2:
            raise ValueError("Ring capacity must be at least 2")
        self.capacity = capacity
        self._ring    = [None] * capacity
        self.head     = 0
        self.tail     = 0

    #  SW-side (producer) 

    def enqueue(self, src_addr, dst_addr, length, direction=0):
        """
        Add a new descriptor to the ring.
        Returns the Descriptor object, or raises OverflowError if the ring is full.
        """
        if self.is_full:
            raise OverflowError("Descriptor ring is full")
        desc = Descriptor(src_addr, dst_addr, length, direction)
        self._ring[self.head] = desc
        self.head = (self.head + 1) % self.capacity
        return desc

    # DMA Engine

    def peek_next(self):
        """Return the next pending descriptor without removing it, or None if empty."""
        if self.is_empty:
            return None
        return self._ring[self.tail]

    def start_next(self):
        """
        Mark the tail descriptor as in-progress and return it.
        The descriptor stays in the ring until complete() is called.
        """
        desc = self.peek_next()
        if desc is None:
            return None
        desc.status = Descriptor.STATUS_IN_PROGRESS
        return desc

    def complete(self, error=False):
        """
        Mark the current tail descriptor as done (or error) and advance the tail.
        Returns the completed Descriptor.
        """
        if self.is_empty:
            raise IndexError("No descriptors to complete")
        desc = self._ring[self.tail]
        desc.status = Descriptor.STATUS_ERROR if error else Descriptor.STATUS_DONE
        self.tail = (self.tail + 1) % self.capacity
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
                f"pending={self.pending_count})")