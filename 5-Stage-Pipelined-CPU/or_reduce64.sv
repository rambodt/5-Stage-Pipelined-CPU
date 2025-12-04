`timescale 1ps / 1ps

    // or_reduce64.sv  (2 input OR tree)
    module
    or_reduce64(output logic out_or, input logic [63:0] din);
logic [31:0] l1;
logic [15:0] l2;
logic [7:0] l3;
logic [3:0] l4;
logic [1:0] l5;

genvar i;

// Level 1: 64 -> 32
generate for (i = 0; i < 32; i = i + 1) begin : L1 
or #(50)OR1(l1[i], din[2 * i], din[2 * i + 1]);
end endgenerate

    // Level 2: 32 -> 16
    generate for (i = 0; i < 16; i = i + 1) begin : L2 
	 or #(50)OR2(l2[i], l1[2 * i], l1[2 * i + 1]);
end endgenerate

    // Level 3: 16 -> 8
    generate for (i = 0; i < 8; i = i + 1) begin : L3 
	 or #(50)OR3(l3[i], l2[2 * i], l2[2 * i + 1]);
end endgenerate

    // Level 4: 8 -> 4
    generate for (i = 0; i < 4; i = i + 1) begin : L4 
	 or #(50)OR4(l4[i], l3[2 * i], l3[2 * i + 1]);
end endgenerate

    // Level 5: 4 -> 2
    generate for (i = 0; i < 2; i = i + 1) begin : L5 
	 or #(50)OR5(l5[i], l4[2 * i], l4[2 * i + 1]);
end endgenerate

    // leve 6: 2 -> 1
    or #(50)OR6(out_or, l5[0], l5[1]);
endmodule
