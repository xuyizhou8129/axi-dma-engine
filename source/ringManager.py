"""
Software model aligned with ring_manager.sv + descriptor fetch path.

Descriptors live in SystemMemory (not inside this class). Layout matches RTL:
    byte address = baseaddr + slot_index * DESCRIPTOR_SIZE_BYTES

Producer (enqueue):
    Pack a Descriptor into memory at the current tail slot, then advance REG_TAIL in CSR.

Consumer (fetch_next_descriptor):
    Same as HW: issue handle (baseaddr + head * 16) via DescriptorFetcher, run
    AXI4MasterGolden until the packed descriptor appears, then return Descriptor.
    Call complete() to advance REG_HEAD after the data mover finishes (as_done).

Requires DescriptorFetcher + AXI4MasterGolden wired to the same SystemMemory and FIFOs
as in a real testbench (see instructions.txt).
"""

from descriptor import DESC_WORDS, Descriptor
from descriptor_fetcher import DescriptorFetcher
from axi_4_master import AXI4MasterGolden
from memory import SystemMemory
from csr import CSR

# Matches rtl/ring_manager.sv localparam DESCRIPTOR_SIZE
DESCRIPTOR_SIZE_BYTES = 16


class RingManager:
    def __init__(
        self,
        memory: SystemMemory,
        csr: CSR,
        descriptor_fetcher: DescriptorFetcher,
        axi_golden: AXI4MasterGolden,
    ):
        self.mem = memory
        self.csr = csr
        self.df = descriptor_fetcher
        self.golden = axi_golden
        # Sticky error flag mirroring ring_manager.sv int_status_error.
        # Set by signal_df_error() (df_error pulse), cleared by clear_error()
        # (CSR error_clear pulse from IRQ_CLEAR[1] write).
        self.int_status_error = False
        # Wire ourselves into the CSR so IRQ_CLEAR[1] reaches us.
        try:
            self.csr.attach_ring_manager(self)
        except AttributeError:
            pass  # older CSR build without the hook

    def _ringlen(self):
        r = self.csr.ringlen() & 0xFFFFFFFF
        if r == 0:
            raise ValueError("CSR REG_RINGLEN must be non-zero before ring operations")
        return r

    def _base(self):
        return self.csr.baseaddr() & 0xFFFFFFFF

    def _slot_byte_addr(self, slot_index: int) -> int:
        return self._base() + (slot_index % self._ringlen()) * DESCRIPTOR_SIZE_BYTES

    def _write_desc_to_mem(self, byte_addr: int, desc: Descriptor) -> None:
        w0 = (byte_addr >> 2) & 0xFFFFFFFF
        if w0 + DESC_WORDS > self.mem.size:
            raise ValueError("Descriptor write out of bounds of SystemMemory")
        self.mem.mem[w0 + 0] = desc.w0
        self.mem.mem[w0 + 1] = desc.w1
        self.mem.mem[w0 + 2] = desc.w2
        self.mem.mem[w0 + 3] = desc.w3

    # -------------------------------------------------------------------------
    # Producer — place descriptor in memory and advance tail (like SW + CSR)
    # -------------------------------------------------------------------------

    def enqueue(self, desc: Descriptor):
        """
        Write descriptor words to system memory at the tail slot and advance REG_TAIL.
        """
        rlen = self._ringlen()
        if self.is_full():
            raise OverflowError("Descriptor ring is full")

        tail = self.csr.read(self.csr.REG_TAIL) & 0xFFFFFFFF
        ti = tail % rlen

        self._write_desc_to_mem(self._slot_byte_addr(ti), desc)
        new_tail = (tail + 1) % rlen
        self.csr.write(self.csr.REG_TAIL, new_tail)
        return desc

    # -------------------------------------------------------------------------
    # Consumer — DescriptorFetcher + AXI4MasterGolden (same as HW DF + AXI path)
    # -------------------------------------------------------------------------

    def _fetch_descriptor_impl(self, max_steps=256):
        """Submit the current head's handle to AXI and return the fetched descriptor."""
        head = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        rlen = self._ringlen()
        ti = head % rlen
        byte_addr = self._slot_byte_addr(ti)

        self.df.submit_handle(byte_addr, DESC_WORDS)

        steps = 0
        while not self.df.has_descriptor():
            if not self.golden.process_one():
                raise RuntimeError(
                    "AXI4MasterGolden could not make progress (empty queues / deadlock?)"
                )
            steps += 1
            if steps > max_steps:
                raise RuntimeError("_fetch_descriptor_impl: exceeded max_steps")

        return self.df.take_descriptor()

    def fetch_next_descriptor(self, max_steps=256):
        """
        Issue rm_df-style handle, run golden until descriptor is in df_out, return it.
        Does not advance head — call complete() after the transfer completes.

        Mirrors ring_manager.sv fetch_req_valid gating: when the sticky error
        flag is set we refuse to issue, exactly as the HW gate does.
        """
        if self.is_empty():
            return None
        if self.int_status_error:
            return None
        return self._fetch_descriptor_impl(max_steps)

    def fetch_inflight_descriptor(self, max_steps=256):
        """
        Bypass the int_status_error gate and fetch the next descriptor.
        Mirrors descriptor_fetcher s_error draining df_out: descriptors already
        issued to AXI before df_error fired are still forwarded to the data mover.
        Only call this for descriptors known to be in-flight when the error fired.
        """
        if self.is_empty():
            return None
        return self._fetch_descriptor_impl(max_steps)

    def complete(self):
        """
        Advance head after descriptor work finishes (mirrors as_done / REG_HEAD update).

        In RTL the head pointer actually advances on issue (fetch_req_valid &&
        fetch_req_ready), so a bad descriptor — even though it is dropped at
        the descriptor fetcher — still consumes its ring slot. We model that
        by calling complete() for both successful and dropped descriptors.
        """
        if self.is_empty():
            raise RuntimeError("No pending descriptor to complete")

        head = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        rlen = self._ringlen()
        hi = head % rlen
        new_head = (hi + 1) % rlen
        self.csr.hw_set_head(new_head)

    # -------------------------------------------------------------------------
    # Error path (mirrors ring_manager.sv int_status_error + CSR error_clear)
    # -------------------------------------------------------------------------

    def signal_df_error(self):
        """
        Mirror df_error pulse: set sticky internal error and propagate the
        error_set pulse to CSR (latches STATUS.error and IRQ_STATUS.error).
        """
        self.int_status_error = True
        self.csr.hw_set_error()

    def clear_error(self):
        """Mirror error_clear pulse from CSR (IRQ_CLEAR[1] write)."""
        self.int_status_error = False

    def has_error(self):
        return self.int_status_error

    # -------------------------------------------------------------------------
    # Status
    # -------------------------------------------------------------------------

    def is_empty(self):
        h = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        t = self.csr.read(self.csr.REG_TAIL) & 0xFFFFFFFF
        return h == t

    def is_full(self):
        rlen = self._ringlen()
        head = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        tail = self.csr.read(self.csr.REG_TAIL) & 0xFFFFFFFF
        hi = head % rlen
        ti = tail % rlen
        return (ti + 1) % rlen == hi

    def pending_count(self):
        rlen = self._ringlen()
        head = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        tail = self.csr.read(self.csr.REG_TAIL) & 0xFFFFFFFF
        hi = head % rlen
        ti = tail % rlen
        return (ti - hi) % rlen

    def next_fetch_byte_addr(self):
        """Address the HW would put on rm_df_addr for the current head (debug)."""
        if self.is_empty():
            return None
        head = self.csr.read(self.csr.REG_HEAD) & 0xFFFFFFFF
        rlen = self._ringlen()
        return self._slot_byte_addr(head % rlen)

    def __repr__(self):
        return (
            f"RingManager(base=0x{self._base():08x}, "
            f"head={self.csr.read(self.csr.REG_HEAD)}, "
            f"tail={self.csr.read(self.csr.REG_TAIL)}, "
            f"pending={self.pending_count()})"
        )


# Legacy alias for old class name
ringManager = RingManager
