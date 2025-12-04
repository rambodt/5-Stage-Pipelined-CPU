// alu64.sv
// 000: B
// 010: A + B
// 011: A - B
// 100: A & B
// 101: A | B
// 110: A ^ B
module alu (
    input  logic [63:0] A,
    input  logic [63:0] B,
    input  logic [2:0]  ALUControl,
    output logic [63:0] Result,
    output logic        Zero,
    output logic        Overflow,
    output logic        CarryOut,
    output logic        Negative
);
    // --- control decode (one-hot for the 6 used ops) ---
    logic n0, n1, n2;
    not #(50) N0(n0, ALUControl[0]);
    not #(50) N1(n1, ALUControl[1]);
    not #(50) N2(n2, ALUControl[2]);

    logic sel_b, sel_add, sel_sub, sel_and, sel_or, sel_xor;

    and #(50) D_B   (sel_b,   n2, n1, n0);                    // 000
    and #(50) D_ADD (sel_add, n2, ALUControl[1], n0);         // 010
    and #(50) D_SUB (sel_sub, n2, ALUControl[1], ALUControl[0]); // 011
    and #(50) D_AND (sel_and, ALUControl[2], n1, n0);         // 100
    and #(50) D_OR  (sel_or,  ALUControl[2], n1, ALUControl[0]); // 101
    and #(50) D_XOR (sel_xor, ALUControl[2], ALUControl[1], n0); // 110

    // shared selects
    logic sel_sum;  // adder output used for ADD/SUB
    or   #(50) S_SUM(sel_sum, sel_add, sel_sub);

    // SUB controls (A + (~B + 1))
    logic invert_b;
    assign invert_b = sel_sub;

    // --- logic paths ---
    logic [63:0] and_ab, or_ab, xor_ab, b_pass;
    genvar i;
    generate
        for (i=0; i<64; i++) begin : GEN_LOGIC
            and #(50) GAND(and_ab[i], A[i], B[i]);
            or  #(50) GOR (or_ab[i],  A[i], B[i]);
            xor #(50) GXR (xor_ab[i], A[i], B[i]);
            // pass-through B
            assign b_pass[i] = B[i];
        end
    endgenerate

    // --- adder path ---
    logic [64:0] c;
    logic [63:0] b_mod, sum;
    assign c[0] = sel_sub; // cin=1 for SUB, 0 for ADD

    generate
        for (i=0; i<64; i++) begin : GEN_ADD
            xor #(50) XB(b_mod[i], B[i], invert_b); // B ^ invert_b
            adder1bit FA(.sum(sum[i]), .cout(c[i+1]), .a(A[i]), .b(b_mod[i]), .cin(c[i]));
        end
    endgenerate

    // --- structural MUX of 5 inputs (one of the sel is high at a time) ---
    logic [63:0] b_sel, and_sel, or_sel, xor_sel, sum_sel;
    logic [63:0] or1, or2, or3;

    generate
        for (i=0; i<64; i++) begin : GEN_RES
            and #(50) SB(b_sel[i],   b_pass[i], sel_b);
            and #(50) SA(and_sel[i], and_ab[i], sel_and);
            and #(50) SO(or_sel[i],  or_ab[i],  sel_or);
            and #(50) SX(xor_sel[i], xor_ab[i], sel_xor);
            and #(50) SS(sum_sel[i], sum[i],    sel_sum);

            or  #(50) O1(or1[i], b_sel[i], and_sel[i]);     
            or  #(50) O2(or2[i], or_sel[i], xor_sel[i]);   
            or  #(50) O3(or3[i], or1[i],   or2[i]);         
            or  #(50) OR(Result[i], or3[i], sum_sel[i]);    
        end
    endgenerate

    // --- flags ---
    // CarryOut only meaningful for ADD/SUB : and gate it with sum
    logic carry_raw;
    assign carry_raw = c[64];
    and #(50) COG(CarryOut, carry_raw, sel_sum);

    // Overflow = XOR of carries into/out of MSB, only for ADD/SUB
    logic ovf_core;
    xor #(50) OVX(ovf_core, c[63], c[64]);
    and #(50) OVG(Overflow, ovf_core, sel_sum);

    // Negative = MSB of result
    assign Negative = Result[63];

    // Zero = NOR of all result bits 
    logic any1;
    or_reduce64 RED(any1, Result);
    not #(50) ZN(Zero, any1);
endmodule
