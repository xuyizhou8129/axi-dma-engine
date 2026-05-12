`timescale 1ns / 1ps

module tb_axi_4_master;

    localparam int MEM_WORDS = 256;
    localparam int QD        = 64;

    logic clock;
    logic reset;

    axi_4_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axi (.clk(clock), .rst_n(~reset));

    logic        df_in_rd_en;
    logic        df_in_empty;
    logic [39:0] df_in_dout;
    logic        df_out_wr_en;
    logic        df_out_full;
    logic [127:0] df_out_din;
    logic        dm_in_rd_en;
    logic        dm_in_empty;
    logic [40:0] dm_in_dout;
    logic        mid_wr_en;
    logic        mid_full;
    logic [31:0] mid_din;
    logic        mid_rd_en;
    logic        mid_empty;
    logic [31:0] mid_dout;
    // Tie high when no separate SRAM controller (AXI mem completes in same cycle as protocol).
    // Drive from real SRAM controller done/ready when integrated.
    logic        sram_done;
    assign       sram_done = 1'b1;
    logic        axi_done;

    axi_4_master dut (
        .clock        (clock),
        .reset        (reset),
        .sram_done    (sram_done),
        .axi_done     (axi_done),
        .df_in_rd_en  (df_in_rd_en),
        .df_in_empty  (df_in_empty),
        .df_in_dout   (df_in_dout),
        .df_out_wr_en (df_out_wr_en),
        .df_out_full  (df_out_full),
        .df_out_din   (df_out_din),
        .dm_in_rd_en  (dm_in_rd_en),
        .dm_in_empty  (dm_in_empty),
        .dm_in_dout   (dm_in_dout),
        .mid_wr_en    (mid_wr_en),
        .mid_full     (mid_full),
        .mid_din      (mid_din),
        .mid_rd_en    (mid_rd_en),
        .mid_empty    (mid_empty),
        .mid_dout     (mid_dout),
        .axi          (axi)
    );

    axi_mem_behav #(
        .MEM_WORDS(MEM_WORDS)
    ) u_mem (
        .axi(axi)
    );

    // --- TB stimulus: preload via rtl/fifo.sv (same as RTL IP) ---
    logic        stim_load;
    logic        tb_df_wr_en;
    logic [39:0] tb_df_din;
    logic        tb_dm_wr_en;
    logic [40:0] tb_dm_din;
    logic        tb_mid_wr_en;
    logic [31:0] tb_mid_din;

    logic df_in_full_w;
    logic dm_in_full_w;

    wire df_wr_en  = stim_load & tb_df_wr_en;
    wire dm_wr_en  = stim_load & tb_dm_wr_en;
    wire mid_wr_en_i = stim_load ? tb_mid_wr_en : mid_wr_en;
    wire [31:0] mid_din_i = stim_load ? tb_mid_din : mid_din;

    fifo #(
        .FIFO_DATA_WIDTH(40),
        .FIFO_BUFFER_SIZE(QD)
    ) u_df_in (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (df_wr_en),
        .din    (tb_df_din),
        .full   (df_in_full_w),
        .rd_clk (clock),
        .rd_en  (df_in_rd_en),
        .dout   (df_in_dout),
        .empty  (df_in_empty)
    );

    fifo #(
        .FIFO_DATA_WIDTH(41),
        .FIFO_BUFFER_SIZE(QD)
    ) u_dm_in (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (dm_wr_en),
        .din    (tb_dm_din),
        .full   (dm_in_full_w),
        .rd_clk (clock),
        .rd_en  (dm_in_rd_en),
        .dout   (dm_in_dout),
        .empty  (dm_in_empty)
    );

    fifo #(
        .FIFO_DATA_WIDTH(32),
        .FIFO_BUFFER_SIZE(QD)
    ) u_mid (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (mid_wr_en_i),
        .din    (mid_din_i),
        .full   (mid_full),
        .rd_clk (clock),
        .rd_en  (mid_rd_en),
        .dout   (mid_dout),
        .empty  (mid_empty)
    );

    assign df_out_full = 1'b0;

    // --- Scoreboard captures ---
    localparam int MAX_DF = 8;
    localparam int MAX_MID_CAP = 64;
    logic [127:0] cap_df[0:MAX_DF-1];
    integer       n_cap_df;
    logic [31:0]  cap_mid[0:MAX_MID_CAP-1];
    integer       n_cap_mid;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            n_cap_df  <= 0;
            n_cap_mid <= 0;
        end else begin
            if (df_out_wr_en && n_cap_df < MAX_DF) begin
                cap_df[n_cap_df] <= df_out_din;
                n_cap_df         <= n_cap_df + 1;
            end
            if (mid_wr_en && n_cap_mid < MAX_MID_CAP) begin
                cap_mid[n_cap_mid] <= mid_din;
                n_cap_mid          <= n_cap_mid + 1;
            end
        end
    end

    task automatic push_df(input logic [39:0] v);
        if (!stim_load) $fatal(1, "push_df outside stim_load");
        while (df_in_full_w) @(posedge clock);
        tb_df_wr_en = 1'b1;
        tb_df_din   = v;
        @(posedge clock);
        tb_df_wr_en = 1'b0;
    endtask

    task automatic push_dm(input logic [40:0] v);
        if (!stim_load) $fatal(1, "push_dm outside stim_load");
        while (dm_in_full_w) @(posedge clock);
        tb_dm_wr_en = 1'b1;
        tb_dm_din   = v;
        @(posedge clock);
        tb_dm_wr_en = 1'b0;
    endtask

    task automatic push_mid(input logic [31:0] v);
        if (!stim_load) $fatal(1, "push_mid outside stim_load");
        while (mid_full) @(posedge clock);
        tb_mid_wr_en = 1'b1;
        tb_mid_din   = v;
        @(posedge clock);
        tb_mid_wr_en = 1'b0;
    endtask

    task load_stim(input reg [1023:0] path);
        int fh, n, wi, ln;
        logic [31:0] da, mb;
        reg [2047:0] line;
        fh = $fopen(path, "r");
        if (fh == 0) begin
            $display("FATAL: cannot open %s (run csv_golden_runner.py first)", path);
            $finish(1);
        end
        n = 0;
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            if (line[7:0] == 8'h0) continue;
            if (line[7:0] == 8'h23) continue;  // '#'
            if ($sscanf(line, "mem %d %x", wi, da) == 2) begin
                ;
            end else if ($sscanf(line, "handle %x %d", mb, ln) == 2) begin
                push_df({ln[7:0], mb});
                n = n + 1;
            end else if ($sscanf(line, "mid %x", da) == 1) begin
                push_mid(da);
                n = n + 1;
            end else if ($sscanf(line, "dm_rd %x %d", mb, ln) == 2) begin
                push_dm({1'b0, ln[7:0], mb});
                n = n + 1;
            end else if ($sscanf(line, "dm_wr %x %d", mb, ln) == 2) begin
                push_dm({1'b1, ln[7:0], mb});
                n = n + 1;
            end
        end
        $fclose(fh);
        $display("Loaded %0d stim records (handle/mid/dm_*)", n);
    endtask

    task check_mem;
        logic [31:0] golden[0:MEM_WORDS-1];
        int i, mism;
        mism = 0;
        $readmemh("../out/golden_mem.hex", golden);
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            if (golden[i] !== u_mem.ram[i]) begin
                $display("MEM mismatch @%0d: got %08x exp %08x", i, u_mem.ram[i], golden[i]);
                mism = mism + 1;
            end
        end
        if (mism != 0) $fatal(1, "memory compare failed");
        $display("MEM compare OK");
    endtask

    task check_df;
        int fh, i, c;
        logic [127:0] expv;
        reg [255:0] line;
        fh = $fopen("../out/golden_df_out.hex", "r");
        if (fh == 0) $fatal(1, "open golden_df_out.hex");
        for (i = 0; i < n_cap_df; i = i + 1) begin
            c = $fgets(line, fh);
            if ($sscanf(line, "%x", expv) != 1) $fatal(1, "bad golden_df line");
            if (cap_df[i] !== expv) $fatal(1, "df_out mismatch");
        end
        $fclose(fh);
        $display("DF_OUT compare OK (%0d)", n_cap_df);
    endtask

    task check_mid;
        int fh, i, c;
        logic [31:0] expw;
        reg [255:0] line;
        fh = $fopen("../out/golden_mid.hex", "r");
        if (fh == 0) $fatal(1, "open golden_mid.hex");
        for (i = 0; i < n_cap_mid; i = i + 1) begin
            c = $fgets(line, fh);
            if ($sscanf(line, "%x", expw) != 1) $fatal(1, "bad golden_mid line");
            if (cap_mid[i] !== expw) $fatal(1, "mid_cap mismatch");
        end
        $fclose(fh);
        $display("MID compare OK (%0d)", n_cap_mid);
    endtask

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    initial begin
        stim_load        = 1'b0;
        tb_df_wr_en      = 1'b0;
        tb_dm_wr_en      = 1'b0;
        tb_mid_wr_en     = 1'b0;
        tb_df_din        = '0;
        tb_dm_din        = '0;
        tb_mid_din       = '0;

        reset = 1;
        repeat (8) @(posedge clock);
        reset = 0;
        @(posedge clock);

        stim_load = 1'b1;
        load_stim("../out/stim.txt");
        stim_load = 1'b0;

        repeat (8000) @(posedge clock);

        check_mem();
        if (n_cap_df > 0) check_df();
        if (n_cap_mid > 0) check_mid();

        $display("*** TB PASS ***");
        $finish(0);
    end

endmodule
