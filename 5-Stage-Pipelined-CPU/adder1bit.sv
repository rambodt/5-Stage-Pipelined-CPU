`timescale 1ps/1ps


module adder1bit (
    output logic sum,
    output logic cout,
    input  logic a, b, cin
);
    // Gate-level full adder (50 ps delay per gate)
    logic axb, g1, g2;

    xor  #(50) U1(axb, a, b);
    xor  #(50) U2(sum, axb, cin);

    and  #(50) U3(g1, a, b);
    and  #(50) U4(g2, axb, cin);
    or   #(50) U5(cout, g1, g2);
endmodule

// Big_adder64.sv
module Big_adder64(
  output logic [63:0] sum,
  output logic        cout,
  output logic        cin_msb,
  input  logic [63:0] a,
  input  logic [63:0] b,
  input  logic        cin
);
  logic [63:0] c;

  adder1bit FA0 (.sum(sum[0]),  .cout(c[0]),  .a(a[0]),  .b(b[0]),  .cin(cin));
  genvar i;
  generate
    for (i=1; i<63; i++) begin : G
      adder1bit FA (.sum(sum[i]), .cout(c[i]), .a(a[i]), .b(b[i]), .cin(c[i-1]));
    end
  endgenerate
  adder1bit FA63(.sum(sum[63]), .cout(cout), .a(a[63]), .b(b[63]), .cin(c[62]));

  assign cin_msb = c[62];
endmodule
