//`timescale 1ps/1ps
//
//module g_inv (output logic y, input logic a);       
//	assign #50 y = ~a; endmodule
//	
//module g_and2 (output logic y, input logic a,b);     
//	assign #50 y =  a & b; endmodule
//	
//module g_and3 (output logic y, input logic a,b,c);   
//	assign #50 y =  a & b & c; endmodule
//	
//module g_and4 (output logic y, input logic a,b,c,d); 
//	assign #50 y =  a & b & c & d; endmodule
//	
//module g_or2 (output logic y, input logic a,b);     
//	assign #50 y =  a | b; endmodule
//	
//module g_or3 (output logic y, input logic a,b,c);   
//	assign #50 y =  a | b | c; endmodule
//	
//module g_or4 (output logic y, input logic a,b,c,d); 
//	assign #50 y =  a | b | c | d; endmodule

`timescale 1ps/1ps

module g_inv  (output wire y, input wire a);
  not  #(50) U_INV (y, a);
endmodule

module g_and2 (output wire y, input wire a, b);
  and  #(50) U_AND2 (y, a, b);
endmodule

module g_and3 (output wire y, input wire a, b, c);
  and  #(50) U_AND3 (y, a, b, c);
endmodule

module g_and4 (output wire y, input wire a, b, c, d);
  and  #(50) U_AND4 (y, a, b, c, d);
endmodule

module g_or2  (output wire y, input wire a, b);
  or   #(50) U_OR2  (y, a, b);
endmodule

module g_or3  (output wire y, input wire a, b, c);
  or   #(50) U_OR3  (y, a, b, c);
endmodule

module g_or4  (output wire y, input wire a, b, c, d);
  or   #(50) U_OR4  (y, a, b, c, d);
endmodule
