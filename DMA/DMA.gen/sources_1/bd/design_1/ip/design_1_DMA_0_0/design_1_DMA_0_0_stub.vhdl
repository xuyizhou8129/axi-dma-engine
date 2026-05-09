-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
-- Date        : Mon May  4 18:29:47 2026
-- Host        : NUL-LENDLAP97 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/laptop/Desktop/DMA/DMA.gen/sources_1/bd/design_1/ip/design_1_DMA_0_0/design_1_DMA_0_0_stub.vhdl
-- Design      : design_1_DMA_0_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity design_1_DMA_0_0 is
  Port ( 
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    s_axil_awaddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axil_awvalid : in STD_LOGIC;
    s_axil_awready : out STD_LOGIC;
    s_axil_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axil_wvalid : in STD_LOGIC;
    s_axil_wready : out STD_LOGIC;
    s_axil_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axil_bvalid : out STD_LOGIC;
    s_axil_bready : in STD_LOGIC;
    s_axil_araddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axil_arvalid : in STD_LOGIC;
    s_axil_arready : out STD_LOGIC;
    s_axil_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axil_rvalid : out STD_LOGIC;
    s_axil_rready : in STD_LOGIC;
    s_axil_init_awaddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_init_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axil_init_awvalid : in STD_LOGIC;
    s_axil_init_awready : out STD_LOGIC;
    s_axil_init_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_init_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axil_init_wvalid : in STD_LOGIC;
    s_axil_init_wready : out STD_LOGIC;
    s_axil_init_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axil_init_bvalid : out STD_LOGIC;
    s_axil_init_bready : in STD_LOGIC;
    s_axil_init_araddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_init_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s_axil_init_arvalid : in STD_LOGIC;
    s_axil_init_arready : out STD_LOGIC;
    s_axil_init_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_init_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axil_init_rvalid : out STD_LOGIC;
    s_axil_init_rready : in STD_LOGIC;
    irq_rm_empty : out STD_LOGIC;
    irq_rm_error : out STD_LOGIC;
    irq_block : out STD_LOGIC;
    irq_block_status : out STD_LOGIC_VECTOR ( 1 downto 0 )
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of design_1_DMA_0_0 : entity is "design_1_DMA_0_0,vivado_config,{}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of design_1_DMA_0_0 : entity is "yes";
  attribute IP_DEFINITION_SOURCE : string;
  attribute IP_DEFINITION_SOURCE of design_1_DMA_0_0 : entity is "package_project";
end design_1_DMA_0_0;

architecture stub of design_1_DMA_0_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "clk,rst_n,s_axil_awaddr[31:0],s_axil_awprot[2:0],s_axil_awvalid,s_axil_awready,s_axil_wdata[31:0],s_axil_wstrb[3:0],s_axil_wvalid,s_axil_wready,s_axil_bresp[1:0],s_axil_bvalid,s_axil_bready,s_axil_araddr[31:0],s_axil_arprot[2:0],s_axil_arvalid,s_axil_arready,s_axil_rdata[31:0],s_axil_rresp[1:0],s_axil_rvalid,s_axil_rready,s_axil_init_awaddr[31:0],s_axil_init_awprot[2:0],s_axil_init_awvalid,s_axil_init_awready,s_axil_init_wdata[31:0],s_axil_init_wstrb[3:0],s_axil_init_wvalid,s_axil_init_wready,s_axil_init_bresp[1:0],s_axil_init_bvalid,s_axil_init_bready,s_axil_init_araddr[31:0],s_axil_init_arprot[2:0],s_axil_init_arvalid,s_axil_init_arready,s_axil_init_rdata[31:0],s_axil_init_rresp[1:0],s_axil_init_rvalid,s_axil_init_rready,irq_rm_empty,irq_rm_error,irq_block,irq_block_status[1:0]";
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_MODE : string;
  attribute X_INTERFACE_MODE of clk : signal is "slave";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of clk : signal is "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axil:s_axil_init, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of rst_n : signal is "xilinx.com:signal:reset:1.0 rst_n RST";
  attribute X_INTERFACE_MODE of rst_n : signal is "slave";
  attribute X_INTERFACE_PARAMETER of rst_n : signal is "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axil_awaddr : signal is "xilinx.com:interface:aximm:1.0 s_axil AWADDR";
  attribute X_INTERFACE_MODE of s_axil_awaddr : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axil_awaddr : signal is "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axil_awprot : signal is "xilinx.com:interface:aximm:1.0 s_axil AWPROT";
  attribute X_INTERFACE_INFO of s_axil_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil AWVALID";
  attribute X_INTERFACE_INFO of s_axil_awready : signal is "xilinx.com:interface:aximm:1.0 s_axil AWREADY";
  attribute X_INTERFACE_INFO of s_axil_wdata : signal is "xilinx.com:interface:aximm:1.0 s_axil WDATA";
  attribute X_INTERFACE_INFO of s_axil_wstrb : signal is "xilinx.com:interface:aximm:1.0 s_axil WSTRB";
  attribute X_INTERFACE_INFO of s_axil_wvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil WVALID";
  attribute X_INTERFACE_INFO of s_axil_wready : signal is "xilinx.com:interface:aximm:1.0 s_axil WREADY";
  attribute X_INTERFACE_INFO of s_axil_bresp : signal is "xilinx.com:interface:aximm:1.0 s_axil BRESP";
  attribute X_INTERFACE_INFO of s_axil_bvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil BVALID";
  attribute X_INTERFACE_INFO of s_axil_bready : signal is "xilinx.com:interface:aximm:1.0 s_axil BREADY";
  attribute X_INTERFACE_INFO of s_axil_araddr : signal is "xilinx.com:interface:aximm:1.0 s_axil ARADDR";
  attribute X_INTERFACE_INFO of s_axil_arprot : signal is "xilinx.com:interface:aximm:1.0 s_axil ARPROT";
  attribute X_INTERFACE_INFO of s_axil_arvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil ARVALID";
  attribute X_INTERFACE_INFO of s_axil_arready : signal is "xilinx.com:interface:aximm:1.0 s_axil ARREADY";
  attribute X_INTERFACE_INFO of s_axil_rdata : signal is "xilinx.com:interface:aximm:1.0 s_axil RDATA";
  attribute X_INTERFACE_INFO of s_axil_rresp : signal is "xilinx.com:interface:aximm:1.0 s_axil RRESP";
  attribute X_INTERFACE_INFO of s_axil_rvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil RVALID";
  attribute X_INTERFACE_INFO of s_axil_rready : signal is "xilinx.com:interface:aximm:1.0 s_axil RREADY";
  attribute X_INTERFACE_INFO of s_axil_init_awaddr : signal is "xilinx.com:interface:aximm:1.0 s_axil_init AWADDR";
  attribute X_INTERFACE_MODE of s_axil_init_awaddr : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axil_init_awaddr : signal is "XIL_INTERFACENAME s_axil_init, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_1_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axil_init_awprot : signal is "xilinx.com:interface:aximm:1.0 s_axil_init AWPROT";
  attribute X_INTERFACE_INFO of s_axil_init_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil_init AWVALID";
  attribute X_INTERFACE_INFO of s_axil_init_awready : signal is "xilinx.com:interface:aximm:1.0 s_axil_init AWREADY";
  attribute X_INTERFACE_INFO of s_axil_init_wdata : signal is "xilinx.com:interface:aximm:1.0 s_axil_init WDATA";
  attribute X_INTERFACE_INFO of s_axil_init_wstrb : signal is "xilinx.com:interface:aximm:1.0 s_axil_init WSTRB";
  attribute X_INTERFACE_INFO of s_axil_init_wvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil_init WVALID";
  attribute X_INTERFACE_INFO of s_axil_init_wready : signal is "xilinx.com:interface:aximm:1.0 s_axil_init WREADY";
  attribute X_INTERFACE_INFO of s_axil_init_bresp : signal is "xilinx.com:interface:aximm:1.0 s_axil_init BRESP";
  attribute X_INTERFACE_INFO of s_axil_init_bvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil_init BVALID";
  attribute X_INTERFACE_INFO of s_axil_init_bready : signal is "xilinx.com:interface:aximm:1.0 s_axil_init BREADY";
  attribute X_INTERFACE_INFO of s_axil_init_araddr : signal is "xilinx.com:interface:aximm:1.0 s_axil_init ARADDR";
  attribute X_INTERFACE_INFO of s_axil_init_arprot : signal is "xilinx.com:interface:aximm:1.0 s_axil_init ARPROT";
  attribute X_INTERFACE_INFO of s_axil_init_arvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil_init ARVALID";
  attribute X_INTERFACE_INFO of s_axil_init_arready : signal is "xilinx.com:interface:aximm:1.0 s_axil_init ARREADY";
  attribute X_INTERFACE_INFO of s_axil_init_rdata : signal is "xilinx.com:interface:aximm:1.0 s_axil_init RDATA";
  attribute X_INTERFACE_INFO of s_axil_init_rresp : signal is "xilinx.com:interface:aximm:1.0 s_axil_init RRESP";
  attribute X_INTERFACE_INFO of s_axil_init_rvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil_init RVALID";
  attribute X_INTERFACE_INFO of s_axil_init_rready : signal is "xilinx.com:interface:aximm:1.0 s_axil_init RREADY";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of stub : architecture is "vivado_config,Vivado 2025.2";
begin
end;
