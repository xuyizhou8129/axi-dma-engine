# Run from tb_descriptor_fetcher/sim/: vsim -do descriptor_fetcher_sim.do

transcript on
setenv LMC_TIMEUNIT -9

vlib work
vmap work work

vlog -sv -work work ../../rtl/dma_pkg.sv
vlog -sv -work work ../../rtl/rm_df_if.sv
vlog -sv -work work ../../rtl/fifo.sv
vlog -sv -work work ../../rtl/descriptor_fetcher.sv
vlog -sv -work work ../tb_desc_fetcher_top.sv
vlog -sv -work work ../tb_desc_fetcher.sv

set out_dir [expr {[info exists env(SCENARIO_OUT)] ? $env(SCENARIO_OUT) : [file normalize "../out/test0"]}]
vsim -voptargs=+acc +notimingchecks -L work work.tb_desc_fetcher -wlf descriptor_fetcher.wlf +OUT_DIR=$out_dir

if {[info exists env(TB_BATCH)]} {
    run -all
    quit -f
} else {
    do descriptor_fetcher_wave.do
    run -all
}
