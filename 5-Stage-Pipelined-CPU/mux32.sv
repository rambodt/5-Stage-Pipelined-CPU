`timescale 1ps/1ps

module mux32_1bit(output logic y, input logic [31:0] d, input logic [4:0] s);

  logic [15:0] L0; genvar i;
  generate for (i=0;i<16;i++) begin: G0
    mux2_1 M(L0[i], d[2*i], d[2*i+1], s[0]);
  end endgenerate
  
  logic [7:0] L1; 
  generate for (i=0;i<8;i++) begin: G1
    mux2_1 M(L1[i], L0[2*i], L0[2*i+1], s[1]);
  end endgenerate
  
  logic [3:0] L2; 
  generate for (i=0;i<4;i++) begin: G2
    mux2_1 M(L2[i], L1[2*i], L1[2*i+1], s[2]);
  end endgenerate
  
  logic [1:0] L3; 
  generate for (i=0;i<2;i++) begin: G3
    mux2_1 M(L3[i], L2[2*i], L2[2*i+1], s[3]);
  end endgenerate
  
  mux2_1 M4(y, L3[0], L3[1], s[4]);
endmodule

module mux32_64(output logic [63:0] y,
                input  logic [31:0][63:0] d,
                input  logic [4:0]        s);
  genvar n, k;
  generate
    for (n=0; n<64; n++) begin: B
      logic [31:0] slice;
      for (k=0; k<32; k++) begin: K
        assign slice[k] = d[k][n];
      end
      mux32_1bit M(y[n], slice, s);
    end
  endgenerate
endmodule
