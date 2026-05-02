# Waveform for tb_dma_top — built from sim/signals_needed.txt
# Sections: dma_top (CSR, ring_mgr, IRQ) -> movement_top (DF, DM FIFOs, AXI, SRAM, BRAM)
#           AXI-Lite (CSR), AXI4 (system mem), model_sys_mem
#
# Hierarchy prefix: /tb_dma_top/dut = dma_top

view wave
add log -r /*
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

# =============================================================================
# Testbench
# =============================================================================
add wave -noupdate -group TB_instance /tb_dma_top/clk
add wave -noupdate -group TB_instance /tb_dma_top/rst_n
add wave -noupdate -group TB_instance /tb_dma_top/irq_rm_empty
add wave -noupdate -group TB_instance /tb_dma_top/irq_rm_error
add wave -noupdate -group TB_instance /tb_dma_top/irq_block
add wave -noupdate -group TB_instance -radix unsigned /tb_dma_top/irq_block_status

# =============================================================================
# dma_top: CSR <-> Ring manager interface (csr_ring_manager_if)
# =============================================================================
add wave -noupdate -group Ring_Manager_IF_instance -radix hex /tb_dma_top/dut/ring_mgr/baseaddr
add wave -noupdate -group Ring_Manager_IF_instance -radix unsigned /tb_dma_top/dut/ring_mgr/ringlen
add wave -noupdate -group Ring_Manager_IF_instance -radix unsigned /tb_dma_top/dut/ring_mgr/tail
add wave -noupdate -group Ring_Manager_IF_instance -radix unsigned /tb_dma_top/dut/ring_mgr/head
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/enable
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/reset
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/irq_en
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/error_clear
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/busy
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/ring_empty
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/irq_empty_set
add wave -noupdate -group Ring_Manager_IF_instance /tb_dma_top/dut/ring_mgr/error_set

# =============================================================================
# CSR (internal shadow regs + AXI-Lite state) — rtl/csr.sv
# =============================================================================
add wave -noupdate -group CSR_instance -radix hex /tb_dma_top/dut/u_csr/reg_baseaddr
add wave -noupdate -group CSR_instance -radix unsigned /tb_dma_top/dut/u_csr/reg_ringlen
add wave -noupdate -group CSR_instance -radix unsigned /tb_dma_top/dut/u_csr/reg_tail
add wave -noupdate -group CSR_instance -radix hex /tb_dma_top/dut/u_csr/reg_ctrl
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/reg_status_error
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/reg_irq_empty
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/reg_irq_error
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/bvalid
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/rvalid
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/aw_pending
add wave -noupdate -group CSR_instance /tb_dma_top/dut/u_csr/w_pending
add wave -noupdate -group CSR_instance -radix hex /tb_dma_top/dut/u_csr/awaddr
add wave -noupdate -group CSR_instance -radix hex /tb_dma_top/dut/u_csr/wdata

# =============================================================================
# Ring manager (internal) — rtl/ring_manager.sv
# =============================================================================
add wave -noupdate -group Ring_Manager_instance -radix unsigned /tb_dma_top/dut/u_ring_manager/inflight_count
add wave -noupdate -group Ring_Manager_instance /tb_dma_top/dut/u_ring_manager/was_empty
add wave -noupdate -group Ring_Manager_instance /tb_dma_top/dut/u_ring_manager/int_status_error
add wave -noupdate -group Ring_Manager_instance /tb_dma_top/dut/u_ring_manager/sw_rst_enable
add wave -noupdate -group Ring_Manager_instance -radix hex /tb_dma_top/dut/u_ring_manager/head_ptr_next

# =============================================================================
# IRQ block — rtl/IRQ.sv
# =============================================================================
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/empty_event
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/error_event
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/irq_en
add wave -noupdate -group IRQ_instance -radix unsigned /tb_dma_top/dut/u_irq/irq_clear
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/status_empty
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/status_error
add wave -noupdate -group IRQ_instance -radix unsigned /tb_dma_top/dut/u_irq/irq_status
add wave -noupdate -group IRQ_instance /tb_dma_top/dut/u_irq/irq

# =============================================================================
# dma_top: wires to movement_top (RM <-> DF path)
# =============================================================================
add wave -noupdate -group RM_to_movement_wires_instance -radix hex /tb_dma_top/dut/rm_df_addr
add wave -noupdate -group RM_to_movement_wires_instance /tb_dma_top/dut/fetch_req_valid
add wave -noupdate -group RM_to_movement_wires_instance /tb_dma_top/dut/fetch_req_ready
add wave -noupdate -group RM_to_movement_wires_instance /tb_dma_top/dut/df_error
add wave -noupdate -group RM_to_movement_wires_instance /tb_dma_top/dut/dm_done

# =============================================================================
# movement_top: rm_df_if (ties to descriptor_fetcher modport df)
# =============================================================================
add wave -noupdate -group RM_DF_interface_instance -radix hex /tb_dma_top/dut/u_movement/rm_df/rm_df_addr
add wave -noupdate -group RM_DF_interface_instance /tb_dma_top/dut/u_movement/rm_df/fetch_req_valid
add wave -noupdate -group RM_DF_interface_instance /tb_dma_top/dut/u_movement/rm_df/fetch_req_ready
add wave -noupdate -group RM_DF_interface_instance /tb_dma_top/dut/u_movement/rm_df/df_error

# =============================================================================
# Descriptor fetcher — rtl/descriptor_fetcher.sv (u_df)
# =============================================================================
add wave -noupdate -group Descriptor_Fetcher_instance -radix unsigned /tb_dma_top/dut/u_movement/u_df/state
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/df_error_c
add wave -noupdate -group Descriptor_Fetcher_instance -radix hex /tb_dma_top/dut/u_movement/u_df/desc_end_addr
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/df_in_wr_en
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/df_in_full
add wave -noupdate -group Descriptor_Fetcher_instance -radix hex /tb_dma_top/dut/u_movement/u_df/df_in_din
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/df_out_rd_en
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/df_out_empty
add wave -noupdate -group Descriptor_Fetcher_instance -radix hex /tb_dma_top/dut/u_movement/u_df/df_out_dout
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/dm_in_wr_en
add wave -noupdate -group Descriptor_Fetcher_instance /tb_dma_top/dut/u_movement/u_df/dm_in_full
add wave -noupdate -group Descriptor_Fetcher_instance -radix hex /tb_dma_top/dut/u_movement/u_df/dm_in_din

# =============================================================================
# Data mover path: 128b descriptor -> 41b instr -> parallel DM FIFOs + MID FIFO
# =============================================================================
add wave -noupdate -group Data_Mover_instance -radix hex /tb_dma_top/dut/u_movement/dm_in_din
add wave -noupdate -group Data_Mover_instance -radix hex /tb_dma_top/dut/u_movement/dm_in_instr
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/dm_full_axi
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/dm_full_sram
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/dm_in_full
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/sram_done
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/axi_done
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/handshake_done
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/handshake_done_d
add wave -noupdate -group Data_Mover_instance /tb_dma_top/dut/u_movement/dm_done

# DM FIFO (AXI side) — u_dm_fifo_axi
add wave -noupdate -group Data_Mover_AXI_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_axi/wr_en
add wave -noupdate -group Data_Mover_AXI_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_axi/rd_en
add wave -noupdate -group Data_Mover_AXI_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_axi/full
add wave -noupdate -group Data_Mover_AXI_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_axi/empty
add wave -noupdate -group Data_Mover_AXI_FIFO_instance -radix hex /tb_dma_top/dut/u_movement/u_dm_fifo_axi/dout

# DM FIFO (SRAM side) — u_dm_fifo_sram
add wave -noupdate -group Data_Mover_SRAM_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_sram/wr_en
add wave -noupdate -group Data_Mover_SRAM_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_sram/rd_en
add wave -noupdate -group Data_Mover_SRAM_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_sram/full
add wave -noupdate -group Data_Mover_SRAM_FIFO_instance /tb_dma_top/dut/u_movement/u_dm_fifo_sram/empty
add wave -noupdate -group Data_Mover_SRAM_FIFO_instance -radix hex /tb_dma_top/dut/u_movement/u_dm_fifo_sram/dout

# MID FIFO (shared AXI / SRAM data path)
add wave -noupdate -group MID_FIFO_instance /tb_dma_top/dut/u_movement/u_mid_fifo/wr_en
add wave -noupdate -group MID_FIFO_instance /tb_dma_top/dut/u_movement/u_mid_fifo/rd_en
add wave -noupdate -group MID_FIFO_instance /tb_dma_top/dut/u_movement/u_mid_fifo/full
add wave -noupdate -group MID_FIFO_instance /tb_dma_top/dut/u_movement/u_mid_fifo/empty
add wave -noupdate -group MID_FIFO_instance -radix hex /tb_dma_top/dut/u_movement/u_mid_fifo/din
add wave -noupdate -group MID_FIFO_instance -radix hex /tb_dma_top/dut/u_movement/u_mid_fifo/dout

# DF <-> AXI FIFOs (handles + packed descriptors)
add wave -noupdate -group DF_in_FIFO_instance /tb_dma_top/dut/u_movement/u_df_in_fifo/wr_en
add wave -noupdate -group DF_in_FIFO_instance /tb_dma_top/dut/u_movement/u_df_in_fifo/rd_en
add wave -noupdate -group DF_in_FIFO_instance /tb_dma_top/dut/u_movement/u_df_in_fifo/full
add wave -noupdate -group DF_in_FIFO_instance /tb_dma_top/dut/u_movement/u_df_in_fifo/empty
add wave -noupdate -group DF_out_FIFO_instance /tb_dma_top/dut/u_movement/u_df_out_fifo/wr_en
add wave -noupdate -group DF_out_FIFO_instance /tb_dma_top/dut/u_movement/u_df_out_fifo/rd_en
add wave -noupdate -group DF_out_FIFO_instance /tb_dma_top/dut/u_movement/u_df_out_fifo/full
add wave -noupdate -group DF_out_FIFO_instance /tb_dma_top/dut/u_movement/u_df_out_fifo/empty

# =============================================================================
# AXI4 master — rtl/axi_4_master.sv (u_axi)
# =============================================================================
add wave -noupdate -group AXI4_Master_instance -radix unsigned /tb_dma_top/dut/u_movement/u_axi/state
add wave -noupdate -group AXI4_Master_instance /tb_dma_top/dut/u_movement/u_axi/sram_done
add wave -noupdate -group AXI4_Master_instance /tb_dma_top/dut/u_movement/u_axi/axi_done
add wave -noupdate -group AXI4_Master_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/cur_addr
add wave -noupdate -group AXI4_Master_instance -radix unsigned /tb_dma_top/dut/u_movement/u_axi/cur_len
add wave -noupdate -group AXI4_Master_instance /tb_dma_top/dut/u_movement/u_axi/cur_write
add wave -noupdate -group AXI4_Master_instance -radix unsigned /tb_dma_top/dut/u_movement/u_axi/beat_idx
add wave -noupdate -group AXI4_Master_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/desc_buf

add wave -noupdate -group AXI4_Master_DF_path_instance /tb_dma_top/dut/u_movement/u_axi/df_in_rd_en
add wave -noupdate -group AXI4_Master_DF_path_instance /tb_dma_top/dut/u_movement/u_axi/df_in_empty
add wave -noupdate -group AXI4_Master_DF_path_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/df_in_dout
add wave -noupdate -group AXI4_Master_DF_path_instance /tb_dma_top/dut/u_movement/u_axi/df_out_wr_en
add wave -noupdate -group AXI4_Master_DF_path_instance /tb_dma_top/dut/u_movement/u_axi/df_out_full
add wave -noupdate -group AXI4_Master_DF_path_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/df_out_din

add wave -noupdate -group AXI4_Master_DM_path_instance /tb_dma_top/dut/u_movement/u_axi/dm_in_rd_en
add wave -noupdate -group AXI4_Master_DM_path_instance /tb_dma_top/dut/u_movement/u_axi/dm_in_empty
add wave -noupdate -group AXI4_Master_DM_path_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/dm_in_dout

add wave -noupdate -group AXI4_Master_MID_path_instance /tb_dma_top/dut/u_movement/u_axi/mid_wr_en
add wave -noupdate -group AXI4_Master_MID_path_instance /tb_dma_top/dut/u_movement/u_axi/mid_full
add wave -noupdate -group AXI4_Master_MID_path_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/mid_din
add wave -noupdate -group AXI4_Master_MID_path_instance /tb_dma_top/dut/u_movement/u_axi/mid_rd_en
add wave -noupdate -group AXI4_Master_MID_path_instance /tb_dma_top/dut/u_movement/u_axi/mid_empty
add wave -noupdate -group AXI4_Master_MID_path_instance -radix hex /tb_dma_top/dut/u_movement/u_axi/mid_dout

# =============================================================================
# SRAM controller — rtl/sram_controller.sv (u_sram)
# =============================================================================
add wave -noupdate -group SRAM_Controller_instance -radix unsigned /tb_dma_top/dut/u_movement/u_sram/state
add wave -noupdate -group SRAM_Controller_instance /tb_dma_top/dut/u_movement/u_sram/sram_done
add wave -noupdate -group SRAM_Controller_instance -radix hex /tb_dma_top/dut/u_movement/u_sram/cur_addr
add wave -noupdate -group SRAM_Controller_instance -radix unsigned /tb_dma_top/dut/u_movement/u_sram/cur_len
add wave -noupdate -group SRAM_Controller_instance /tb_dma_top/dut/u_movement/u_sram/cur_write
add wave -noupdate -group SRAM_Controller_instance -radix unsigned /tb_dma_top/dut/u_movement/u_sram/beat_idx
add wave -noupdate -group SRAM_Controller_instance -radix unsigned /tb_dma_top/dut/u_movement/u_sram/addr
add wave -noupdate -group SRAM_Controller_instance /tb_dma_top/dut/u_movement/u_sram/en
add wave -noupdate -group SRAM_Controller_instance /tb_dma_top/dut/u_movement/u_sram/wr_en
add wave -noupdate -group SRAM_Controller_instance -radix hex /tb_dma_top/dut/u_movement/u_sram/din

# =============================================================================
# BRAM — rtl/bram.sv (u_bram)
# =============================================================================
add wave -noupdate -group SRAM_instance -radix unsigned /tb_dma_top/dut/u_movement/u_bram/addra
add wave -noupdate -group SRAM_instance -radix unsigned /tb_dma_top/dut/u_movement/u_bram/addrb
add wave -noupdate -group SRAM_instance /tb_dma_top/dut/u_movement/u_bram/ena
add wave -noupdate -group SRAM_instance /tb_dma_top/dut/u_movement/u_bram/enb
add wave -noupdate -group SRAM_instance /tb_dma_top/dut/u_movement/u_bram/wea
add wave -noupdate -group SRAM_instance /tb_dma_top/dut/u_movement/u_bram/web
add wave -noupdate -group SRAM_instance -radix hex /tb_dma_top/dut/u_movement/u_bram/dina
add wave -noupdate -group SRAM_instance -radix hex /tb_dma_top/dut/u_movement/u_bram/dinb
add wave -noupdate -group SRAM_instance -radix hex /tb_dma_top/dut/u_movement/u_bram/douta
add wave -noupdate -group SRAM_instance -radix hex /tb_dma_top/dut/u_movement/u_bram/doutb
add wave -noupdate -group SRAM_instance -radix hex {/tb_dma_top/dut/u_movement/u_bram/mem[0]}
add wave -noupdate -group SRAM_instance -radix hex {/tb_dma_top/dut/u_movement/u_bram/mem[1]}

# =============================================================================
# AXI4 (system memory) — tb connects axi_sys to model_sys_mem
# =============================================================================
add wave -noupdate -group AXI4_System_Memory_AW_instance -radix hex /tb_dma_top/axi_sys/awaddr
add wave -noupdate -group AXI4_System_Memory_AW_instance -radix unsigned /tb_dma_top/axi_sys/awlen
add wave -noupdate -group AXI4_System_Memory_AW_instance /tb_dma_top/axi_sys/awvalid
add wave -noupdate -group AXI4_System_Memory_AW_instance /tb_dma_top/axi_sys/awready

add wave -noupdate -group AXI4_System_Memory_W_instance -radix hex /tb_dma_top/axi_sys/wdata
add wave -noupdate -group AXI4_System_Memory_W_instance /tb_dma_top/axi_sys/wlast
add wave -noupdate -group AXI4_System_Memory_W_instance /tb_dma_top/axi_sys/wvalid
add wave -noupdate -group AXI4_System_Memory_W_instance /tb_dma_top/axi_sys/wready

add wave -noupdate -group AXI4_System_Memory_B_instance /tb_dma_top/axi_sys/bresp
add wave -noupdate -group AXI4_System_Memory_B_instance /tb_dma_top/axi_sys/bvalid
add wave -noupdate -group AXI4_System_Memory_B_instance /tb_dma_top/axi_sys/bready

add wave -noupdate -group AXI4_System_Memory_AR_instance -radix hex /tb_dma_top/axi_sys/araddr
add wave -noupdate -group AXI4_System_Memory_AR_instance -radix unsigned /tb_dma_top/axi_sys/arlen
add wave -noupdate -group AXI4_System_Memory_AR_instance /tb_dma_top/axi_sys/arvalid
add wave -noupdate -group AXI4_System_Memory_AR_instance /tb_dma_top/axi_sys/arready

add wave -noupdate -group AXI4_System_Memory_R_instance -radix hex /tb_dma_top/axi_sys/rdata
add wave -noupdate -group AXI4_System_Memory_R_instance /tb_dma_top/axi_sys/rresp
add wave -noupdate -group AXI4_System_Memory_R_instance /tb_dma_top/axi_sys/rlast
add wave -noupdate -group AXI4_System_Memory_R_instance /tb_dma_top/axi_sys/rvalid
add wave -noupdate -group AXI4_System_Memory_R_instance /tb_dma_top/axi_sys/rready

# =============================================================================
# AXI-Lite (CSR slave) — tb drives soc_bus
# =============================================================================
add wave -noupdate -group AXI_Lite_CSR_AW_instance -radix hex /tb_dma_top/soc_bus/awaddr
add wave -noupdate -group AXI_Lite_CSR_AW_instance /tb_dma_top/soc_bus/awvalid
add wave -noupdate -group AXI_Lite_CSR_AW_instance /tb_dma_top/soc_bus/awready

add wave -noupdate -group AXI_Lite_CSR_W_instance -radix hex /tb_dma_top/soc_bus/wdata
add wave -noupdate -group AXI_Lite_CSR_W_instance -radix hex /tb_dma_top/soc_bus/wstrb
add wave -noupdate -group AXI_Lite_CSR_W_instance /tb_dma_top/soc_bus/wvalid
add wave -noupdate -group AXI_Lite_CSR_W_instance /tb_dma_top/soc_bus/wready

add wave -noupdate -group AXI_Lite_CSR_B_instance /tb_dma_top/soc_bus/bresp
add wave -noupdate -group AXI_Lite_CSR_B_instance /tb_dma_top/soc_bus/bvalid
add wave -noupdate -group AXI_Lite_CSR_B_instance /tb_dma_top/soc_bus/bready

add wave -noupdate -group AXI_Lite_CSR_AR_instance -radix hex /tb_dma_top/soc_bus/araddr
add wave -noupdate -group AXI_Lite_CSR_AR_instance /tb_dma_top/soc_bus/arvalid
add wave -noupdate -group AXI_Lite_CSR_AR_instance /tb_dma_top/soc_bus/arready

add wave -noupdate -group AXI_Lite_CSR_R_instance -radix hex /tb_dma_top/soc_bus/rdata
add wave -noupdate -group AXI_Lite_CSR_R_instance /tb_dma_top/soc_bus/rresp
add wave -noupdate -group AXI_Lite_CSR_R_instance /tb_dma_top/soc_bus/rvalid
add wave -noupdate -group AXI_Lite_CSR_R_instance /tb_dma_top/soc_bus/rready

add wave -noupdate -group AXI_Lite_IRQ_instance /tb_dma_top/soc_bus/irq
add wave -noupdate -group AXI_Lite_IRQ_instance /tb_dma_top/soc_bus/irq_empty
add wave -noupdate -group AXI_Lite_IRQ_instance /tb_dma_top/soc_bus/irq_error

# =============================================================================
# System memory model (TB) — sim/model_sys_mem.sv
# =============================================================================
add wave -noupdate -group System_memory_instance /tb_dma_top/u_sysmem/ram_preloaded
add wave -noupdate -group System_memory_instance -radix unsigned /tb_dma_top/u_sysmem/r_state
add wave -noupdate -group System_memory_instance -radix hex /tb_dma_top/u_sysmem/r_addr
add wave -noupdate -group System_memory_instance -radix unsigned /tb_dma_top/u_sysmem/r_beat
add wave -noupdate -group System_memory_instance -radix unsigned /tb_dma_top/u_sysmem/w_state
add wave -noupdate -group System_memory_instance -radix hex /tb_dma_top/u_sysmem/w_addr
add wave -noupdate -group System_memory_instance -radix unsigned /tb_dma_top/u_sysmem/w_beat
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[0]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[1]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[2]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[3]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[64]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[65]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[66]}
add wave -noupdate -group System_memory_instance -radix hex {/tb_dma_top/u_sysmem/ram[67]}

update
wave zoom full
