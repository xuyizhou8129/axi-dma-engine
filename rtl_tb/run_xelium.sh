source /vol/ece303/genus_tutorial/cadence.env
xrun -64bit -sv -access +rw -timescale 1ns/1ps -clean \
    ../rtl/fifo.sv \
    ../rtl/bram.sv \
    ../rtl/sram_controller.sv \
    tb_sram_controller.sv \
    -top tb_sram_controller
