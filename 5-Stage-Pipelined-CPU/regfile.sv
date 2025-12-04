`timescale 1ps/1ps

module regfile(
  output logic [63:0] ReadData1,
  output logic [63:0] ReadData2,
  input  logic [63:0] WriteData,
  input  logic [4:0]  ReadRegister1,
  input  logic [4:0]  ReadRegister2,
  input  logic [4:0]  WriteRegister,
  input  logic        RegWrite,
  input  logic        clk
);

  logic reset = 1'b0; // Test Bench has no reset

  logic [31:0] wen_raw, wen;
  dec5to32 DEC(wen_raw, RegWrite, WriteRegister);
  assign wen[30:0] = wen_raw[30:0];
  assign wen[31]   = 1'b0;

  logic [31:0][63:0] regs_q;
  assign regs_q[31] = 64'b0;

  genvar r;
  generate for (r=0;r<31;r++) begin: REGS
    reg64_en RX(regs_q[r], WriteData, wen[r], reset, clk);
  end endgenerate

  mux32_64 RD1(ReadData1, regs_q, ReadRegister1);
  mux32_64 RD2(ReadData2, regs_q, ReadRegister2);
endmodule
