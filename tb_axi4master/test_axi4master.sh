#!/bin/csh -f

source /vol/eecs392/env/modelsim.env
cd sim
vsim -do axi4master_sim.do
