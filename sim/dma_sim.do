# System-level DMA testbench — invoke from any cwd, e.g.:
#   cd sim && vsim -do dma_sim.do
#   vsim -do /path/to/axi-dma-engine/sim/dma_sim.do
#   TB_BATCH=1 vsim -c -do dma_sim.do
#
# Prerequisites:  run `make golden` or  python3 run_golden.py scenarios/example.csv out
# so that out/initial_smem.hex and out/stim.txt exist under sim/out/.

transcript on
setenv LMC_TIMEUNIT -9

# ModelSim quirk: [info script] inside a macro often resolves to the vsim binary
# (e.g. /mtitcl/vsim), not the path to this .do file — so we cannot anchor on it.
# Instead: walk upward from [pwd] until rtl/dma_pkg.sv is found (repo or sim/ cwd).
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
    error "dma_sim.do: cannot find rtl/dma_pkg.sv above [pwd] — cd to sim/ or the repo root, then run vsim."
}
set SIM_DIR [file normalize [file join $RTL ../sim]]
cd $SIM_DIR

vlib work
vmap work work

# --- RTL (dependency order) ---
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

# --- TB + synthesizable system memory ---
vlog -sv -work work ${RTL}/sys_mem.sv
vlog -sv -work work tb_top.sv

set vsim_plusargs [list]
if {[info exists env(EXPECT_ERROR)] && $env(EXPECT_ERROR) eq "1"} {
    lappend vsim_plusargs +EXPECT_ERROR=1
}

vsim -t 1ns -voptargs=+acc +notimingchecks -L work \
    work.tb_dma_top \
    {*}$vsim_plusargs \
    -wlf dma.wlf

if {[info exists env(TB_BATCH)] && $env(TB_BATCH) eq "1"} {
    run -all
    quit -code [expr {[examine -radix decimal /tb_dma_top/tb_pass] == 1 ? 0 : 1}]
} else {
    do dma_wave.do
    run -all
}
