module IRQ (
    input logic         clk,
    input logic         rst_n,

    input logic         empty_event,    //pulse from ring manager
    input logic         error_event,    //pulse from ring manager
    input logic         irq_en,         //CTRL from CSR
    input logic [1:0]   irq_clear,      //written by CPU

    output logic [1:0]  irq_status,     //feeds back into IRQ_STATUS in CSR? (unsure)
    output logic        irq             //goes to CPU interrupt pin
);
    // comb signals
    logic next_status_error;
    logic status_empty;
    logic status_error;
    logic next_status_empty;      //status flag for empty IRQ register

    // comb blocks for error and empty ffs
    always_comb begin 
        next_status_empty = status_empty;

        if (empty_event)
            next_status_empty = 1;
        else if (irq_clear[0]) 
            next_status_empty = 0;
    end

    always_comb begin 
        next_status_error = status_error;
        if (error_event)
            next_status_error = 1;
        else if (irq_clear[1]) 
            next_status_error = 0;
    end

    // latches the value on rising edge for empty 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_empty <= 0;
        end else begin
            status_empty <= next_status_empty;
        end
    end

    // latches the value on rising edge for error, similar to empty
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            status_error <= 0;
        end else begin
            status_error <= next_status_error;
        end
    end     

    //wire up outputs
    // msb first, flipped indexing apparently
    assign irq_status = {status_error, status_empty};
    assign irq = (status_error | status_empty) & irq_en;

endmodule