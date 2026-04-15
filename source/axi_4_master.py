"""
Simple functional golden model

Input: descriptor / instruction / memory contents / FIFO contents
Output: expected descriptor data, expected memory updates, expected FIFO outputs
Do not model exact FSM state transitions
Do not model exact cycle-by-cycle ready/valid timing
Do not model internal temporary buffers unless they affect visible behavior

Behavior matches rtl/axi_4_master.sv at the transaction boundary:
  - If a handle is pending on df_in, it is served before any dm_in instruction.
  - One handle -> read len 32-bit words from system memory (byte-aligned addr), push
    packed 128-bit descriptor to df_out (same word order as Verilog +: packing).
  - One instruction -> read or write len words: reads go to mid; writes pop mid.

Encodings (same as RTL):
  Handle (40b):   [31:0] addr, [39:32] len (beats)
  Instruction:    [31:0] addr, [39:32] len (beats), [40] rw (1=write, 0=read)
"""


ADDR_WIDTH = 32
DATA_WIDTH = 32
LEN_WIDTH = 8
DESC_WORDS = 4
HANDLE_WIDTH = 40
INSTR_WIDTH = 41
DESC_WIDTH = DESC_WORDS * DATA_WIDTH

RW_BIT = INSTR_WIDTH - 1
LEN_LSB = 32


def pack_handle(addr, len_beats):
    return (addr & 0xFFFFFFFF) | ((len_beats & 0xFF) << 32)


def pack_instruction(addr, len_beats, is_write):
    rw = 1 if is_write else 0
    return (addr & 0xFFFFFFFF) | ((len_beats & 0xFF) << 32) | (rw << 40)


def _word_index(byte_addr):
    if byte_addr & 0x3:
        raise ValueError("AXI address must be 4-byte aligned, got 0x%08x" % byte_addr)
    return (byte_addr >> 2) & 0xFFFFFFFF


def _pack_descriptor_words(words):
    """Pack up to first len words into DESC_WIDTH bits (LSB = word0)."""
    p = 0
    for i, w in enumerate(words):
        if i >= DESC_WORDS:
            break
        p |= (w & 0xFFFFFFFF) << (32 * i)
    return p & ((1 << DESC_WIDTH) - 1)


class AXI4MasterGolden:
    """
    Functional golden for the AXI master: each process_one() completes at most
    one handle or one instruction (never interleaved).
    """

    def __init__(self, memory, df_in_fifo, df_out_fifo, dm_in_fifo, mid_fifo):
        self.memory = memory
        self.df_in = df_in_fifo
        self.df_out = df_out_fifo
        self.dm_in = dm_in_fifo
        self.mid = mid_fifo

    @property
    def idle(self):
        return self.df_in.is_empty() and self.dm_in.is_empty()

    def reset(self):
        """Clear only the golden's notion of work queues if you re-instantiate FIFOs separately."""
        pass

    def process_one(self):
        """
        If work is pending, complete one logical transaction (DF path has priority).
        Returns True if something ran, False if both input queues were empty.
        Raises if FIFOs or memory cannot satisfy the operation (backpressure / OOB).
        """
        if not self.df_in.is_empty():
            self._do_descriptor_fetch()
            return True
        if not self.dm_in.is_empty():
            self._do_instruction()
            return True
        return False

    def _mem_read_words(self, byte_addr, num_beats):
        w0 = _word_index(byte_addr)
        mem = self.memory.mem
        if num_beats == 0:
            return []
        if w0 + num_beats > len(mem):
            raise ValueError("read burst out of bounds")
        out = []
        for i in range(num_beats):
            out.append(mem[w0 + i] & 0xFFFFFFFF)
        return out

    def _mem_write_words(self, byte_addr, words):
        w0 = _word_index(byte_addr)
        mem = self.memory.mem
        if w0 + len(words) > len(mem):
            raise ValueError("write burst out of bounds")
        for i, w in enumerate(words):
            mem[w0 + i] = w & 0xFFFFFFFF

    def _do_descriptor_fetch(self):
        handle = self.df_in.dequeue()
        byte_addr = handle & 0xFFFFFFFF
        num_beats = (handle >> LEN_LSB) & 0xFF
        if num_beats > DESC_WORDS:
            raise ValueError(
                "functional golden: descriptor fetch len=%d exceeds %d words" % (num_beats, DESC_WORDS)
            )
        words = self._mem_read_words(byte_addr, num_beats)
        packed = _pack_descriptor_words(words)
        if self.df_out.is_full():
            raise RuntimeError("df_out FIFO full (backpressure)")
        self.df_out.enqueue(packed)

    def _do_instruction(self):
        instr = self.dm_in.dequeue()
        byte_addr = instr & 0xFFFFFFFF
        num_beats = (instr >> LEN_LSB) & 0xFF
        is_write = bool((instr >> RW_BIT) & 1)
        if num_beats == 0:
            return
        if is_write:
            if len(self.mid) < num_beats:
                raise ValueError(
                    "write instruction needs %d MID words, have %d" % (num_beats, len(self.mid))
                )
            words = [self.mid.dequeue() & 0xFFFFFFFF for _ in range(num_beats)]
            self._mem_write_words(byte_addr, words)
        else:
            free = self.mid.queue_length - len(self.mid)
            if free < num_beats:
                raise RuntimeError(
                    "MID FIFO cannot accept %d beats (only %d free)" % (num_beats, free)
                )
            words = self._mem_read_words(byte_addr, num_beats)
            for w in words:
                self.mid.enqueue(w)


# Backward-compatible alias
AXI4Master = AXI4MasterGolden
