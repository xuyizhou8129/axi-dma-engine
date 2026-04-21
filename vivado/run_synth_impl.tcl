# run_synth_impl.tcl — Run full Vivado flow on an existing project
# Usage (from repo root):
#   vivado -mode batch -source vivado/run_synth_impl.tcl
#
# Create the project first if it doesn't exist:
#   vivado -mode batch -source vivado/create_project.tcl

set REPO_ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJ_FILE [glob -nocomplain $REPO_ROOT/vivado/proj/*.xpr]

if {$PROJ_FILE eq ""} {
    error "No .xpr found — run create_project.tcl first."
}

open_project $PROJ_FILE

# ---- Synthesis ----
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis failed — check vivado/proj/*.runs/synth_1/*.log"
}
open_run synth_1

# ---- Timing check post-synthesis (non-fatal) ----
report_timing_summary -file $REPO_ROOT/vivado/reports/timing_synth.rpt

# ---- Implementation ----
launch_runs impl_1 -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation failed — check vivado/proj/*.runs/impl_1/*.log"
}
open_run impl_1

# ---- Reports ----
file mkdir $REPO_ROOT/vivado/reports
report_timing_summary   -file $REPO_ROOT/vivado/reports/timing_impl.rpt
report_utilization      -file $REPO_ROOT/vivado/reports/utilization.rpt
report_clock_interaction -file $REPO_ROOT/vivado/reports/clock_interaction.rpt
report_cdc              -file $REPO_ROOT/vivado/reports/cdc.rpt

# ---- Bitstream ----
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set BIT_FILE [glob -nocomplain $REPO_ROOT/vivado/proj/*.runs/impl_1/*.bit]
if {$BIT_FILE ne ""} {
    puts "Bitstream: $BIT_FILE"
} else {
    puts "WARNING: bitstream not found after impl_1 — check logs."
}
