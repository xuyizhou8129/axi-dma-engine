from memory import SystemMemory
from fifo_queue import FIFOQueue
from descriptor import descriptor


WAIT_FOR_ENTER_EACH_CYCLE = True


def tick(cycle, label):
    print(f"\n=== Cycle {cycle}: {label} ===")
    if WAIT_FOR_ENTER_EACH_CYCLE:
        try:
            input("Press Enter to continue...")
        except EOFError:
            pass


def dump_memory(mem, start, end, label):
    print(f"{label} memory[{start}:{end}] -> {mem.mem[start:end]}")


def dump_fifo(fifo, label):
    print(f"{label} ({fifo.id}) depth={len(fifo)} data={fifo.buffer}")


class DataMoverSim:
    def __init__(self, dm_fifo_to_axi: FIFOQueue):
        self.dm_fifo_to_axi = dm_fifo_to_axi

    def copy_from_axi_fifo_to_axi_write_fifo(self, axi_fifo_to_dm: FIFOQueue, count):
        for _ in range(count):
            value = axi_fifo_to_dm.dequeue()
            self.dm_fifo_to_axi.enqueue(value)


class DescriptorFetcherSim:
    def __init__(self, df_fifo_to_axi: FIFOQueue):
        self.df_fifo_to_axi = df_fifo_to_axi

    def df_read(self, axi_fifo_to_df: FIFOQueue):
        word_start_address = axi_fifo_to_df.dequeue()
        word_burst_length = axi_fifo_to_df.dequeue()
        word_datasize = axi_fifo_to_df.dequeue()
        new_descriptor = descriptor(
            start_address=word_start_address,
            burst_length=word_burst_length,
            datasize=word_datasize,
        )
        return new_descriptor

    def df_write_destination_to_axi(self, destination_addr):
        self.df_fifo_to_axi.enqueue(destination_addr)


class AXI4MasterSim:
    def __init__(self, memory: SystemMemory, fifo_to_df: FIFOQueue, fifo_to_dm: FIFOQueue, dm: DataMoverSim, df: DescriptorFetcherSim):
        self.memory = memory
        self.fifo_to_df = fifo_to_df
        self.fifo_to_dm = fifo_to_dm
        self.fifo_from_dm = dm.dm_fifo_to_axi
        self.fifo_from_df = df.df_fifo_to_axi

    def read_memory(self, start_addr, burst_length, datasize, target_fifo: FIFOQueue = None, target="dm"):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI read out of bounds")

        if target_fifo is None:
            if target == "df":
                target_fifo = self.fifo_to_df
            elif target == "dm":
                target_fifo = self.fifo_to_dm
            else:
                raise ValueError("Invalid AXI read target, use 'df' or 'dm'")

        for addr in range(start_addr, end_addr):
            target_fifo.enqueue(self.memory.mem[addr])

    def write_memory(self, start_addr, burst_length, datasize, source_fifo: FIFOQueue = None, source="dm"):
        total_num_bytes = burst_length * datasize
        end_addr = start_addr + total_num_bytes

        if start_addr < 0 or end_addr > self.memory.size:
            raise ValueError("AXI write out of bounds")

        if source_fifo is None:
            if source == "dm":
                source_fifo = self.fifo_from_dm
            elif source == "df":
                source_fifo = self.fifo_from_df
            else:
                raise ValueError("Invalid AXI write source, use 'dm' or 'df'")

        if source_fifo is None:
            raise ValueError("AXI write source FIFO is not connected")

        if len(source_fifo) != total_num_bytes:
            raise ValueError("FIFO size mismatch for AXI write")

        for addr in range(start_addr, end_addr):
            self.memory.mem[addr] = source_fifo.dequeue()


