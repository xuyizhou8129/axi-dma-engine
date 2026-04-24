// -------------------------------------------------------------------------------------------
// Interface: rm_df_if
// Description: Signals crossing the Ring Manager → Descriptor Fetcher boundary.
//              Ready/valid handshake for fetch requests; error response from DF.
// -------------------------------------------------------------------------------------------

interface rm_df_if ();

    logic [dma_pkg::ADDR_WIDTH-1:0] rm_df_addr;  // Address of the next descriptor to fetch
    logic           fetch_req_valid;  // Asserted by RM when a fetch can be issued
    logic           fetch_req_ready;  // Asserted by DF when it can accept a new request
    logic           df_error;         // Asserted by DF for one cycle when the fetched descriptor faults

    modport rm (
        output rm_df_addr,
        output fetch_req_valid,

        input  fetch_req_ready,
        input  df_error
    );

    modport df (
        input  rm_df_addr,
        input  fetch_req_valid,

        output fetch_req_ready,
        output df_error
    );

endinterface
