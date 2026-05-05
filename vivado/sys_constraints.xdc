set CLK_PERIOD_NS 20.000

# Clock pin
set_property PACKAGE_PIN E3      [get_ports sys_clock]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clock]
create_clock -period $CLK_PERIOD_NS -name sys_clock [get_ports sys_clock]

# Reset pin
set_property PACKAGE_PIN C2      [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
set_false_path -from [get_ports reset]

# I/O delays for all inputs except clock and reset
set INPUT_PORTS [get_ports * -filter {DIRECTION == IN && NAME !~ sys_clock && NAME !~ reset}]
set_input_delay  -clock sys_clock -max 2.0 $INPUT_PORTS
set_input_delay  -clock sys_clock -min 0.5 $INPUT_PORTS
set_output_delay -clock sys_clock -max 2.0 [all_outputs]
set_output_delay -clock sys_clock -min 0.5 [all_outputs]

# Suppress DRC errors for internal AXI ports with no physical pin
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]