def run_sim():
    cycle = 0

    mem = SystemMemory(size=128)
    # memory.py currently creates [] by default; set a real backing store here.
    mem.mem = [0] * mem.size

    fifo_to_df = FIFOQueue("AXI->DF", queue_length=64)
    fifo_to_dm = FIFOQueue("AXI->DM", queue_length=64)
    fifo_df_to_axi = FIFOQueue("DF->AXI", queue_length=64)
    fifo_dm_to_axi = FIFOQueue("DM->AXI", queue_length=64)

    dm = DataMoverSim(dm_fifo_to_axi=fifo_dm_to_axi)
    df = DescriptorFetcherSim(df_fifo_to_axi=fifo_df_to_axi)
    axi = AXI4MasterSim(mem, fifo_to_df, fifo_to_dm, dm, df)

    # Test scenario
    descriptor_addr = 8
    payload_src_addr = 32
    payload_burst_len = 8
    payload_datasize = 1
    payload_dst_addr = 80

    cycle += 1
    tick(cycle, "Populate memory with descriptor + payload")
    mem.mem[descriptor_addr] = payload_src_addr
    mem.mem[descriptor_addr + 1] = payload_burst_len
    mem.mem[descriptor_addr + 2] = payload_datasize
    for i in range(payload_burst_len * payload_datasize):
        mem.mem[payload_src_addr + i] = 100 + i
    dump_memory(mem, descriptor_addr, descriptor_addr + 3, "Descriptor")
    dump_memory(mem, payload_src_addr, payload_src_addr + payload_burst_len, "Source payload")
    dump_memory(mem, payload_dst_addr, payload_dst_addr + payload_burst_len, "Destination before move")

    cycle += 1
    tick(cycle, "AXI reads descriptor from memory and sends to Descriptor Fetcher")
    axi.read_memory(
        start_addr=descriptor_addr,
        burst_length=3,
        datasize=1,
        target="df",
    )
    dump_fifo(fifo_to_df, "After AXI descriptor read")

    cycle += 1
    tick(cycle, "Descriptor Fetcher unpacks descriptor and sends destination command back to AXI")
    desc = df.df_read(axi.fifo_to_df)
    print(
        "Unpacked descriptor -> "
        f"start_address={desc.start_address}, "
        f"burst_length={desc.burst_length}, "
        f"datasize={desc.datasize}"
    )
    df.df_write_destination_to_axi(payload_dst_addr)
    dump_fifo(fifo_df_to_axi, "DF command FIFO")
    destination_addr_from_df = fifo_df_to_axi.dequeue()
    print(f"AXI popped destination address from DF FIFO: {destination_addr_from_df}")

    cycle += 1
    tick(cycle, "AXI reads payload using descriptor and sends data to Data Mover")
    axi.read_memory(
        start_addr=desc.start_address,
        burst_length=desc.burst_length,
        datasize=desc.datasize,
        target="dm",
    )
    dump_fifo(fifo_to_dm, "AXI->DM payload FIFO")

    cycle += 1
    tick(cycle, "Data Mover forwards payload to AXI writeback FIFO")
    dm.copy_from_axi_fifo_to_axi_write_fifo(
        axi_fifo_to_dm=axi.fifo_to_dm,
        count=desc.burst_length * desc.datasize,
    )
    dump_fifo(fifo_dm_to_axi, "DM->AXI write FIFO")

    cycle += 1
    tick(cycle, "AXI writes DM data to destination addresses in memory")
    axi.write_memory(
        start_addr=destination_addr_from_df,
        burst_length=desc.burst_length,
        datasize=desc.datasize,
        source="dm",
    )
    dump_memory(mem, payload_dst_addr, payload_dst_addr + payload_burst_len, "Destination after move")

    cycle += 1
    tick(cycle, "Final check")
    src = mem.mem[payload_src_addr : payload_src_addr + payload_burst_len]
    dst = mem.mem[payload_dst_addr : payload_dst_addr + payload_burst_len]
    print(f"Source payload      : {src}")
    print(f"Destination payload : {dst}")
    if src == dst:
        print("PASS: payload copied correctly")
    else:
        print("FAIL: payload mismatch")


if __name__ == "__main__":
    run_sim()
