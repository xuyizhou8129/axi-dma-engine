"""
Software model of ring_manager.sv.

Naming matches the RTL and CSR register map exactly:
    tail: SW write pointer — CPU advances by writing REG_TAIL after placing a descriptor
    head: HW read pointer  — hardware advances as descriptors are processed (REG_HEAD)

Empty when head == tail.
Full  when (tail + 1) % capacity == head.
"""

from descriptor import descriptor


class RingManager:
    def __init__(self, capacity=8):
        if capacity < 2:
            raise ValueError("Ring capacity must be at least 2")
        self.capacity = capacity
        self._ring    = [None] * capacity
        self.head     = 0   # HW read pointer (mirrors REG_HEAD)
        self.tail     = 0   # SW write pointer (mirrors REG_TAIL)

    # -------------------------------------------------------------------------
    # Software (producer) side
    # -------------------------------------------------------------------------

    def enqueue(self, start_address: int, burst_length: int, datasize: int):
        """
        Place a new descriptor in the ring and advance the tail pointer.
        Raises OverflowError if the ring is full.
        """
        if self.is_full():
            raise OverflowError("Descriptor ring is full")
        desc = descriptor(start_address, burst_length, datasize)
        self._ring[self.tail] = desc
        self.tail = (self.tail + 1) % self.capacity
        return desc

    # -------------------------------------------------------------------------
    # Hardware (consumer) side
    # -------------------------------------------------------------------------

    def peek_next(self):
        """Return the next pending descriptor without consuming it, or None if empty."""
        if self.is_empty():
            return None
        return self._ring[self.head]

    def complete(self):
        """
        Mark the head descriptor as done and advance the head pointer.
        Mirrors the HW advancing REG_HEAD after as_done.
        Raises RuntimeError if the ring is empty.
        """
        if self.is_empty():
            raise RuntimeError("No pending descriptor to complete")
        desc = self._ring[self.head]
        self.head = (self.head + 1) % self.capacity
        return desc

    # -------------------------------------------------------------------------
    # Status queries
    # -------------------------------------------------------------------------

    def is_empty(self):
        return self.head == self.tail

    def is_full(self):
        return (self.tail + 1) % self.capacity == self.head

    def pending_count(self):
        return (self.tail - self.head) % self.capacity

    def __repr__(self):
        return (f"RingManager(capacity={self.capacity}, "
                f"head={self.head}, tail={self.tail}, "
                f"pending={self.pending_count()})")


# Legacy alias (keeps old tests working)
ringManager = RingManager
