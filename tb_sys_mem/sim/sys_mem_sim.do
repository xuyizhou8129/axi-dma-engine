# Run from tb_sys_mem/sim/: vsim -do sys_mem_sim.do

transcript on
setenv LMC_TIMEUNIT -9

vlib work
vmap work work

vlog -sv -work work ../../rtl/dma_pkg.sv
vlog -sv -work work ../../rtl/axi_4_if.sv
vlog -sv -work work ../../rtl/sys_mem.sv
vlog -sv -work work ../tb_sys_mem_top.sv
vlog -sv -work work ../tb_sys_mem.sv

set out_dir [expr {[info exists env(SCENARIO_OUT)] ? $env(SCENARIO_OUT) : [file normalize "../out/test0"]}]
vsim -voptargs=+acc +notimingchecks -L work work.tb_sys_mem -wlf sys_mem.wlf +OUT_DIR=$out_dir

if {[info exists env(TB_BATCH)]} {
    run -all
    quit -f
} else {
    do sys_mem_wave.do
    run -all
}
