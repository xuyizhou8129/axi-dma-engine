# create_project.tcl — Vivado project setup for axi-dma-engine
# Usage: vivado -mode batch -source vivado/create_project.tcl
# Run from the repo root, or adjust REPO_ROOT below.

set REPO_ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJ_NAME axi_dma_engine
set PROJ_DIR  [file join $REPO_ROOT vivado/proj]

# ---- Target device (placeholder: Artix-7 on Arty A7-100T) ----
# Replace with your actual part number before running.
set PART xc7a100tcsg324-1

# ---- Create project ----
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

set_property target_language SystemVerilog [current_project]

# ---- Add RTL sources ----
# Order matters: package first, then interfaces, then modules.
set RTL_SOURCES [list \
    $REPO_ROOT/rtl/dma_pkg.sv           \
    $REPO_ROOT/rtl/axi_4_if.sv          \
    $REPO_ROOT/rtl/csr_interfaces.sv    \
    $REPO_ROOT/rtl/rm_df_if.sv          \
    $REPO_ROOT/rtl/as_rm_if.sv          \
    $REPO_ROOT/rtl/rm_to_irq_if.sv      \
    $REPO_ROOT/rtl/fifo.sv              \
    $REPO_ROOT/rtl/bram.sv              \
    $REPO_ROOT/rtl/axi_4_master.sv      \
    $REPO_ROOT/rtl/sram_controller.sv   \
    $REPO_ROOT/rtl/descriptor_fetcher.sv \
    $REPO_ROOT/rtl/data_mover.sv        \
    $REPO_ROOT/rtl/ring_manager.sv      \
    $REPO_ROOT/rtl/IRQ.sv               \
    $REPO_ROOT/rtl/csr.sv               \
    $REPO_ROOT/rtl/movement_top.sv      \
    $REPO_ROOT/rtl/dma_top.sv           \
    $REPO_ROOT/rtl/vivado_config.sv     \
]

add_files -norecurse $RTL_SOURCES
set_property file_type SystemVerilog [get_files *.sv]

# Keep the explicit file order above: packages → interfaces → modules.
# 'DisplayOnly' prevents Vivado from re-sorting files and ensures dma_pkg
# is compiled before any module that references dma_pkg::<symbol>.
set_property source_mgmt_mode DisplayOnly [current_project]

# ---- Add constraints ----
add_files -fileset constrs_1 -norecurse $REPO_ROOT/vivado/constraints.xdc

# ---- Set top ----
set_property top vivado_config [current_fileset]

puts "Project created: $PROJ_DIR/$PROJ_NAME.xpr"
puts "Top module: vivado_config  |  Part: $PART"
puts "Run 'launch_runs synth_1' to synthesize."
