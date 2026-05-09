transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xilinx_vip
vlib activehdl/xpm
vlib activehdl/microblaze_v11_0_16
vlib activehdl/xil_defaultlib
vlib activehdl/lmb_v10_v3_0_16
vlib activehdl/lmb_bram_if_cntlr_v4_0_27
vlib activehdl/blk_mem_gen_v8_4_12
vlib activehdl/axi_lite_ipif_v3_0_4
vlib activehdl/mdm_v3_2_29
vlib activehdl/proc_sys_reset_v5_0_17
vlib activehdl/axi_uartlite_v2_0_39
vlib activehdl/smartconnect_v1_0
vlib activehdl/axi_infrastructure_v1_1_0
vlib activehdl/axi_register_slice_v2_1_36
vlib activehdl/axi_vip_v1_1_22
vlib activehdl/axi_intc_v4_1_22

vmap xilinx_vip activehdl/xilinx_vip
vmap xpm activehdl/xpm
vmap microblaze_v11_0_16 activehdl/microblaze_v11_0_16
vmap xil_defaultlib activehdl/xil_defaultlib
vmap lmb_v10_v3_0_16 activehdl/lmb_v10_v3_0_16
vmap lmb_bram_if_cntlr_v4_0_27 activehdl/lmb_bram_if_cntlr_v4_0_27
vmap blk_mem_gen_v8_4_12 activehdl/blk_mem_gen_v8_4_12
vmap axi_lite_ipif_v3_0_4 activehdl/axi_lite_ipif_v3_0_4
vmap mdm_v3_2_29 activehdl/mdm_v3_2_29
vmap proc_sys_reset_v5_0_17 activehdl/proc_sys_reset_v5_0_17
vmap axi_uartlite_v2_0_39 activehdl/axi_uartlite_v2_0_39
vmap smartconnect_v1_0 activehdl/smartconnect_v1_0
vmap axi_infrastructure_v1_1_0 activehdl/axi_infrastructure_v1_1_0
vmap axi_register_slice_v2_1_36 activehdl/axi_register_slice_v2_1_36
vmap axi_vip_v1_1_22 activehdl/axi_vip_v1_1_22
vmap axi_intc_v4_1_22 activehdl/axi_intc_v4_1_22

vlog -work xilinx_vip  -sv2k12 "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/axi_vip_if.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/clk_vip_if.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work microblaze_v11_0_16 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/c957/hdl/microblaze_v11_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_microblaze_0_0/sim/design_1_microblaze_0_0.vhd" \

vcom -work lmb_v10_v3_0_16 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/dac4/hdl/lmb_v10_v3_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_dlmb_v10_0/sim/design_1_dlmb_v10_0.vhd" \
"../../../bd/design_1/ip/design_1_ilmb_v10_0/sim/design_1_ilmb_v10_0.vhd" \

vcom -work lmb_bram_if_cntlr_v4_0_27 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/7cd0/hdl/lmb_bram_if_cntlr_v4_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_dlmb_bram_if_cntlr_0/sim/design_1_dlmb_bram_if_cntlr_0.vhd" \
"../../../bd/design_1/ip/design_1_ilmb_bram_if_cntlr_0/sim/design_1_ilmb_bram_if_cntlr_0.vhd" \

vlog -work blk_mem_gen_v8_4_12  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/42f3/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_lmb_bram_0/sim/design_1_lmb_bram_0.v" \

vcom -work axi_lite_ipif_v3_0_4 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/66ea/hdl/axi_lite_ipif_v3_0_vh_rfs.vhd" \

vcom -work mdm_v3_2_29 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/1dd0/hdl/mdm_v3_2_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_mdm_1_0/sim/design_1_mdm_1_0.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_clk_wiz_1_0/design_1_clk_wiz_1_0_clk_wiz.v" \
"../../../bd/design_1/ip/design_1_clk_wiz_1_0/design_1_clk_wiz_1_0.v" \

vcom -work proc_sys_reset_v5_0_17 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/9438/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_rst_clk_wiz_1_100M_0/sim/design_1_rst_clk_wiz_1_100M_0.vhd" \

