add log -r /*
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

add wave -noupdate -group tb /tb_desc_fetcher/clock
add wave -noupdate -group tb /tb_desc_fetcher/reset

add wave -noupdate -group ring -radix hex /tb_desc_fetcher/rm_df_addr
add wave -noupdate -group ring /tb_desc_fetcher/rm_df_valid
add wave -noupdate -group ring /tb_desc_fetcher/df_ready

add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/df_in_wr_en
add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/df_in_full
add wave -noupdate -group dut -radix hex /tb_desc_fetcher/u_top/dut/df_in_din
add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/df_out_rd_en
add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/df_out_empty
add wave -noupdate -group dut -radix hex /tb_desc_fetcher/u_top/dut/df_out_dout
add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/dm_in_wr_en
add wave -noupdate -group dut /tb_desc_fetcher/u_top/dut/dm_in_full
add wave -noupdate -group dut -radix hex /tb_desc_fetcher/u_top/dut/dm_in_din

add wave -noupdate -group fifo_df_in /tb_desc_fetcher/u_top/u_df_in_fifo/wr_en
add wave -noupdate -group fifo_df_in /tb_desc_fetcher/u_top/u_df_in_fifo/full
add wave -noupdate -group fifo_df_in /tb_desc_fetcher/u_top/u_df_in_fifo/empty
add wave -noupdate -group fifo_df_in -radix hex /tb_desc_fetcher/u_top/u_df_in_fifo/din
add wave -noupdate -group fifo_df_in -radix hex /tb_desc_fetcher/u_top/u_df_in_fifo/dout

add wave -noupdate -group fifo_df_out /tb_desc_fetcher/tb_df_out_wr_en
add wave -noupdate -group fifo_df_out /tb_desc_fetcher/tb_df_out_full
add wave -noupdate -group fifo_df_out /tb_desc_fetcher/u_top/u_df_out_fifo/empty
add wave -noupdate -group fifo_df_out /tb_desc_fetcher/u_top/u_df_out_fifo/rd_en
add wave -noupdate -group fifo_df_out -radix hex /tb_desc_fetcher/tb_df_out_din
add wave -noupdate -group fifo_df_out -radix hex /tb_desc_fetcher/u_top/u_df_out_fifo/dout

add wave -noupdate -group fifo_dm /tb_desc_fetcher/u_top/u_dm_in_fifo/wr_en
add wave -noupdate -group fifo_dm /tb_desc_fetcher/u_top/u_dm_in_fifo/full
add wave -noupdate -group fifo_dm /tb_desc_fetcher/u_top/u_dm_in_fifo/empty
add wave -noupdate -group fifo_dm -radix hex /tb_desc_fetcher/u_top/u_dm_in_fifo/din

update
wave zoom full
