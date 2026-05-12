//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.2 (lin64) Build 4029153 Fri Oct 13 20:13:54 MDT 2023
//Date        : Wed Apr 22 22:23:04 2026
//Host        : dubliner running 64-bit Ubuntu 22.04.4 LTS
//Command     : generate_target microblaze_test_wrapper.bd
//Design      : microblaze_test_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module microblaze_test_wrapper
   (btn_tri_io,
    led_4bits_tri_o,
    reset,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  inout [3:0]btn_tri_io;
  output [3:0]led_4bits_tri_o;
  input reset;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [0:0]btn_tri_i_0;
  wire [1:1]btn_tri_i_1;
  wire [2:2]btn_tri_i_2;
  wire [3:3]btn_tri_i_3;
  wire [0:0]btn_tri_io_0;
  wire [1:1]btn_tri_io_1;
  wire [2:2]btn_tri_io_2;
  wire [3:3]btn_tri_io_3;
  wire [0:0]btn_tri_o_0;
  wire [1:1]btn_tri_o_1;
  wire [2:2]btn_tri_o_2;
  wire [3:3]btn_tri_o_3;
  wire [0:0]btn_tri_t_0;
  wire [1:1]btn_tri_t_1;
  wire [2:2]btn_tri_t_2;
  wire [3:3]btn_tri_t_3;
  wire [3:0]led_4bits_tri_o;
  wire reset;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  IOBUF btn_tri_iobuf_0
       (.I(btn_tri_o_0),
        .IO(btn_tri_io[0]),
        .O(btn_tri_i_0),
        .T(btn_tri_t_0));
  IOBUF btn_tri_iobuf_1
       (.I(btn_tri_o_1),
        .IO(btn_tri_io[1]),
        .O(btn_tri_i_1),
        .T(btn_tri_t_1));
  IOBUF btn_tri_iobuf_2
       (.I(btn_tri_o_2),
        .IO(btn_tri_io[2]),
        .O(btn_tri_i_2),
        .T(btn_tri_t_2));
  IOBUF btn_tri_iobuf_3
       (.I(btn_tri_o_3),
        .IO(btn_tri_io[3]),
        .O(btn_tri_i_3),
        .T(btn_tri_t_3));
  microblaze_test microblaze_test_i
       (.btn_tri_i({btn_tri_i_3,btn_tri_i_2,btn_tri_i_1,btn_tri_i_0}),
        .btn_tri_o({btn_tri_o_3,btn_tri_o_2,btn_tri_o_1,btn_tri_o_0}),
        .btn_tri_t({btn_tri_t_3,btn_tri_t_2,btn_tri_t_1,btn_tri_t_0}),
        .led_4bits_tri_o(led_4bits_tri_o),
        .reset(reset),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule
