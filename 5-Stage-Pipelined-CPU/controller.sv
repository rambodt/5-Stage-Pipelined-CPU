// EE469 Lab 3 — Controller
`timescale 1ns / 10ps

    module
    controller(input logic [31:0] instr, input logic N, Z, C, V,  // flags (for B.cond in datapath)
               output logic [2:0] alu_ctl, output logic do_setflags, output logic RegWrite,
               output logic Reg2Loc, output logic ALUSrc, output logic MemWrite,
               output logic MemToReg, output logic is_branch, output logic UncondBr,
               output logic IsCBZ, output logic IsLSR);

// Opcode slices
logic [10:0] op11;
assign op11 = instr [31:21];
logic [9:0] op10;
assign op10 = instr [31:22];
logic [7:0] op8;
assign op8 = instr [31:24];
logic [5:0] op6;
assign op6 = instr [31:26];
logic [3:0] cond;
assign cond = instr [3:0];

// decodes
logic dec_ADDI;
assign dec_ADDI = (op10 == 10'b1001000100);  // ADDI
logic dec_ADDS;
assign dec_ADDS = (op11 == 11'b10101011000);  // ADDS (reg)
logic dec_SUBS;
assign dec_SUBS = (op11 == 11'b11101011000);  // SUBS (reg)
logic dec_AND;
assign dec_AND = (op11 == 11'b10001010000);  // AND  (reg)
logic dec_EOR;
assign dec_EOR = (op11 == 11'b11001010000);  // EOR  (reg)
logic dec_LSR;
assign dec_LSR = (op11 == 11'b11010011010);  // LSR (imm)
logic dec_LDUR;
assign dec_LDUR = (op11 == 11'b11111000010);  // LDUR
logic dec_STUR;
assign dec_STUR = (op11 == 11'b11111000000);  // STUR
logic dec_B;
assign dec_B = (op6 == 6'b000101);  // B (uncond)
logic dec_BLT;
assign dec_BLT = (op8 == 8'b01010100) && (cond == 4'b1011);  // B.LT
logic dec_CBZ;
assign dec_CBZ = (op8 == 8'b10110100);  // CBZ

always_comb begin
    // -------- DEFAULTS (for no x) --------
    alu_ctl = 3'b010;  // ADD by default
do_setflags = 1'b0;
RegWrite = 1'b0;
Reg2Loc = 1'b0;  // Ab = Rm unless store/CBZ
ALUSrc = 1'b0;   // B <= Db unless immediate
MemWrite = 1'b0;
MemToReg = 1'b0;
is_branch = 1'b0;
UncondBr = 1'b0;
IsCBZ = 1'b0;
IsLSR = 1'b0;

// -------- DECODE ACTIONS --------
if (dec_ADDI) begin RegWrite = 1'b1;
ALUSrc = 1'b1;     // immediate on ALU_B
alu_ctl = 3'b010;  // add
end else if (dec_ADDS) begin RegWrite = 1'b1;
do_setflags = 1'b1;
ALUSrc = 1'b0;  // register
alu_ctl = 3'b010;
end else if (dec_SUBS) begin RegWrite = 1'b1;
do_setflags = 1'b1;
ALUSrc = 1'b0;
alu_ctl = 3'b011;  // sub
end else if (dec_AND) begin RegWrite = 1'b1;
ALUSrc = 1'b0;
alu_ctl = 3'b100;
end else if (dec_EOR) begin RegWrite = 1'b1;
ALUSrc = 1'b0;
alu_ctl = 3'b110;
end else if (dec_LSR) begin RegWrite = 1'b1;
IsLSR = 1'b1;  // write shifter result
end else if (dec_LDUR) begin RegWrite = 1'b1;
ALUSrc = 1'b1;     // imm9
MemToReg = 1'b1;   // WB from memory
alu_ctl = 3'b010;  // addr = Rn + imm9
end else if (dec_STUR) begin RegWrite = 1'b0;
ALUSrc = 1'b1;  // imm9
MemWrite = 1'b1;
Reg2Loc = 1'b1;  // Ab = Rd for store data
alu_ctl = 3'b010;
end else if (dec_B) begin is_branch = 1'b1;
UncondBr = 1'b1;                               // imm26 path
end else if (dec_BLT) begin is_branch = 1'b1;  // conditional; datapath tests N^V
UncondBr = 1'b0;                               // imm19 path
end else if (dec_CBZ) begin IsCBZ = 1'b1;      // datapath compares Db with zero
Reg2Loc = 1'b1;                                // Ab = Rd so Db is the Rd value
end end

    endmodule
