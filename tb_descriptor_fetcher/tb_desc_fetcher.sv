// Test harness: clock/reset, stimulus tasks, and checks.
// Hierarchy: tb_desc_fetcher_top (DUT + FIFOs + capture).

`timescale 1ns / 1ps

module tb_desc_fetcher;

    localparam int HANDLE_WIDTH = 40;
    localparam int DESC_WIDTH   = 128;

    string out_dir;

    logic clock;
    logic reset;

    logic [31:0] rm_df_addr;
    logic        rm_df_valid;
    logic        df_ready;

    logic               tb_df_out_wr_en;
    logic [DESC_WIDTH-1:0] tb_df_out_din;
    logic               tb_df_out_full;

    tb_desc_fetcher_top u_top (
        .clock           (clock),
        .reset           (reset),
        .rm_df_addr      (rm_df_addr),
        .rm_df_valid     (rm_df_valid),
        .df_ready        (df_ready),
        .tb_df_out_wr_en (tb_df_out_wr_en),
        .tb_df_out_din   (tb_df_out_din),
        .tb_df_out_full  (tb_df_out_full)
    );

    task automatic send_rm(input logic [31:0] addr);
        while (!df_ready) @(posedge clock);
        rm_df_addr  = addr;
        rm_df_valid = 1'b1;
        @(posedge clock);
        rm_df_valid = 1'b0;
    endtask

    task automatic push_cb(input logic [DESC_WIDTH-1:0] payload);
        while (tb_df_out_full) @(posedge clock);
        tb_df_out_din   = payload;
        tb_df_out_wr_en = 1'b1;
        @(posedge clock);
        tb_df_out_wr_en = 1'b0;
    endtask

    task automatic load_stim(input string path);
        int fh, n;
        logic [31:0] addr;
        logic [DESC_WIDTH-1:0] desc;
        reg [2047:0] line;

        fh = $fopen(path, "r");
        if (fh == 0) $fatal(1, "cannot open %s", path);
        n = 0;
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            if (line[7:0] == 8'h0) continue;
            if (line[7:0] == 8'h23) continue;
            if ($sscanf(line, "rm %x", addr) == 1) begin
                send_rm(addr);
                n = n + 1;
            end else if ($sscanf(line, "cb %x", desc) == 1) begin
                push_cb(desc);
                n = n + 1;
            end
        end
        $fclose(fh);
        $display("Loaded %0d stim records", n);
    endtask

    task automatic check_df_in;
        int fh, i, c;
        logic [HANDLE_WIDTH-1:0] expv;
        reg [255:0] line;
        fh = $fopen($sformatf("%s/golden_df_in.hex", out_dir), "r");
        if (fh == 0) $fatal(1, "open golden_df_in.hex");
        for (i = 0; i < u_top.n_cap_df_in; i = i + 1) begin
            c = $fgets(line, fh);
            if ($sscanf(line, "%x", expv) != 1) $fatal(1, "bad golden_df_in line");
            if (u_top.cap_df_in[i] !== expv) $fatal(1, "df_in handle mismatch @%0d", i);
        end
        $fclose(fh);
        $display("DF->AXI handle compare OK (%0d)", u_top.n_cap_df_in);
    endtask

    task automatic check_dm_in;
        int fh, i, c;
        logic [DESC_WIDTH-1:0] expv;
        reg [511:0] line;
        fh = $fopen($sformatf("%s/golden_dm_in.hex", out_dir), "r");
        if (fh == 0) $fatal(1, "open golden_dm_in.hex");
        for (i = 0; i < u_top.n_cap_dm_in; i = i + 1) begin
            c = $fgets(line, fh);
            if ($sscanf(line, "%x", expv) != 1) $fatal(1, "bad golden_dm_in line");
            if (u_top.cap_dm_in[i] !== expv) $fatal(1, "dm_in descriptor mismatch @%0d", i);
        end
        $fclose(fh);
        $display("DF->DM descriptor compare OK (%0d)", u_top.n_cap_dm_in);
    endtask

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    initial begin
        rm_df_addr      = '0;
        rm_df_valid     = 1'b0;
        tb_df_out_wr_en = 1'b0;
        tb_df_out_din   = '0;

        if (!$value$plusargs("OUT_DIR=%s", out_dir))
            out_dir = "../out/test0";

        reset = 1'b1;
        repeat (6) @(posedge clock);
        reset = 1'b0;
        @(posedge clock);

        load_stim($sformatf("%s/stim.txt", out_dir));

        repeat (20) @(posedge clock);

        check_df_in();
        check_dm_in();

        $display("*** TB PASS ***");
        $finish(0);
    end

endmodule
