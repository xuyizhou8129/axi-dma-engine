from dma_top import DMATop
from csr import CSR

def write_descriptor(sys_mem, addr, src, dst, length, flags):
    """Helper to write a 16-byte descriptor struct to System Memory."""
    sys_mem.write_word(addr + 0, src)
    sys_mem.write_word(addr + 4, dst)
    sys_mem.write_word(addr + 8, length)
    sys_mem.write_word(addr + 12, flags)

def test_sram_to_sys_memory_workflow():
    """Simulates Data Mover transferring data from SRAM back to System Memory."""
    print("\n--- Running SRAM -> SysMem Test ---")
    dma = DMATop(sys_mem_size=1024, sram_size=1024)
    sys_ring_base = 0x100
    
    # 1. Setup CSRs
    dma.csr.write_register(CSR.RINGLEN_REG, 4)
    dma.csr.write_register(CSR.BASEADDR_REG, sys_ring_base)
    dma.csr.write_register(CSR.CTRL_REG, 1) # Enable DMA
    
    # 2. Put target data into SRAM
    dma.sram_controller.write_word(0x300, 0x11223344)
    dma.sram_controller.write_word(0x304, 0x55667788)
    dma.sram_controller.write_word(0x308, 0x99AABBCC)
    
    # 3. Create Descriptor: Src=0x300(SRAM), Dst=0x80(Sys), Len=3 words, Dir=0(SRAM->Sys)
    write_descriptor(dma.sys_mem, sys_ring_base, 0x300, 0x80, 3, 0)
    
    # 4. Ring Manager Enqueue (Advance TAIL by 1)
    dma.ring_manager.sync_capacity() # Load RM's queue bounds
    tail = dma.csr.get_tail()
    dma.ring_manager.owner_bits[tail] = 0 # Hand over to DMA
    dma.csr.write_register(CSR.TAIL_REG, tail + 1)
    
    # 5. Tick Clock
    for cycle in range(100):
        dma.step()
        if dma.ring_manager.owner_bits[tail] == 1:
            print(f"Transfer finished in {cycle} cycles.")
            break
            
    # 6. Verify System Memory received the data
    assert dma.sys_mem.read_word(0x80) == 0x11223344
    assert dma.sys_mem.read_word(0x84) == 0x55667788
    assert dma.sys_mem.read_word(0x88) == 0x99AABBCC
    print("Success: Data moved from SRAM to System Memory!")


def test_multiple_chained_descriptors():
    """Simulates queuing up multiple descriptors in the ring at once to test pipelining."""
    print("\n--- Running Multi-Descriptor Pipeline Test ---")
    dma = DMATop(sys_mem_size=1024, sram_size=1024)
    sys_ring_base = 0x100
    
    # Setup CSRs with length 4
    dma.csr.write_register(CSR.RINGLEN_REG, 4)
    dma.csr.write_register(CSR.BASEADDR_REG, sys_ring_base)
    dma.csr.write_register(CSR.CTRL_REG, 1)
    
    # 1st Transfer: Sys(0x40) -> SRAM(0x200), length 2
    dma.sys_mem.write_word(0x40, 0xDEADBEEF)
    dma.sys_mem.write_word(0x44, 0xCAFEBABE)
    write_descriptor(dma.sys_mem, sys_ring_base + 0, 0x40, 0x200, 2, 1)
    
    # 2nd Transfer: Sys(0x50) -> SRAM(0x210), length 2
    dma.sys_mem.write_word(0x50, 0xFEEDFACE)
    dma.sys_mem.write_word(0x54, 0x01234567)
    write_descriptor(dma.sys_mem, sys_ring_base + 16, 0x50, 0x210, 2, 1) # 16 bytes offset for next slot
    
    # Enqueue both to the ring
    dma.ring_manager.sync_capacity()
    tail = dma.csr.get_tail() # starts at 0
    dma.ring_manager.owner_bits[0] = 0
    dma.ring_manager.owner_bits[1] = 0
    dma.csr.write_register(CSR.TAIL_REG, tail + 2) # Now TAIL is 2
    
    # Tick Clock
    for cycle in range(150):
        dma.step()
        # Wait until BOTH descriptors are yielded back to CPU
        if dma.ring_manager.owner_bits[0] == 1 and dma.ring_manager.owner_bits[1] == 1:
            print(f"Both transfers finished in {cycle} cycles.")
            break
            
    # Verify SRAM contents
    assert dma.sram_controller.read_word(0x200) == 0xDEADBEEF
    assert dma.sram_controller.read_word(0x204) == 0xCAFEBABE
    assert dma.sram_controller.read_word(0x210) == 0xFEEDFACE
    assert dma.sram_controller.read_word(0x214) == 0x01234567
    
    # Verify the HEAD moved cleanly wrapping or advancing
    assert dma.csr.get_head() == 2
    print("Success: Both descriptors executed through the pipeline perfectly!")


if __name__ == "__main__":
    test_sram_to_sys_memory_workflow()
    test_multiple_chained_descriptors()
