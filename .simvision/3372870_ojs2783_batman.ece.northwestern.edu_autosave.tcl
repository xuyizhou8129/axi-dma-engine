
# XM-Sim Command File
# TOOL:	xmsim(64)	18.09-s011
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
alias . run
alias quit exit
database -open -shm -into waves.shm waves -default
probe -create -database waves tb_top.dut.AXI_LITE_ARDone tb_top.dut.AXI_LITE_AWDone tb_top.dut.AXI_LITE_DWDone tb_top.dut.clk tb_top.dut.rd_state tb_top.dut.read_addr tb_top.dut.read_data tb_top.dut.regs tb_top.dut.rst_n tb_top.dut.wr_state tb_top.dut.write_addr tb_top.dut.write_data tb_top.dut.write_enable tb_top.axil_if.slave.araddr tb_top.axil_if.slave.arready tb_top.axil_if.slave.arvalid tb_top.axil_if.slave.awaddr tb_top.axil_if.slave.awready tb_top.axil_if.slave.awvalid tb_top.axil_if.slave.bready tb_top.axil_if.slave.bresp tb_top.axil_if.slave.bvalid tb_top.axil_if.slave.clk tb_top.axil_if.slave.rdata tb_top.axil_if.slave.rready tb_top.axil_if.slave.rresp tb_top.axil_if.slave.rst_n tb_top.axil_if.slave.rvalid tb_top.axil_if.slave.wdata tb_top.axil_if.slave.wready tb_top.axil_if.slave.wvalid

simvision -input /home/ojs2783/ieee2026/axi-dma-engine/.simvision/3372870_ojs2783_batman.ece.northwestern.edu_autosave.tcl.svcf
