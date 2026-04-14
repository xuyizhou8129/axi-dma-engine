setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "./csr_interfaces.sv"
vlog -work work "./csr.sv"
vlog -work work "./csr_tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.csr_tb -wlf csr_tb.wlf

add wave -noupdate -group csr_tb
add wave -noupdate -group csr_tb -radix hexadecimal /csr_tb/*

add wave -noupdate -group csr_tb/dut
add wave -noupdate -group csr_tb/dut -radix hexadecimal /csr_tb/dut/*

run -all
