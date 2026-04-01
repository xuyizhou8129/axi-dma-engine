from fifo_queue import FIFOQueue
from memory import SystemMemory
from sram_controller import SRAMController
from ring_manager import RingManager
from csr import CSR
from irq import IRQ
from descriptor_fetcher import DescriptorFetcher
from data_mover import DataMover
from axi_4_master import AXI4Master
from structs import Descriptor

class DMATop:
    """
    Top-level wrapper that instantiates and connects all the DMA engine components.
    """
    def __init__(self, sys_mem_size=1024, sram_size=1024):
        # 1. Instantiate Modules
        self.sys_mem = SystemMemory(sys_mem_size)
        self.sram_controller = SRAMController(sram_size)
        
        self.csr = CSR()
        self.irq = IRQ(self.csr)
        
        # 2. Instantiate FIFOs
        self.rm_handle_fifo = FIFOQueue("RM_Handle", 16)
        self.axi_handle_fifo = FIFOQueue("AXI_Handle", 16)
        self.axi_callback_fifo = FIFOQueue("AXI_Callback_Words", 64)
        
        self.df_dm_fifo = FIFOQueue("DF_DM_Desc", 16)
        
        self.axi_inst_fifo = FIFOQueue("AXI_Inst", 16)
        self.sram_inst_fifo = FIFOQueue("SRAM_Inst", 16)
        
        self.data_fifo = FIFOQueue("Shared_Data", 128) # Shared between SRAM and SysMem

        # 3. Initialize Components
        self.ring_manager = RingManager(self.csr, self.rm_handle_fifo)
        
        self.descriptor_fetcher = DescriptorFetcher(
            self.rm_handle_fifo,
            self.axi_handle_fifo,
            self.axi_callback_fifo,
            self.df_dm_fifo
        )
        
        self.data_mover = DataMover(
            self.df_dm_fifo,
            self.axi_inst_fifo,
            self.sram_inst_fifo,
            self.ring_manager
        )
        
        self.axi_4_master = AXI4Master(
            self.sys_mem,
            self.axi_handle_fifo,
            self.axi_inst_fifo,
            self.axi_callback_fifo,
            self.data_fifo,
            self.data_mover
        )
        
        # Link SRAM controller connections
        self.sram_controller.link(
            self.sram_inst_fifo,
            self.data_fifo,
            self.data_mover
        )

    def step(self):
        """
        Simulate a single clock cycle update across all modules.
        """
        # Module logic execution (Order can vary in real synchronous RTL, here we execute them)
        self.ring_manager.update()
        self.descriptor_fetcher.update()
        self.data_mover.update()
        self.axi_4_master.update()
        self.sram_controller.update()
