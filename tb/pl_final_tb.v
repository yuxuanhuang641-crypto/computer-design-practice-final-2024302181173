`timescale 1ns/1ns

module pl_final_tb();
  reg clk;
  reg rstn;

  integer i;
  integer cycles;
  reg [1023:0] imem_file;

  plcomp dut(.clk(clk), .rstn(rstn));

  initial begin
    if (!$value$plusargs("IMEM=%s", imem_file)) begin
      $display("[ERROR] missing +IMEM=<path>");
      $finish;
    end
    if (!$value$plusargs("CYCLES=%d", cycles)) begin
      cycles = 160;
    end

    $readmemh(imem_file, dut.U_imem.RAM);
    for (i = 0; i < 128; i = i + 1) begin
      dut.U_DM.dmem[i] = 32'h0000_0000;
    end

    clk = 1'b0;
    rstn = 1'b1;
    #50;
    rstn = 1'b0;

    repeat (cycles) @(posedge clk);

    $display("[SNAPSHOT] registers");
    $display("[REG] x0=00000000");
    for (i = 1; i < 32; i = i + 1) begin
      $display("[REG] x%0d=%08x", i, dut.U_PLCPU.U_RF.rf[i]);
    end

    $display("[SNAPSHOT] memory");
    for (i = 0; i < 64; i = i + 1) begin
      $display("[MEM] m%0d=%08x", i, dut.U_DM.dmem[i]);
    end

    $finish;
  end

  always begin
    #5 clk = ~clk;
  end
endmodule
