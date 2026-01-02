#!/bin/tcsh
# Xcelium simulation script for smoke test

# Clean previous runs
rm -rf xcelium.d
rm -rf xrun.log
rm -rf xrun.history
rm -rf waves.shm

# Source the Cadence environment (uses setenv, needs tcsh/csh)
source /vol/ece303/genus_tutorial/cadence.env

# Compile and run the simulation
xrun \
    -64bit \
    -sv \
    -access +rw \
    -timescale 1ns/1ps \
    -incdir rtl \
    -incdir tb/sv \
    rtl/axi_lite_if.sv \
    rtl/dma_top.sv \
    tb/sv/axi_lite_bfm.sv \
    tb/sv/tb_top.sv \
    tb/tests/t_reg_smoke.sv \
    -top tb_top \
    -gui \
    >& output.txt

echo "Simulation complete. Check output.txt for console output and xrun.log for details."

