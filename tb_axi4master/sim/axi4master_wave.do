add log -r /*
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

# --- Top-level TB ---
add wave -noupdate -group tb /tb_axi_4_master/clock
add wave -noupdate -group tb /tb_axi_4_master/reset

# --- DUT: axi_4_master ---
add wave -noupdate -group dut /tb_axi_4_master/dut/sram_done
add wave -noupdate -group dut /tb_axi_4_master/dut/state
add wave -noupdate -group dut /tb_axi_4_master/dut/axi_done
add wave -noupdate -group dut -radix hex /tb_axi_4_master/dut/cur_addr
add wave -noupdate -group dut -radix unsigned /tb_axi_4_master/dut/cur_len
add wave -noupdate -group dut /tb_axi_4_master/dut/cur_write
add wave -noupdate -group dut -radix unsigned /tb_axi_4_master/dut/beat_idx
add wave -noupdate -group dut -radix hex /tb_axi_4_master/dut/desc_buf

add wave -noupdate -group dut_df /tb_axi_4_master/dut/df_in_rd_en
add wave -noupdate -group dut_df /tb_axi_4_master/dut/df_in_empty
add wave -noupdate -group dut_df -radix hex /tb_axi_4_master/dut/df_in_dout
add wave -noupdate -group dut_df /tb_axi_4_master/dut/df_out_wr_en
add wave -noupdate -group dut_df /tb_axi_4_master/dut/df_out_full
add wave -noupdate -group dut_df -radix hex /tb_axi_4_master/dut/df_out_din

add wave -noupdate -group dut_dm /tb_axi_4_master/dut/dm_in_rd_en
add wave -noupdate -group dut_dm /tb_axi_4_master/dut/dm_in_empty
add wave -noupdate -group dut_dm -radix hex /tb_axi_4_master/dut/dm_in_dout

add wave -noupdate -group dut_mid /tb_axi_4_master/dut/mid_wr_en
add wave -noupdate -group dut_mid /tb_axi_4_master/dut/mid_full
add wave -noupdate -group dut_mid -radix hex /tb_axi_4_master/dut/mid_din
add wave -noupdate -group dut_mid /tb_axi_4_master/dut/mid_rd_en
add wave -noupdate -group dut_mid /tb_axi_4_master/dut/mid_empty
add wave -noupdate -group dut_mid -radix hex /tb_axi_4_master/dut/mid_dout

# --- AXI4 interface (master side, connected to DUT) ---
add wave -noupdate -group axi_aw -radix hex /tb_axi_4_master/axi/awaddr
add wave -noupdate -group axi_aw -radix unsigned /tb_axi_4_master/axi/awlen
add wave -noupdate -group axi_aw /tb_axi_4_master/axi/awvalid
add wave -noupdate -group axi_aw /tb_axi_4_master/axi/awready

add wave -noupdate -group axi_w -radix hex /tb_axi_4_master/axi/wdata
add wave -noupdate -group axi_w /tb_axi_4_master/axi/wlast
add wave -noupdate -group axi_w /tb_axi_4_master/axi/wvalid
add wave -noupdate -group axi_w /tb_axi_4_master/axi/wready

add wave -noupdate -group axi_b /tb_axi_4_master/axi/bresp
add wave -noupdate -group axi_b /tb_axi_4_master/axi/bvalid
add wave -noupdate -group axi_b /tb_axi_4_master/axi/bready

add wave -noupdate -group axi_ar -radix hex /tb_axi_4_master/axi/araddr
add wave -noupdate -group axi_ar -radix unsigned /tb_axi_4_master/axi/arlen
add wave -noupdate -group axi_ar /tb_axi_4_master/axi/arvalid
add wave -noupdate -group axi_ar /tb_axi_4_master/axi/arready

add wave -noupdate -group axi_r -radix hex /tb_axi_4_master/axi/rdata
add wave -noupdate -group axi_r /tb_axi_4_master/axi/rresp
add wave -noupdate -group axi_r /tb_axi_4_master/axi/rlast
add wave -noupdate -group axi_r /tb_axi_4_master/axi/rvalid
add wave -noupdate -group axi_r /tb_axi_4_master/axi/rready

# --- Memory slave (sample RAM words; Verilog uses []) ---
add wave -noupdate -group u_mem -radix hex {/tb_axi_4_master/u_mem/ram[0]}
add wave -noupdate -group u_mem -radix hex {/tb_axi_4_master/u_mem/ram[1]}
add wave -noupdate -group u_mem -radix hex {/tb_axi_4_master/u_mem/ram[9]}
add wave -noupdate -group u_mem -radix hex {/tb_axi_4_master/u_mem/ram[20]}
add wave -noupdate -group u_mem -radix hex {/tb_axi_4_master/u_mem/ram[40]}

update
wave zoom full
