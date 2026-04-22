add log -r /*
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

add wave -noupdate -group tb /tb_sys_mem/clk
add wave -noupdate -group tb /tb_sys_mem/rst_n

add wave -noupdate -group aw -radix hex /tb_sys_mem/awaddr
add wave -noupdate -group aw           /tb_sys_mem/awlen
add wave -noupdate -group aw           /tb_sys_mem/awvalid
add wave -noupdate -group aw           /tb_sys_mem/awready

add wave -noupdate -group w  -radix hex /tb_sys_mem/wdata
add wave -noupdate -group w            /tb_sys_mem/wlast
add wave -noupdate -group w            /tb_sys_mem/wvalid
add wave -noupdate -group w            /tb_sys_mem/wready

add wave -noupdate -group b            /tb_sys_mem/bvalid
add wave -noupdate -group b            /tb_sys_mem/bready
add wave -noupdate -group b  -radix hex /tb_sys_mem/bresp

add wave -noupdate -group ar -radix hex /tb_sys_mem/araddr
add wave -noupdate -group ar           /tb_sys_mem/arlen
add wave -noupdate -group ar           /tb_sys_mem/arvalid
add wave -noupdate -group ar           /tb_sys_mem/arready

add wave -noupdate -group r  -radix hex /tb_sys_mem/rdata
add wave -noupdate -group r  -radix hex /tb_sys_mem/rresp
add wave -noupdate -group r            /tb_sys_mem/rlast
add wave -noupdate -group r            /tb_sys_mem/rvalid
add wave -noupdate -group r            /tb_sys_mem/rready

add wave -noupdate -group dut          /tb_sys_mem/u_top/dut/r_state
add wave -noupdate -group dut          /tb_sys_mem/u_top/dut/w_state
add wave -noupdate -group dut -radix hex /tb_sys_mem/u_top/dut/r_addr
add wave -noupdate -group dut          /tb_sys_mem/u_top/dut/r_beat
add wave -noupdate -group dut          /tb_sys_mem/u_top/dut/r_last_beat
add wave -noupdate -group dut -radix hex /tb_sys_mem/u_top/dut/w_addr
add wave -noupdate -group dut          /tb_sys_mem/u_top/dut/w_beat

update
wave zoom full
