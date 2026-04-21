# constraints.xdc — Timing and I/O constraints for axi-dma-engine
# Adjust clock period and pin assignments to match your board.

# ---- Primary clock (100 MHz placeholder) ----
# Replace CLK_PIN with your board's clock pin (e.g. E3 on Arty A7).
set CLK_PERIOD_NS 10.0

create_clock -period $CLK_PERIOD_NS -name clk [get_ports clk]

# ---- Async reset: no timing path needed ----
set_false_path -from [get_ports rst_n]

# ---- I/O timing (adjust or remove for internal use / Zynq PS) ----
# Input setup/hold relative to clk — loosen for board-level integration.
set_input_delay  -clock clk -max 2.0 [all_inputs]
set_input_delay  -clock clk -min 0.5 [all_inputs]
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# ---- Pin assignments (uncomment and fill in for your board) ----
# set_property PACKAGE_PIN E3  [get_ports clk]
# set_property IOSTANDARD  LVCMOS33 [get_ports clk]
# set_property PACKAGE_PIN C2  [get_ports rst_n]
# set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]
