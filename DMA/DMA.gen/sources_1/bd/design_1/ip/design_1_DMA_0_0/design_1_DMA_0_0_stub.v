// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Mon May  4 18:29:47 2026
// Host        : NUL-LENDLAP97 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/laptop/Desktop/DMA/DMA.gen/sources_1/bd/design_1/ip/design_1_DMA_0_0/design_1_DMA_0_0_stub.v
// Design      : design_1_DMA_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "design_1_DMA_0_0,vivado_config,{}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) (* IP_DEFINITION_SOURCE = "package_project" *) 
(* X_CORE_INFO = "vivado_config,Vivado 2025.2" *) 
module design_1_DMA_0_0(clk, rst_n, s_axil_awaddr, s_axil_awprot, 
  s_axil_awvalid, s_axil_awready, s_axil_wdata, s_axil_wstrb, s_axil_wvalid, s_axil_wready, 
  s_axil_bresp, s_axil_bvalid, s_axil_bready, s_axil_araddr, s_axil_arprot, s_axil_arvalid, 
  s_axil_arready, s_axil_rdata, s_axil_rresp, s_axil_rvalid, s_axil_rready, 
  s_axil_init_awaddr, s_axil_init_awprot, s_axil_init_awvalid, s_axil_init_awready, 
  s_axil_init_wdata, s_axil_init_wstrb, s_axil_init_wvalid, s_axil_init_wready, 
  s_axil_init_bresp, s_axil_init_bvalid, s_axil_init_bready, s_axil_init_araddr, 
  s_axil_init_arprot, s_axil_init_arvalid, s_axil_init_arready, s_axil_init_rdata, 
  s_axil_init_rresp, s_axil_init_rvalid, s_axil_init_rready, irq_rm_empty, irq_rm_error, 
  irq_block, irq_block_status)
/* synthesis syn_black_box black_box_pad_pin="rst_n,s_axil_awaddr[31:0],s_axil_awprot[2:0],s_axil_awvalid,s_axil_awready,s_axil_wdata[31:0],s_axil_wstrb[3:0],s_axil_wvalid,s_axil_wready,s_axil_bresp[1:0],s_axil_bvalid,s_axil_bready,s_axil_araddr[31:0],s_axil_arprot[2:0],s_axil_arvalid,s_axil_arready,s_axil_rdata[31:0],s_axil_rresp[1:0],s_axil_rvalid,s_axil_rready,s_axil_init_awaddr[31:0],s_axil_init_awprot[2:0],s_axil_init_awvalid,s_axil_init_awready,s_axil_init_wdata[31:0],s_axil_init_wstrb[3:0],s_axil_init_wvalid,s_axil_init_wready,s_axil_init_bresp[1:0],s_axil_init_bvalid,s_axil_init_bready,s_axil_init_araddr[31:0],s_axil_init_arprot[2:0],s_axil_init_arvalid,s_axil_init_arready,s_axil_init_rdata[31:0],s_axil_init_rresp[1:0],s_axil_init_rvalid,s_axil_init_rready,irq_rm_empty,irq_rm_error,irq_block,irq_block_status[1:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axil:s_axil_init, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, INSERT_VIP 0" *) input clk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input rst_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [31:0]s_axil_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWPROT" *) input [2:0]s_axil_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *) input s_axil_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *) output s_axil_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *) input [31:0]s_axil_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *) input [3:0]s_axil_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *) input s_axil_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *) output s_axil_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *) output [1:0]s_axil_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *) output s_axil_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *) input s_axil_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *) input [31:0]s_axil_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARPROT" *) input [2:0]s_axil_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *) input s_axil_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *) output s_axil_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *) output [31:0]s_axil_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *) output [1:0]s_axil_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *) output s_axil_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *) input s_axil_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWADDR" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil_init, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [31:0]s_axil_init_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWPROT" *) input [2:0]s_axil_init_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWVALID" *) input s_axil_init_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWREADY" *) output s_axil_init_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WDATA" *) input [31:0]s_axil_init_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WSTRB" *) input [3:0]s_axil_init_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WVALID" *) input s_axil_init_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WREADY" *) output s_axil_init_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BRESP" *) output [1:0]s_axil_init_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BVALID" *) output s_axil_init_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BREADY" *) input s_axil_init_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARADDR" *) input [31:0]s_axil_init_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARPROT" *) input [2:0]s_axil_init_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARVALID" *) input s_axil_init_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARREADY" *) output s_axil_init_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RDATA" *) output [31:0]s_axil_init_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RRESP" *) output [1:0]s_axil_init_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RVALID" *) output s_axil_init_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RREADY" *) input s_axil_init_rready;
  output irq_rm_empty;
  output irq_rm_error;
  output irq_block;
  output [1:0]irq_block_status;
endmodule
