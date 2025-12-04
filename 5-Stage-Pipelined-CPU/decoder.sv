`timescale 1ps/1ps

module dec2to4(output logic [3:0] y, input logic en, input logic [1:0] a);
  logic na1,na0; 
  g_inv I1(na1,a[1]); 
  g_inv I0(na0,a[0]);
  
  g_and3 A0(y[0], en, na1, na0);
  g_and3 A1(y[1], en, na1, a[0]);
  g_and3 A2(y[2], en, a[1], na0);
  g_and3 A3(y[3], en, a[1], a[0]);
endmodule

module dec3to8(output logic [7:0] y, input logic en, input logic [2:0] a);
  logic na2,na1,na0;
  
  g_inv I2(na2,a[2]); 
  g_inv I1(na1,a[1]); 
  g_inv I0(na0,a[0]);
  
  g_and4 A0(y[0], en, na2,na1,na0);
  g_and4 A1(y[1], en, na2,na1,a[0] );
  g_and4 A2(y[2], en, na2,a[1] ,na0);
  g_and4 A3(y[3], en, na2,a[1] ,a[0] );
  g_and4 A4(y[4], en, a[2] ,na1,na0);
  g_and4 A5(y[5], en, a[2] ,na1,a[0] );
  g_and4 A6(y[6], en, a[2] ,a[1] ,na0);
  g_and4 A7(y[7], en, a[2] ,a[1] ,a[0] );
endmodule

module dec5to32(output logic [31:0] y, input logic en, input logic [4:0] a);

  logic [3:0] d_hi; logic [7:0] d_lo; 
  
  genvar i,j;
  
  dec2to4 DHI(d_hi, en,   a[4:3]);
  dec3to8 DLO(d_lo, 1'b1, a[2:0]);
  
	generate
	  for (i=0; i<4; i++) begin: HI
		 for (j=0; j<8; j++) begin: LO
			g_and2 A( y[i*8 + j], d_hi[i], d_lo[j] );
		 end
	  end
	endgenerate
endmodule
