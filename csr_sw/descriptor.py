class Descriptor:
    """A single DMA transfer descriptor."""

    STATUS_PENDING     = 'pending'
    STATUS_IN_PROGRESS = 'in_progress'
    STATUS_DONE        = 'done'
    STATUS_ERROR       = 'error'

    def __init__(self, src_addr, dst_addr, length, direction=0):
        """
        Args:
            src_addr:  Source address (must be 4-byte aligned)
            dst_addr:  Destination address (must be 4-byte aligned)
            length:    Transfer length in bytes (must be multiple of 4)
            direction: 0 = Memory->SRAM, 1 = SRAM->Memory
        """
        self.src_addr  = src_addr
        self.dst_addr  = dst_addr
        self.length    = length
        self.direction = direction
        self.status    = self.STATUS_PENDING

    def __repr__(self):
        return (f"Descriptor(src=0x{self.src_addr:08X}, dst=0x{self.dst_addr:08X}, "
                f"len=0x{self.length:X}, dir={self.direction}, status={self.status})")