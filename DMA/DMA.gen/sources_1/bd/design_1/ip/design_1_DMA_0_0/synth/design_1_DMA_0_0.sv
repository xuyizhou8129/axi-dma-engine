// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: northwestern.edu:user:DMA:1.0
// IP Revision: 2

(* X_CORE_INFO = "vivado_config,Vivado 2025.2" *)
(* CHECK_LICENSE_TYPE = "design_1_DMA_0_0,vivado_config,{}" *)
(* IP_DEFINITION_SOURCE = "package_project" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module design_1_DMA_0_0 (
  clk,
  rst_n,
  s_axil_awaddr,
  s_axil_awprot,
  s_axil_awvalid,
  s_axil_awready,
  s_axil_wdata,
  s_axil_wstrb,
  s_axil_wvalid,
  s_axil_wready,
  s_axil_bresp,
  s_axil_bvalid,
  s_axil_bready,
  s_axil_araddr,
  s_axil_arprot,
  s_axil_arvalid,
  s_axil_arready,
  s_axil_rdata,
  s_axil_rresp,
  s_axil_rvalid,
  s_axil_rready,
  s_axil_init_awaddr,
  s_axil_init_awprot,
  s_axil_init_awvalid,
  s_axil_init_awready,
  s_axil_init_wdata,
  s_axil_init_wstrb,
  s_axil_init_wvalid,
  s_axil_init_wready,
  s_axil_init_bresp,
  s_axil_init_bvalid,
  s_axil_init_bready,
  s_axil_init_araddr,
  s_axil_init_arprot,
  s_axil_init_arvalid,
  s_axil_init_arready,
  s_axil_init_rdata,
  s_axil_init_rresp,
  s_axil_init_rvalid,
  s_axil_init_rready,
  irq_rm_empty,
  irq_rm_error,
  irq_block,
  irq_block_status
);

(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axil:s_axil_init, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, INSERT_VIP 0" *)
input wire clk;
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
input wire rst_n;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS \
1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire [31 : 0] s_axil_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWPROT" *)
input wire [2 : 0] s_axil_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
input wire s_axil_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
output wire s_axil_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
input wire [31 : 0] s_axil_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
input wire [3 : 0] s_axil_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
input wire s_axil_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
output wire s_axil_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
output wire [1 : 0] s_axil_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
output wire s_axil_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
input wire s_axil_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
input wire [31 : 0] s_axil_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARPROT" *)
input wire [2 : 0] s_axil_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
input wire s_axil_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
output wire s_axil_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
output wire [31 : 0] s_axil_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
output wire [1 : 0] s_axil_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
output wire s_axil_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
input wire s_axil_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWADDR" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil_init, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THR\
EADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire [31 : 0] s_axil_init_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWPROT" *)
input wire [2 : 0] s_axil_init_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWVALID" *)
input wire s_axil_init_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init AWREADY" *)
output wire s_axil_init_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WDATA" *)
input wire [31 : 0] s_axil_init_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WSTRB" *)
input wire [3 : 0] s_axil_init_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WVALID" *)
input wire s_axil_init_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init WREADY" *)
output wire s_axil_init_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BRESP" *)
output wire [1 : 0] s_axil_init_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BVALID" *)
output wire s_axil_init_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init BREADY" *)
input wire s_axil_init_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARADDR" *)
input wire [31 : 0] s_axil_init_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARPROT" *)
input wire [2 : 0] s_axil_init_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARVALID" *)
input wire s_axil_init_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init ARREADY" *)
output wire s_axil_init_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RDATA" *)
output wire [31 : 0] s_axil_init_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RRESP" *)
output wire [1 : 0] s_axil_init_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RVALID" *)
output wire s_axil_init_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil_init RREADY" *)
input wire s_axil_init_rready;
output wire irq_rm_empty;
output wire irq_rm_error;
output wire irq_block;
output wire [1 : 0] irq_block_status;

  vivado_config #(
    .MAX_INFLIGHT(4),
    .MEM_WORDS(256),
    .BRAM_SIZE(256),
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .s_axil_init_awaddr(s_axil_init_awaddr),
    .s_axil_init_awprot(s_axil_init_awprot),
    .s_axil_init_awvalid(s_axil_init_awvalid),
    .s_axil_init_awready(s_axil_init_awready),
    .s_axil_init_wdata(s_axil_init_wdata),
    .s_axil_init_wstrb(s_axil_init_wstrb),
    .s_axil_init_wvalid(s_axil_init_wvalid),
    .s_axil_init_wready(s_axil_init_wready),
    .s_axil_init_bresp(s_axil_init_bresp),
    .s_axil_init_bvalid(s_axil_init_bvalid),
    .s_axil_init_bready(s_axil_init_bready),
    .s_axil_init_araddr(s_axil_init_araddr),
    .s_axil_init_arprot(s_axil_init_arprot),
    .s_axil_init_arvalid(s_axil_init_arvalid),
    .s_axil_init_arready(s_axil_init_arready),
    .s_axil_init_rdata(s_axil_init_rdata),
    .s_axil_init_rresp(s_axil_init_rresp),
    .s_axil_init_rvalid(s_axil_init_rvalid),
    .s_axil_init_rready(s_axil_init_rready),
    .irq_rm_empty(irq_rm_empty),
    .irq_rm_error(irq_rm_error),
    .irq_block(irq_block),
    .irq_block_status(irq_block_status)
  );
endmodule
