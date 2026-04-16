# Waveform for system-level tb_dma_top (dma_top DUT + model_sys_mem + AXI-Lite)

add log -r /*
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

# --- Testbench top ---
add wave -noupdate -group tb /tb_dma_top/clk
add wave -noupdate -group tb /tb_dma_top/rst_n
add wave -noupdate -group tb /tb_dma_top/irq_rm_empty
add wave -noupdate -group tb /tb_dma_top/irq_rm_error
add wave -noupdate -group tb /tb_dma_top/irq_block
add wave -noupdate -group tb -radix unsigned /tb_dma_top/irq_block_status

# --- dma_top: ring manager / RM signals ---
add wave -noupdate -group rm -radix hex /tb_dma_top/dut/rm_df_addr
add wave -noupdate -group rm /tb_dma_top/dut/fetch_req_valid
add wave -noupdate -group rm /tb_dma_top/dut/fetch_req_ready
add wave -noupdate -group rm /tb_dma_top/dut/df_error
add wave -noupdate -group rm /tb_dma_top/dut/dm_done

# --- movement_top / axi_4_master (u_axi) ---
add wave -noupdate -group axi_m -radix unsigned /tb_dma_top/dut/u_movement/u_axi/state
add wave -noupdate -group axi_m /tb_dma_top/dut/u_movement/u_axi/sram_done
add wave -noupdate -group axi_m /tb_dma_top/dut/u_movement/u_axi/axi_done
add wave -noupdate -group axi_m -radix hex /tb_dma_top/dut/u_movement/u_axi/cur_addr
add wave -noupdate -group axi_m -radix unsigned /tb_dma_top/dut/u_movement/u_axi/cur_len
add wave -noupdate -group axi_m /tb_dma_top/dut/u_movement/u_axi/cur_write

add wave -noupdate -group axi_m_df /tb_dma_top/dut/u_movement/u_axi/df_in_rd_en
add wave -noupdate -group axi_m_df /tb_dma_top/dut/u_movement/u_axi/df_in_empty
add wave -noupdate -group axi_m_df -radix hex /tb_dma_top/dut/u_movement/u_axi/df_in_dout
add wave -noupdate -group axi_m_df /tb_dma_top/dut/u_movement/u_axi/df_out_wr_en
add wave -noupdate -group axi_m_df /tb_dma_top/dut/u_movement/u_axi/df_out_full
add wave -noupdate -group axi_m_df -radix hex /tb_dma_top/dut/u_movement/u_axi/df_out_din

add wave -noupdate -group axi_m_dm /tb_dma_top/dut/u_movement/u_axi/dm_in_rd_en
add wave -noupdate -group axi_m_dm /tb_dma_top/dut/u_movement/u_axi/dm_in_empty
add wave -noupdate -group axi_m_dm -radix hex /tb_dma_top/dut/u_movement/u_axi/dm_in_dout

add wave -noupdate -group axi_m_mid /tb_dma_top/dut/u_movement/u_axi/mid_wr_en
add wave -noupdate -group axi_m_mid /tb_dma_top/dut/u_movement/u_axi/mid_full
add wave -noupdate -group axi_m_mid -radix hex /tb_dma_top/dut/u_movement/u_axi/mid_din
add wave -noupdate -group axi_m_mid /tb_dma_top/dut/u_movement/u_axi/mid_rd_en
add wave -noupdate -group axi_m_mid /tb_dma_top/dut/u_movement/u_axi/mid_empty
add wave -noupdate -group axi_m_mid -radix hex /tb_dma_top/dut/u_movement/u_axi/mid_dout

# --- SRAM controller (inside movement_top) ---
add wave -noupdate -group sram_c -radix unsigned /tb_dma_top/dut/u_movement/u_sram/state
add wave -noupdate -group sram_c /tb_dma_top/dut/u_movement/u_sram/sram_done

# --- AXI4 master port to system memory (tb connects axi_sys) ---
add wave -noupdate -group axi_sys_aw -radix hex /tb_dma_top/axi_sys/awaddr
add wave -noupdate -group axi_sys_aw -radix unsigned /tb_dma_top/axi_sys/awlen
add wave -noupdate -group axi_sys_aw /tb_dma_top/axi_sys/awvalid
add wave -noupdate -group axi_sys_aw /tb_dma_top/axi_sys/awready

add wave -noupdate -group axi_sys_w -radix hex /tb_dma_top/axi_sys/wdata
add wave -noupdate -group axi_sys_w /tb_dma_top/axi_sys/wlast
add wave -noupdate -group axi_sys_w /tb_dma_top/axi_sys/wvalid
add wave -noupdate -group axi_sys_w /tb_dma_top/axi_sys/wready

add wave -noupdate -group axi_sys_b /tb_dma_top/axi_sys/bresp
add wave -noupdate -group axi_sys_b /tb_dma_top/axi_sys/bvalid
add wave -noupdate -group axi_sys_b /tb_dma_top/axi_sys/bready

add wave -noupdate -group axi_sys_ar -radix hex /tb_dma_top/axi_sys/araddr
add wave -noupdate -group axi_sys_ar -radix unsigned /tb_dma_top/axi_sys/arlen
add wave -noupdate -group axi_sys_ar /tb_dma_top/axi_sys/arvalid
add wave -noupdate -group axi_sys_ar /tb_dma_top/axi_sys/arready

add wave -noupdate -group axi_sys_r -radix hex /tb_dma_top/axi_sys/rdata
add wave -noupdate -group axi_sys_r /tb_dma_top/axi_sys/rresp
add wave -noupdate -group axi_sys_r /tb_dma_top/axi_sys/rlast
add wave -noupdate -group axi_sys_r /tb_dma_top/axi_sys/rvalid
add wave -noupdate -group axi_sys_r /tb_dma_top/axi_sys/rready

# --- AXI-Lite CSR (soc_bus) ---
add wave -noupdate -group axil_aw -radix hex /tb_dma_top/soc_bus/awaddr
add wave -noupdate -group axil_aw /tb_dma_top/soc_bus/awvalid
add wave -noupdate -group axil_aw /tb_dma_top/soc_bus/awready

add wave -noupdate -group axil_w -radix hex /tb_dma_top/soc_bus/wdata
add wave -noupdate -group axil_w -radix hex /tb_dma_top/soc_bus/wstrb
add wave -noupdate -group axil_w /tb_dma_top/soc_bus/wvalid
add wave -noupdate -group axil_w /tb_dma_top/soc_bus/wready

add wave -noupdate -group axil_b /tb_dma_top/soc_bus/bresp
add wave -noupdate -group axil_b /tb_dma_top/soc_bus/bvalid
add wave -noupdate -group axil_b /tb_dma_top/soc_bus/bready

add wave -noupdate -group axil_ar -radix hex /tb_dma_top/soc_bus/araddr
add wave -noupdate -group axil_ar /tb_dma_top/soc_bus/arvalid
add wave -noupdate -group axil_ar /tb_dma_top/soc_bus/arready

add wave -noupdate -group axil_r -radix hex /tb_dma_top/soc_bus/rdata
add wave -noupdate -group axil_r /tb_dma_top/soc_bus/rresp
add wave -noupdate -group axil_r /tb_dma_top/soc_bus/rvalid
add wave -noupdate -group axil_r /tb_dma_top/soc_bus/rready

# --- system memory model (sample words) ---
add wave -noupdate -group u_sysmem -radix hex {/tb_dma_top/u_sysmem/ram[0]}
add wave -noupdate -group u_sysmem -radix hex {/tb_dma_top/u_sysmem/ram[1]}
add wave -noupdate -group u_sysmem -radix hex {/tb_dma_top/u_sysmem/ram[64]}
add wave -noupdate -group u_sysmem -radix hex {/tb_dma_top/u_sysmem/ram[65]}

update
wave zoom full
