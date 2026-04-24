// csr_ring_manager_if: signals crossing the SPI-CSR / Ring-Manager boundary.
// AXI-Lite csr_soc_bus_if has been removed; CSR is now SPI-based (spi_csr.sv).

interface csr_ring_manager_if (
    input logic clk,
    input logic rst_n
);
    // CSR -> RingManager (configuration / control)
    logic [dma_pkg::ADDR_WIDTH-1:0] baseaddr;  // descriptor ring base address
    logic [7:0]  ringlen;    // number of descriptors in ring
    logic [7:0]  tail;       // tail pointer (SW-written)
    logic        enable;     // DMA enable
    logic        reset;      // soft reset
    logic        irq_en;     // interrupt enable
    logic        error_clear; // one-cycle pulse to clear error state

    // RingManager -> CSR (status / events)
    logic [7:0]  head;          // head pointer (HW-advanced)
    logic        busy;          // any descriptor in-flight
    logic        ring_empty;    // head == tail
    logic        irq_empty_set; // pulse: ring became empty
    logic        error_set;     // pulse: descriptor error

    modport csr (
        input  clk, rst_n,
        output baseaddr, ringlen, tail, enable, reset, irq_en, error_clear,
        input  head, busy, ring_empty, irq_empty_set, error_set
    );

    modport ring_manager (
        input  clk, rst_n,
        input  baseaddr, ringlen, tail, enable, reset, irq_en, error_clear,
        output head, busy, ring_empty, irq_empty_set, error_set
    );

endinterface
