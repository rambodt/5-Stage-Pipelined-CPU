`timescale 1ps/1ps

module mux2_1(output logic y, input logic a,b,s);
  logic ns, a0, a1;
  g_inv  U0(ns, s);
  g_and2 U1(a0, a, ns);
  g_and2 U2(a1, b, s);
  g_or2  U3(y, a0, a1);
endmodule

module mux2_64(output logic [63:0] y,
               input  logic [63:0] a,b,
               input  logic        s);
  genvar i;
  
  generate for (i=0;i<64;i++) begin: loop
    mux2_1 M(y[i], a[i], b[i], s);
	end 
  endgenerate
endmodule

module mux2_32(
  output logic [31:0] out,
  input  logic [31:0] i0,
  input  logic [31:0] i1,
  input  logic        sel
);
  genvar b;
  generate
    for (b = 0; b < 32; b++) begin : MUXBITS
      mux2_1 M(.y (out[b]),.a (i0[b]),.b (i1[b]),.s (sel));
    end
  endgenerate
endmodule