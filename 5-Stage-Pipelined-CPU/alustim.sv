// Test bench for ALU
`timescale 1ns/10ps

// Meaning of signals in and out of the ALU:

// Flags:
// negative: whether the result output is negative if interpreted as 2's comp.
// zero: whether the result output was a 64-bit zero.
// overflow: on an add or subtract, whether the computation overflowed if the inputs are interpreted as 2's comp.
// carry_out: on an add or subtract, whether the computation produced a carry-out.

// cntrl			Operation						Notes:
// 000:			result = B						value of overflow and carry_out unimportant
// 010:			result = A + B
// 011:			result = A - B
// 100:			result = bitwise A & B		value of overflow and carry_out unimportant
// 101:			result = bitwise A | B		value of overflow and carry_out unimportant
// 110:			result = bitwise A XOR B	value of overflow and carry_out unimportant

module alustim();

	parameter delay = 100000;

	logic		[63:0]	A, B;
	logic		[2:0]		cntrl;
	logic		[63:0]	result;
	logic					negative, zero, overflow, carry_out ;

	parameter ALU_PASS_B=3'b000, ALU_ADD=3'b010, ALU_SUBTRACT=3'b011, ALU_AND=3'b100, ALU_OR=3'b101, ALU_XOR=3'b110;
	

	alu dut (.A, .B, .ALUControl(cntrl), .Result(result), .Negative(negative),
				.Zero(zero), .Overflow(overflow), .CarryOut(carry_out));

	// Force %t's to print in a nice format.
	initial $timeformat(-9, 2, " ns", 10);

	integer i;
	logic [63:0] test_val;
	initial begin
	
		$display("%t testing PASS_A operations", $time);
		cntrl = ALU_PASS_B;
		for (i=0; i<100; i++) begin
			A = $random(); B = $random();
			#(delay);
			assert(result == B && negative == B[63] && zero == (B == '0));
		end
		
		$display("%t testing addition", $time);
		cntrl = ALU_ADD;
		A = 64'h0000000000000001; B = 64'h0000000000000001;
		#(delay);
		assert(result == 64'h0000000000000002 && carry_out == 0 && overflow == 0 && negative == 0 && zero == 0);
		    // ----------- extra test -----------

    // ---- ADD edge cases ----
    cntrl = ALU_ADD;  A = 64'h7FFF_FFFF_FFFF_FFFF; B = 64'h1;  #(delay);
    assert(result == 64'h8000_0000_0000_0000 && carry_out == 0 && overflow == 1 && negative == 1 && zero == 0);

    cntrl = ALU_ADD;  A = 64'hFFFF_FFFF_FFFF_FFFF; B = 64'h1;  #(delay);
    assert(result == 64'h0000_0000_0000_0000 && carry_out == 1 && overflow == 0 && negative == 0 && zero == 1);

    // Random ADDs 
    begin : ADD_RANDOMS
      int k2;
      logic [64:0] w2; logic [63:0] r2; bit c2, v2, n2, z2;
      for (k2=0; k2<20; k2++) begin
        A = { $random, $random }; B = { $random, $random }; cntrl = ALU_ADD; #(delay);
        w2 = {1'b0,A} + {1'b0,B}; r2 = w2[63:0]; c2 = w2[64];
        v2 = (~(A[63]^B[63])) & (A[63]^r2[63]); n2 = r2[63]; z2 = (r2=='0);
        assert(result==r2 && carry_out==c2 && overflow==v2 && negative==n2 && zero==z2);
      end
    end

    // ---- SUB edge cases ----
    cntrl = ALU_SUBTRACT; A = 64'h0; B = 64'h1; #(delay);
    assert(result == 64'hFFFF_FFFF_FFFF_FFFF && carry_out == 0 && overflow == 0 && negative == 1 && zero == 0);

    cntrl = ALU_SUBTRACT; A = 64'h8000_0000_0000_0000; B = 64'h1; #(delay);
    assert(result == 64'h7FFF_FFFF_FFFF_FFFF && carry_out == 1 && overflow == 1 && negative == 0 && zero == 0);

    // Random SUBs 
    begin : SUB_RANDOMS
      int k3;
      logic [64:0] w3; logic [63:0] r3; bit c3, v3, n3, z3;
      for (k3=0; k3<20; k3++) begin
        A = { $random, $random }; B = { $random, $random }; cntrl = ALU_SUBTRACT; #(delay);
        w3 = {1'b0,A} + {1'b0,~B} + 65'd1; r3 = w3[63:0]; c3 = w3[64];
        v3 = (A[63]^B[63]) & (A[63]^r3[63]); n3 = r3[63]; z3 = (r3=='0);
        assert(result==r3 && carry_out==c3 && overflow==v3 && negative==n3 && zero==z3);
      end
    end

    // AND
	cntrl = ALU_AND; A = 64'hFFFF_FFFF_FFFF_FFFF; B = 64'h0F0F_0F0F_0F0F_0F0F; #(delay);
	assert(result==(A&B)	 && negative==(((A&B)>>63) & 1'b1) && zero==((A&B)=='0));

	// OR
	cntrl = ALU_OR;  A = 64'hF000_F000_F000_F000; B = 64'h0F00_0F00_0F00_0F00; #(delay);
	assert(result==(A|B) && negative==(((A|B)>>63) & 1'b1) && zero==((A|B)=='0));

	// XOR
	cntrl = ALU_XOR; A = 64'hAAAA_AAAA_AAAA_AAAA; B = 64'h5555_5555_5555_5555; #(delay);
	assert(result==(A^B) && negative==(((A^B)>>63) & 1'b1) && zero==((A^B)=='0));


    // Random logic ops
    begin : LOGIC_RANDOMS
      int k4;
      for (k4=0; k4<20; k4++) begin
        A = { $random, $random }; B = { $random, $random };

         cntrl = ALU_AND; #(delay);
			assert(result==(A&B) && negative==(((A&B)>>63) & 1'b1) && zero==((A&B)=='0));

			cntrl = ALU_OR;  #(delay);
			assert(result==(A|B) && negative==(((A|B)>>63) & 1'b1) && zero==((A|B)=='0));

			cntrl = ALU_XOR; #(delay);
			assert(result==(A^B) && negative==(((A^B)>>63) & 1'b1) && zero==((A^B)=='0));

      end
    end

    // ---- PASS_B a couple more ----
    cntrl = ALU_PASS_B; A = 64'hDEAD_BEEF_CAFE_F00D; B = 64'h0; #(delay);
    assert(result==B && zero==1 && negative==0);

    cntrl = ALU_PASS_B; A = 64'h0; B = 64'h8000_0000_0000_0000; #(delay);
    assert(result==B && zero==0 && negative==1);

	end
	
	
endmodule
