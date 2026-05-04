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
# Do not apply board I/O delays to the clock/reset ports themselves.
set INPUT_PORTS  [remove_from_collection [all_inputs]  [get_ports {clk rst_n}]]
set OUTPUT_PORTS [all_outputs]

if {[sizeof_collection $INPUT_PORTS] > 0} {
    set_input_delay  -clock clk -max 2.0 $INPUT_PORTS
    set_input_delay  -clock clk -min 0.5 $INPUT_PORTS
}

if {[sizeof_collection $OUTPUT_PORTS] > 0} {
    set_output_delay -clock clk -max 2.0 $OUTPUT_PORTS
    set_output_delay -clock clk -min 0.5 $OUTPUT_PORTS
}

# Note:
# vivado_config exposes wide AXI-Lite buses as top-level ports. Those buses do
# not correspond to physical Arty A7 header pins and should normally be driven
# by an internal MicroBlaze/block-design wrapper. Only assign package pins for
# debug outputs here if you intentionally route them to LEDs or PMOD headers.
