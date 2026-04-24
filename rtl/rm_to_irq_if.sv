// -------------------------------------------------------------------------------------------
// Interface: rm_to_irq_if
// Description: Signals crossing the Ring Manager → IRQ Controller boundary.
//              Single-cycle interrupt pulses driven by the Ring Manager.
// -------------------------------------------------------------------------------------------

interface rm_to_irq_if ();

    logic irq_empty; // Pulses for one cycle on the non-empty → empty ring transition
    logic irq_error; // Pulses for one cycle when a descriptor error is detected

    modport rm (
        output irq_empty,
        output irq_error
    );

    modport irq (
        input irq_empty,
        input irq_error
    );

endinterface 
