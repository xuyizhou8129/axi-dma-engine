module IRQ (
    input logic         clk,
    input logic         rst_n,

    input logic         empty_event,    //pulse from ring manager
    input logic         error_event,    //pulse from data mover
    input logic         irq_en,         //CTRL from CSR
    input logic [1:0]   irq_clear,      //written by CPU
    input logic         next_status_empty       //status flag for empty IRQ register

    output logic [1:0]  irq_status,     //feeds back into IRQ_STATUS in CSR? (unsure)
    output logic        irq             //goes to CPU interrupt pin
);
    // comb signals
    logic [1:0] irq_status_c;
    //flip flop for empty_event
    logic status_empty;
    logic status_error;

    always_comb begin 
        next_status_empty = status_empty;

        if (empty_event)
            next_status_empty = 1;
        else if (irq_clear[0]) 
            next_status_empty = 0;
    end

    // latches the value on rising edge
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_empty <= 0;
        else
            status_empty <= next_status_empty;
        end

endmodule

