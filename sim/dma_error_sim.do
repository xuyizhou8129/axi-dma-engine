# Directed DMA error tests — run from sim/: 
#   TB_BATCH=1 ERR_TEST=overflow_sets_error vsim -c -do dma_error_sim.do

transcript on
setenv LMC_TIMEUNIT -9

proc _dma_sim_find_rtl {} {
    set dir [file normalize [pwd]]
    for {set i 0} {$i < 32} {incr i} {
        set marker [file join $dir rtl dma_pkg.sv]
        if {[file exists $marker]} {
            return [file dirname $marker]
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} { break }
        set dir $parent
    }
    return ""
}
set RTL [_dma_sim_find_rtl]
if {$RTL eq ""} {
    error "dma_error_sim.do: cannot find rtl/dma_pkg.sv above [pwd]"
}
set SIM_DIR [file normalize [file join $RTL ../sim]]
cd $SIM_DIR

vlib work
vmap work work

vlog -sv -work work ${RTL}/dma_pkg.sv
vlog -sv -work work ${RTL}/axi_4_if.sv
vlog -sv -work work ${RTL}/csr_interfaces.sv
vlog -sv -work work ${RTL}/rm_df_if.sv
vlog -sv -work work ${RTL}/as_rm_if.sv
vlog -sv -work work ${RTL}/fifo.sv
vlog -sv -work work ${RTL}/bram.sv
vlog -sv -work work ${RTL}/axi_4_master.sv
vlog -sv -work work ${RTL}/sram_controller.sv
vlog -sv -work work ${RTL}/descriptor_fetcher.sv
vlog -sv -work work ${RTL}/data_mover.sv
vlog -sv -work work ${RTL}/ring_manager.sv
vlog -sv -work work ${RTL}/IRQ.sv
vlog -sv -work work ${RTL}/csr.sv
vlog -sv -work work ${RTL}/movement_top.sv
vlog -sv -work work ${RTL}/dma_top.sv

vlog -sv -work work ${RTL}/sys_mem.sv
vlog -sv -work work tb_error_top.sv

if {[info exists env(ERR_TEST)]} {
    set ERR_ARG "+ERR_TEST=$env(ERR_TEST)"
} else {
    set ERR_ARG "+ERR_TEST=overflow_sets_error"
}

vsim -t 1ns -voptargs=+acc +notimingchecks -L work \
    work.tb_dma_error_top \
    $ERR_ARG \
    -wlf dma_error.wlf

run -all

if {[info exists env(TB_BATCH)] && $env(TB_BATCH) eq "1"} {
    quit -f
}
