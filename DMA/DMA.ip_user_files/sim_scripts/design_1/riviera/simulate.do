transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+design_1  -L xil_defaultlib -L xilinx_vip -L xpm -L microblaze_v11_0_16 -L lmb_v10_v3_0_16 -L lmb_bram_if_cntlr_v4_0_27 -L blk_mem_gen_v8_4_12 -L axi_lite_ipif_v3_0_4 -L mdm_v3_2_29 -L proc_sys_reset_v5_0_17 -L axi_uartlite_v2_0_39 -L smartconnect_v1_0 -L axi_infrastructure_v1_1_0 -L axi_register_slice_v2_1_36 -L axi_vip_v1_1_22 -L axi_intc_v4_1_22 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.design_1 xil_defaultlib.glbl

do {design_1.udo}

run 1000ns

endsim

quit -force
