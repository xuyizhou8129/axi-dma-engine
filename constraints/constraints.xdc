# constraints.xdc - Arty A7-100T constraints for axi-dma-engine
#
# Board: Digilent Arty A7-100T, 100 MHz oscillator on E3.
# Source pinout: Arty-A7-100-Master.xdc in this repo.

# ---- Primary clock: Arty A7 CLK100MHZ, pin E3 ----
set CLK_PERIOD_NS 20.000

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period $CLK_PERIOD_NS -name clk [get_ports clk]

# ---- Reset: Arty A7 reset signal, pin C2 ----
# The RTL reset is active-low (rst_n), matching the board reset net.
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports rst_n]
set_false_path -from [get_ports rst_n]

# ---- I/O timing relative to clk ----
# clk and rst_n are already covered by create_clock / set_false_path above;
# applying set_input_delay to them as well is harmless and avoids the need
# for remove_from_collection / if-guards, which are not valid XDC syntax.
set_input_delay  -clock clk -max 2.0 [all_inputs]
set_input_delay  -clock clk -min 0.5 [all_inputs]
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# Note:
# vivado_config exposes wide AXI-Lite buses as top-level ports. Those buses do
# not correspond to physical Arty A7 header pins and should normally be driven
# by an internal MicroBlaze/block-design wrapper. Only assign package pins for
# debug outputs here if you intentionally route them to LEDs or PMOD headers.
