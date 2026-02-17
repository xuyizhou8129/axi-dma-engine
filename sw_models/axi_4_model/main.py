import os
import sys
import types
import importlib

from memory import SystemMemory
from fifo_queue import FIFOQueue


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


def pack_descriptor(start_address, burst_length, datasize):
    # DescriptorFetcher.df_read() expects packed bits:
    # [31:0] start_address, [39:32] burst_length, [42:40] datasize
    return (start_address & 0xFFFFFFFF) | ((burst_length & 0xFF) << 32) | ((datasize & 0x7) << 40)


def import_project_classes():
    # Ensure repo root is in sys.path so "sw_models...." imports work.
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)

    # Temporary stubs to break circular imports between:
    # axi_4_master <-> data_mover and data_mover <-> sram_controller.
    data_mover_stub = types.ModuleType("data_mover")
    descriptor_fetcher_stub = types.ModuleType("descriptor_fetcher")
    sram_controller_stub = types.ModuleType("sw_models.axi_4_model.sram_controller")

    class _DataMoverStub:
        pass

    class _DescriptorFetcherStub:
        pass

    class _SRAMControllerStub:
        def __init__(self, fifo_to_dm):
            self.fifo_to_dm = fifo_to_dm

    data_mover_stub.DataMover = _DataMoverStub
    descriptor_fetcher_stub.DescriptorFetcher = _DescriptorFetcherStub
    sram_controller_stub.SRAMController = _SRAMControllerStub

    sys.modules["data_mover"] = data_mover_stub
    sys.modules["descriptor_fetcher"] = descriptor_fetcher_stub
    sys.modules["sw_models.axi_4_model.sram_controller"] = sram_controller_stub

    from axi_4_master import AXI4Master

    # Load real modules now that AXI4Master exists.
    del sys.modules["data_mover"]
    del sys.modules["descriptor_fetcher"]
    # Keep SRAMController stub for DataMover import compatibility.
    DataMover = importlib.import_module("data_mover").DataMover
    DescriptorFetcher = importlib.import_module("descriptor_fetcher").DescriptorFetcher
    SRAMController = sys.modules["sw_models.axi_4_model.sram_controller"].SRAMController

    return AXI4Master, DataMover, DescriptorFetcher, SRAMController


def run_sim():
    AXI4Master, DataMover, DescriptorFetcher, SRAMController = import_project_classes()

    cycle = 0

    mem = SystemMemory(size=128)
    # memory.py currently initializes an empty list; set backing storage here.
    mem.mem = [0] * mem.size

    fifo_to_df = FIFOQueue("AXI->DF", queue_length=64)
    fifo_to_dm = FIFOQueue("AXI->DM", queue_length=64)
    fifo_df_to_axi = FIFOQueue("DF->AXI", queue_length=64)
    fifo_dm_to_axi = FIFOQueue("DM->AXI", queue_length=64)
    fifo_dm_to_sram = FIFOQueue("DM->SRAM", queue_length=64)
    fifo_sram_to_dm = FIFOQueue("SRAM->DM", queue_length=64)

    # Instantiate modules (AXI/DM/DF use cross-references, so wire in two phases).
    sram = SRAMController(fifo_to_dm=fifo_sram_to_dm)
    dm = DataMover(None, sram, fifo_dm_to_axi, fifo_dm_to_sram)
    dm.dm_fifo_to_axi = dm.dm_axi4_write_fifo
    df = DescriptorFetcher(None, fifo_df_to_axi)
    axi = AXI4Master(mem, fifo_to_df, fifo_to_dm, dm, df)
    dm.axi4 = axi
    df.axi4 = axi

    # Test scenario
    descriptor_addr = 9
    payload_src_addr = 32
    payload_burst_len = 12
    payload_datasize = 3
    payload_dst_addr = 82

    cycle += 1
    tick(cycle, "Populate memory with descriptor + payload")
    mem.mem[descriptor_addr] = pack_descriptor(payload_src_addr, payload_burst_len, payload_datasize)
    for i in range(payload_burst_len * payload_datasize):
        mem.mem[payload_src_addr + i] = 100 + i
    dump_memory(mem, descriptor_addr, descriptor_addr + 1, "Packed descriptor")
    dump_memory(mem, payload_src_addr, payload_src_addr + payload_burst_len, "Source payload")
    dump_memory(mem, payload_dst_addr, payload_dst_addr + payload_burst_len, "Destination before move")

    cycle += 1
    tick(cycle, "AXI reads descriptor from memory and sends to Descriptor Fetcher")
    axi.read_memory(
        start_addr=descriptor_addr,
        burst_length=1,
        datasize=1,
        target="df",
    )
    dump_fifo(fifo_to_df, "After AXI descriptor read")

    cycle += 1
    tick(cycle, "Descriptor Fetcher unpacks descriptor and sends destination command back to AXI")
    desc = df.df_read()
    print(
        "Unpacked descriptor -> "
        f"start_address={desc.start_address}, "
        f"burst_length={desc.burst_length}, "
        f"datasize={desc.datasize}"
    )
    df.df_write(payload_dst_addr)
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
    tick(cycle, "Data Mover reads AXI FIFO and pushes into DM->AXI FIFO")
    transfer_count = desc.burst_length * desc.datasize
    for _ in range(transfer_count):
        value = dm.read_from_axi4_master(desc.start_address, desc.burst_length, desc.datasize)
        dm.dm_axi4_write_fifo.enqueue(value)
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
