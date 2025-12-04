`timescale 1ps/1ps

module D_FF (q, d, reset, clk);
 output reg q;
 input d, reset, clk;
 always_ff @(posedge clk)
 if (reset)
 q <= 0; // On reset, set to 0
 else
 q <= d; // Otherwise out = d
endmodule

module reg1_en(output logic q,
               input  logic d, en, reset, clk);
  logic d_next;
  // d_next = en ? d : q
  mux2_1 M(.y(d_next), .a(q), .b(d), .s(en));
  D_FF   F(.q(q), .d(d_next), .reset(reset), .clk(clk));
endmodule


// 64-bit register with enable and synchronous reset.
module reg64_en(
  output logic [63:0] q,
  input  logic [63:0] d,
  input  logic        en,
  input  logic        reset,
  input  logic        clk);
  
  genvar i;
  generate
    for (i = 0; i < 64; i++) begin : G
      reg1_en R(q[i], d[i], en, reset, clk);
    end
  endgenerate
endmodule

// Generic N-bit register with enable and synchronous reset.
module regN_en #(parameter int N = 1)(
  output logic [N-1:0] q,
  input  logic [N-1:0] d,
  input  logic         en,
  input  logic         reset,
  input  logic         clk);
  
  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_REGN
      reg1_en R(q[i], d[i], en, reset, clk);
    end
  endgenerate
endmodule
