interface csr_soc_bus_if (
    input logic clk,
    input logic rst_n
);
    logic [31:0]           awaddr;
    logic [2:0]            awprot;
    logic                  awvalid;
    logic                  awready;

    logic [31:0]           wdata;
    logic [3:0]            wstrb;
    logic                  wvalid;
    logic                  wready;

    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    logic [31:0]           araddr;
    logic [2:0]            arprot;
    logic                  arvalid;
    logic                  arready;

    logic [31:0]           rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    logic                  irq;
    logic                  irq_empty;
    logic                  irq_error;

    // CSR block is AXI4-Lite slave from the SoC perspective.
    modport slave (
        input  clk, rst_n,
        input  awaddr, awprot, awvalid,
        output awready,
        input  wdata, wstrb, wvalid,
        output wready,
        output bresp, bvalid,
        input  bready,
        input  araddr, arprot, arvalid,
        output arready,
        output rdata, rresp, rvalid,
        input  rready,
        output irq, irq_empty, irq_error
    );

    modport master (
        input  clk, rst_n,
        output awaddr, awprot, awvalid,
        input  awready,
        output wdata, wstrb, wvalid,
        input  wready,
        input  bresp, bvalid,
        output bready,
        output araddr, arprot, arvalid,
        input  arready,
        input  rdata, rresp, rvalid,
        output rready,
        input  irq, irq_empty, irq_error
    );
endinterface

interface csr_ring_manager_if (
    input logic clk,
    input logic rst_n
);
    // CSR -> RingManager (configuration/control values)
    logic [31:0] baseaddr;
    logic [31:0] ringlen;
    logic [31:0] tail;
    logic        enable;
    logic        reset;
    logic        irq_en;
    logic        error_clear;

    // RingManager -> CSR (status/events)
    logic [31:0] head;
    logic        busy;
    logic        ring_empty;
    logic        irq_empty_set;
    logic        error_set;

    modport master (
        input  clk, rst_n,
        output baseaddr, ringlen, tail, enable, reset, irq_en, error_clear,
        input  head, busy, ring_empty, irq_empty_set, error_set
    );

    modport slave (
        input  clk, rst_n,
        input  baseaddr, ringlen, tail, enable, reset, irq_en, error_clear,
        output head, busy, ring_empty, irq_empty_set, error_set
    );
endinterface
