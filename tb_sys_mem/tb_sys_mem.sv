// Test harness: clock/reset, stimulus tasks, and checks.
// Hierarchy: tb_sys_mem_top (DUT + capture).

`timescale 1ns / 1ps

module tb_sys_mem;

    string out_dir;

    logic clk;
    logic rst_n;

    // Write address channel
    logic [31:0] awaddr;
    logic [7:0]  awlen;
    logic        awvalid;
    logic        awready;

    // Write data channel
    logic [31:0] wdata;
    logic        wlast;
    logic        wvalid;
    logic        wready;

    // Write response channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // Read address channel
    logic [31:0] araddr;
    logic [7:0]  arlen;
    logic        arvalid;
    logic        arready;

    // Read data channel
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rlast;
    logic        rvalid;
    logic        rready;

    tb_sys_mem_top u_top (
        .clk    (clk),
        .rst_n  (rst_n),
        .awaddr (awaddr),
        .awlen  (awlen),
        .awvalid(awvalid),
        .awready(awready),
        .wdata  (wdata),
        .wlast  (wlast),
        .wvalid (wvalid),
        .wready (wready),
        .bresp  (bresp),
        .bvalid (bvalid),
        .bready (bready),
        .araddr (araddr),
        .arlen  (arlen),
        .arvalid(arvalid),
        .arready(arready),
        .rdata  (rdata),
        .rresp  (rresp),
        .rlast  (rlast),
        .rvalid (rvalid),
        .rready (rready)
    );

    // Single-beat AXI write: send AW, W, then wait for B response
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
        while (!awready) @(posedge clk);
        awaddr  = addr;
        awlen   = 8'h00;
        awvalid = 1'b1;
        @(posedge clk);
        awvalid = 1'b0;

        while (!wready) @(posedge clk);
        wdata  = data;
        wlast  = 1'b1;
        wvalid = 1'b1;
        @(posedge clk);
        wvalid = 1'b0;
        wlast  = 1'b0;

        bready = 1'b1;
        while (!bvalid) @(posedge clk);
        @(posedge clk);
        bready = 1'b0;
    endtask

    // AXI read burst: send AR, wait for all beats (arlen_val = AXI arlen = beats-1)
    task automatic axi_read(input logic [31:0] addr, input logic [7:0] arlen_val);
        while (!arready) @(posedge clk);
        araddr  = addr;
        arlen   = arlen_val;
        arvalid = 1'b1;
        @(posedge clk);
        arvalid = 1'b0;

        rready = 1'b1;
        while (!(rvalid && rlast)) @(posedge clk);
        @(posedge clk);
        rready = 1'b0;
    endtask

    task automatic load_stim(input string path);
        int fh, n;
        logic [31:0] addr;
        logic [31:0] data;
        logic [7:0]  arlen_val;
        reg [2047:0] line;

        fh = $fopen(path, "r");
        if (fh == 0) $fatal(1, "cannot open %s", path);
        n = 0;
        while (!$feof(fh)) begin
            if ($fgets(line, fh) == 0) continue;
            if (line[7:0] == 8'h0)  continue;
            if (line[7:0] == 8'h23) continue;  // '#'
            if ($sscanf(line, "wr %x %x", addr, data) == 2) begin
                axi_write(addr, data);
                n = n + 1;
            end else if ($sscanf(line, "rd %x %x", addr, arlen_val) == 2) begin
                axi_read(addr, arlen_val);
                n = n + 1;
            end
        end
        $fclose(fh);
        $display("Loaded %0d stim records", n);
    endtask

    task automatic check_rdata;
        int fh, i, c;
        logic [31:0] expv;
        reg [255:0]  line;
        fh = $fopen($sformatf("%s/golden_rd.hex", out_dir), "r");
        if (fh == 0) $fatal(1, "open golden_rd.hex");
        for (i = 0; i < u_top.n_cap_rdata; i = i + 1) begin
            c = $fgets(line, fh);
            if ($sscanf(line, "%x", expv) != 1) $fatal(1, "bad golden_rd line %0d", i);
            if (u_top.cap_rdata[i] !== expv)
                $fatal(1, "rdata mismatch @%0d: got %08x exp %08x",
                       i, u_top.cap_rdata[i], expv);
        end
        $fclose(fh);
        $display("Read data compare OK (%0d beats)", u_top.n_cap_rdata);
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        awaddr  = '0; awlen   = '0; awvalid = 1'b0;
        wdata   = '0; wlast   = 1'b0; wvalid  = 1'b0;
        bready  = 1'b0;
        araddr  = '0; arlen   = '0; arvalid = 1'b0;
        rready  = 1'b0;

        if (!$value$plusargs("OUT_DIR=%s", out_dir))
            out_dir = "../out/test0";

        rst_n = 1'b0;
        repeat (6) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        load_stim($sformatf("%s/stim.txt", out_dir));

        repeat (10) @(posedge clk);

        check_rdata();

        $display("*** TB PASS ***");
        $finish(0);
    end

endmodule
