# sim_top.do — compile and simulate the dma_top system testbench
#
# !! RTL NOTE !!
#   descriptor_fetcher.sv declares its ring-manager port as an interface:
#       rm_df_if.df rm_df
#   movement_top.sv currently connects individual logic signals to this port:
#       .rm_df_addr(rm_df_addr), .rm_df_valid(rm_df_valid), ...
#   This type mismatch will cause a compile error.  To fix it, either:
#   (a) Replace descriptor_fetcher.sv's rm_df_if port with individual
#       input/output ports that match what movement_top connects, OR
#   (b) Instantiate an rm_df_if inside movement_top and bind its members
#       to the individual signals before passing it to descriptor_fetcher.
#
# All other RTL files compile correctly (verified by dependency ordering below).

# -------------------------------------------------------------------------
# Library setup
# -------------------------------------------------------------------------
vlib work
vmap work work

set RTL ../rtl

# -------------------------------------------------------------------------
# Compile RTL in dependency order
# -------------------------------------------------------------------------
vlog -sv ${RTL}/dma_pkg.sv
vlog -sv ${RTL}/axi_4_if.sv
vlog -sv ${RTL}/csr_interfaces.sv
vlog -sv ${RTL}/rm_df_if.sv
vlog -sv ${RTL}/as_rm_if.sv
vlog -sv ${RTL}/fifo.sv
vlog -sv ${RTL}/bram.sv
vlog -sv ${RTL}/axi_4_master.sv
vlog -sv ${RTL}/sram_controller.sv
vlog -sv ${RTL}/descriptor_fetcher.sv
vlog -sv ${RTL}/ring_manager.sv
vlog -sv ${RTL}/IRQ.sv
vlog -sv ${RTL}/csr.sv
vlog -sv ${RTL}/movement_top.sv
vlog -sv ${RTL}/dma_top.sv

# -------------------------------------------------------------------------
# Compile simulation models and testbench
# -------------------------------------------------------------------------
vlog -sv model_sys_mem.sv
vlog -sv tb_top.sv

# -------------------------------------------------------------------------
# Simulate
# -------------------------------------------------------------------------
# Pass the initial system-memory image via +MEMHEX so model_sys_mem picks it up
vsim -t 1ns -voptargs=+acc \
    +MEMHEX=out/initial_smem.hex \
    tb_dma_top

add wave -r /*

if {[info exists env(TB_BATCH)] && $env(TB_BATCH) eq "1"} {
    run -all
    quit -f
} else {
    run -all
}
