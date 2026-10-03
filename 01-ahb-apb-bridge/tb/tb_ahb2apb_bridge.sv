//------------------------------------------------------------------------------
// Self-checking testbench for ahb2apb_bridge
//  - AHB master BFM (write/read tasks)
//  - APB slave model with configurable wait states
//  - Reference memory scoreboard + APB protocol monitor
//------------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_ahb2apb_bridge;

  logic        HCLK = 0, HRESETn = 0;
  logic        HSEL = 0, HWRITE = 0, HREADY;
  logic [31:0] HADDR = 0, HWDATA = 0, HRDATA;
  logic [1:0]  HTRANS = 0;
  logic [2:0]  HSIZE = 3'b010;
  logic        HRESP;

  logic [31:0] PADDR, PWDATA, PRDATA;
  logic        PSEL, PENABLE, PWRITE, PREADY;

  integer errors = 0, checks = 0;
  integer wait_states = 0;

  always #5 HCLK = ~HCLK;

  ahb2apb_bridge dut (
    .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(HSEL), .HADDR(HADDR),
    .HWRITE(HWRITE), .HTRANS(HTRANS), .HSIZE(HSIZE), .HWDATA(HWDATA),
    .HREADY(HREADY), .HRDATA(HRDATA), .HREADYOUT(HREADY), .HRESP(HRESP),
    .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
    .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY)
  );

  // ---------------- APB slave model ----------------
  logic [31:0] slave_mem [0:15];
  integer wcnt = 0;

  assign PREADY = (wcnt >= wait_states);
  assign PRDATA = slave_mem[PADDR[5:2]];

  always @(posedge HCLK) begin
    if (PSEL && PENABLE && !PREADY) wcnt <= wcnt + 1;
    else                            wcnt <= 0;
    if (PSEL && PENABLE && PREADY && PWRITE)
      slave_mem[PADDR[5:2]] <= PWDATA;
  end

  // ---------------- Reference model ----------------
  logic [31:0] ref_mem [0:15];

  // ---------------- AHB master BFM ----------------
  task automatic ahb_write(input [31:0] addr, input [31:0] data);
    begin
      HSEL <= 1; HADDR <= addr; HWRITE <= 1; HTRANS <= 2'b10;
      @(posedge HCLK); while (!HREADY) @(posedge HCLK);      // address accepted
      HSEL <= 0; HTRANS <= 2'b00; HWDATA <= data;
      @(posedge HCLK); while (!HREADY) @(posedge HCLK);      // data phase done
      ref_mem[addr[5:2]] = data;
    end
  endtask

  task automatic ahb_read(input [31:0] addr, output [31:0] data);
    begin
      HSEL <= 1; HADDR <= addr; HWRITE <= 0; HTRANS <= 2'b10;
      @(posedge HCLK); while (!HREADY) @(posedge HCLK);
      HSEL <= 0; HTRANS <= 2'b00;
      @(posedge HCLK); while (!HREADY) @(posedge HCLK);
      data = HRDATA;                                         // sampled at completion
    end
  endtask

  task automatic check_read(input [31:0] addr);
    logic [31:0] rd;
    begin
      ahb_read(addr, rd);
      checks = checks + 1;
      if (rd !== ref_mem[addr[5:2]]) begin
        errors = errors + 1;
        $display("[FAIL] t=%0t addr=%h exp=%h got=%h", $time, addr, ref_mem[addr[5:2]], rd);
      end else
        $display("[PASS] t=%0t addr=%h data=%h", $time, addr, rd);
    end
  endtask

  // ---------------- APB protocol monitor ----------------
  logic psel_d = 0, penable_d = 0;
  always @(posedge HCLK) begin
    psel_d <= PSEL; penable_d <= PENABLE;
    if (HRESETn) begin
      if (PENABLE && !PSEL) begin
        errors = errors + 1; $display("[PROTO] PENABLE without PSEL");
      end
      if (PENABLE && !penable_d && !psel_d) begin
        errors = errors + 1; $display("[PROTO] ACCESS without SETUP");
      end
    end
  end

  // ---------------- Tests ----------------
  integer i, w;
  logic [31:0] a, d;

  initial begin
    for (i = 0; i < 16; i = i + 1) begin slave_mem[i] = 0; ref_mem[i] = 0; end
    repeat (3) @(posedge HCLK);
    HRESETn <= 1;
    repeat (2) @(posedge HCLK);

    for (w = 0; w < 4; w = w + 2) begin      // wait_states = 0 then 2
      wait_states = w;
      $display("=== Directed tests, APB wait states = %0d ===", w);
      for (i = 0; i < 16; i = i + 1) ahb_write(i*4, 32'hA5A5_0000 + i + w);
      for (i = 0; i < 16; i = i + 1) check_read(i*4);

      $display("=== Random tests, APB wait states = %0d ===", w);
      repeat (100) begin
        a = ($urandom_range(0,15)) * 4;
        d = $urandom;
        if ($urandom_range(0,1)) ahb_write(a, d);
        else                     check_read(a);
      end
    end

    $display("-----------------------------------------");
    $display("Checks: %0d   Errors: %0d", checks, errors);
    if (errors == 0) $display("RESULT: TEST PASSED");
    else             $display("RESULT: TEST FAILED");
    $finish;
  end

  initial begin
    $dumpfile("sim/ahb2apb.vcd");
    $dumpvars(0, tb_ahb2apb_bridge);
  end

  initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
