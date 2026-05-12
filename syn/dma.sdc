# dma_top — 100 MHz (matches sim/tb_top.sv). Change -period if your SoC clock differs.

create_clock -name {clk} -period 10.0 -waveform {0.0 5.0} [get_ports {clk}]

# Asynchronous active-low reset: do not time paths as synchronous launches from rst_n.
set_false_path -from [get_ports {rst_n}]
