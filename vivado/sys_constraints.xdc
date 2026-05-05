set CLK_PERIOD_NS 20.000

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports sys_clock]
create_clock -period $CLK_PERIOD_NS -name sys_clock [get_ports sys_clock]

set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports reset]
set_false_path -from [get_ports reset]

set INPUT_PORTS [remove_from_collection [all_inputs] [get_ports {sys_clock reset}]]

set_input_delay  -clock sys_clock -max 2.0 $INPUT_PORTS
set_input_delay  -clock sys_clock -min 0.5 $INPUT_PORTS
set_output_delay -clock sys_clock -max 2.0 [all_outputs]
set_output_delay -clock sys_clock -min 0.5 [all_outputs]