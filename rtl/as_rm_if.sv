// -------------------------------------------------------------------------------------------
// Interface: as_rm_if
// Description: Signals crossing the AXI/SRAM Controller → Ring Manager boundary.
//              Single-cycle completion pulse when a descriptor transfer finishes.
// -------------------------------------------------------------------------------------------

interface as_rm_if ();

    logic as_done; // Single-cycle pulse from AXI4/SRAM controller when a descriptor transfer finishes

    modport as (
        output as_done
    );

    modport rm (
        input as_done
    );

endinterface
