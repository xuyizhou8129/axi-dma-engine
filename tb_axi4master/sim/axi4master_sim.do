# Run from tb_axi4master/sim/:  vsim -do axi4master_sim.do   |   TB_BATCH=1 vsim -c -do axi4master_sim.do

transcript on
setenv LMC_TIMEUNIT -9

vlib work
vmap work work

vlog -sv -work work ../../rtl/axi_4_if.sv
vlog -sv -work work ../../rtl/axi_4_master.sv
vlog -sv -work work ../../rtl/fifo.sv
vlog -sv -work work ../sv/axi_mem_behav.sv
vlog -sv -work work ../tb_axi_4_master.sv

vsim -voptargs=+acc +notimingchecks -L work work.tb_axi_4_master -wlf axi4master.wlf

if {[info exists env(TB_BATCH)]} {
    run -all
    quit -f
} else {
    do axi4master_wave.do
    run -all
}