vcom -work axi_uartlite_v2_0_39 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/eab1/hdl/axi_uartlite_v2_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_axi_uartlite_0_0/sim/design_1_axi_uartlite_0_0.vhd" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ipshared/b86a/src/IRQ.sv" \
"../../../bd/design_1/ipshared/b86a/src/dma_pkg.sv" \
"../../../bd/design_1/ipshared/b86a/src/axi_4_if.sv" \
"../../../bd/design_1/ipshared/b86a/src/axi_4_master.sv" \
"../../../bd/design_1/ipshared/b86a/src/bram.sv" \
"../../../bd/design_1/ipshared/b86a/src/csr.sv" \
"../../../bd/design_1/ipshared/b86a/src/csr_interfaces.sv" \
"../../../bd/design_1/ipshared/b86a/src/data_mover.sv" \
"../../../bd/design_1/ipshared/b86a/src/descriptor_fetcher.sv" \
"../../../bd/design_1/ipshared/b86a/src/dma_top.sv" \
"../../../bd/design_1/ipshared/b86a/src/fifo.sv" \
"../../../bd/design_1/ipshared/b86a/src/mem_access_ctrl.sv" \
"../../../bd/design_1/ipshared/b86a/src/movement_top.sv" \
"../../../bd/design_1/ipshared/b86a/src/ring_manager.sv" \
"../../../bd/design_1/ipshared/b86a/src/rm_df_if.sv" \
"../../../bd/design_1/ipshared/b86a/src/sram_controller.sv" \
"../../../bd/design_1/ipshared/b86a/src/sys_mem.sv" \
"../../../bd/design_1/ipshared/b86a/src/vivado_config.sv" \
"../../../bd/design_1/ip/design_1_DMA_0_0/sim/design_1_DMA_0_0.sv" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/sim/bd_afc3.v" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_1/sim/bd_afc3_psr_aclk_0.vhd" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/sc_util_v1_0_vl_rfs.sv" \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/0848/hdl/sc_switchboard_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_2/sim/bd_afc3_arinsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_3/sim/bd_afc3_rinsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_4/sim/bd_afc3_awinsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_5/sim/bd_afc3_winsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_6/sim/bd_afc3_binsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_7/sim/bd_afc3_aroutsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_8/sim/bd_afc3_routsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_9/sim/bd_afc3_awoutsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_10/sim/bd_afc3_woutsw_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_11/sim/bd_afc3_boutsw_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/sc_node_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_12/sim/bd_afc3_arni_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_13/sim/bd_afc3_rni_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_14/sim/bd_afc3_awni_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_15/sim/bd_afc3_wni_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_16/sim/bd_afc3_bni_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/3d9a/hdl/sc_mmu_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_17/sim/bd_afc3_s00mmu_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/7785/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_18/sim/bd_afc3_s00tr_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/3051/hdl/sc_si_converter_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_19/sim/bd_afc3_s00sic_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/852f/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_20/sim/bd_afc3_s00a2s_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_21/sim/bd_afc3_sarn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_22/sim/bd_afc3_srn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_23/sim/bd_afc3_sawn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_24/sim/bd_afc3_swn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_25/sim/bd_afc3_sbn_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/fca9/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_26/sim/bd_afc3_m00s2a_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_27/sim/bd_afc3_m00arn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_28/sim/bd_afc3_m00rn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_29/sim/bd_afc3_m00awn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_30/sim/bd_afc3_m00wn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_31/sim/bd_afc3_m00bn_0.sv" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/e44a/hdl/sc_exit_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_32/sim/bd_afc3_m00e_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_33/sim/bd_afc3_m01s2a_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_34/sim/bd_afc3_m01arn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_35/sim/bd_afc3_m01rn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_36/sim/bd_afc3_m01awn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_37/sim/bd_afc3_m01wn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_38/sim/bd_afc3_m01bn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_39/sim/bd_afc3_m01e_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_40/sim/bd_afc3_m02s2a_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_41/sim/bd_afc3_m02arn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_42/sim/bd_afc3_m02rn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_43/sim/bd_afc3_m02awn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_44/sim/bd_afc3_m02wn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_45/sim/bd_afc3_m02bn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_46/sim/bd_afc3_m02e_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_47/sim/bd_afc3_m03s2a_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_48/sim/bd_afc3_m03arn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_49/sim/bd_afc3_m03rn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_50/sim/bd_afc3_m03awn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_51/sim/bd_afc3_m03wn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_52/sim/bd_afc3_m03bn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_0/bd_0/ip/ip_53/sim/bd_afc3_m03e_0.sv" \

vcom -work smartconnect_v1_0 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.vhd" \

vlog -work smartconnect_v1_0  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.sv" \

vlog -work axi_infrastructure_v1_1_0  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_register_slice_v2_1_36  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/bc4b/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_22  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/b16a/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/ip/design_1_axi_smc_0/sim/design_1_axi_smc_0.sv" \

vcom -work axi_intc_v4_1_22 -93  \
"../../../../DMA.gen/sources_1/bd/design_1/ipshared/f258/hdl/axi_intc_v4_1_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/design_1/ip/design_1_axi_intc_0_0/sim/design_1_axi_intc_0_0.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/a415" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../DMA.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2025.2/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l microblaze_v11_0_16 -l xil_defaultlib -l lmb_v10_v3_0_16 -l lmb_bram_if_cntlr_v4_0_27 -l blk_mem_gen_v8_4_12 -l axi_lite_ipif_v3_0_4 -l mdm_v3_2_29 -l proc_sys_reset_v5_0_17 -l axi_uartlite_v2_0_39 -l smartconnect_v1_0 -l axi_infrastructure_v1_1_0 -l axi_register_slice_v2_1_36 -l axi_vip_v1_1_22 -l axi_intc_v4_1_22 \
"../../../bd/design_1/sim/design_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

