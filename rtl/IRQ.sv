module IRQ (
    input logic         clk,
    input logic         rst_n,

    input logic         empty_event,    //pulse from ring manager
    input logic         error_event,    //pulse from data mover
    input logic         irq_en,         //CTRL from CSR
    input logic [1:0]   irq_clear,      //written by CPU

    output logic [1:0]  irq_status,     //feeds back into IRQ_STATUS
    output logic [1:0]  irq             //goes to CPU interrupt pin
);
endmodule