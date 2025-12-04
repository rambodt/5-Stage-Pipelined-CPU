// EE469 Lab 3 — Single-cycle CPU (datapath)
// control comes from controller.sv
`timescale 1ns / 10ps

    module
    cpu(input logic clk, input logic reset);

// ---------------- PC register ----------------
logic [63:0] PC_q, PC_d;
reg64_en PC_REG(.q(PC_q), .d(PC_d), .en(1'b1), .reset(reset), .clk(clk));

// ---------------- Instruction memory ----------------
logic [31:0] Instruction;
instructmem IMEM(.address(PC_q), .instruction(Instruction), .clk(clk));

// ---------------- Field extracts ----------------
logic [4:0] Rd, Rn, Rm;
logic [5:0] Shamt;
logic [11:0] Imm12;
logic [18:0] CondAddr19;
logic [25:0] BrAddr26;
logic [8:0] DAddr9;

assign Rd = Instruction [4:0];
assign Rn = Instruction [9:5];
assign Rm = Instruction [20:16];
assign Shamt = Instruction [15:10];
assign Imm12 = Instruction [21:10];
assign CondAddr19 = Instruction [23:5];
assign BrAddr26 = Instruction [25:0];
assign DAddr9 = Instruction [20:12];

// ---------------- Immediates ----------------
logic [63:0] SE_Imm12, SE_DAddr9, SE_CondAddr, SE_BrAddr;
assign SE_Imm12 = {52'b0, Imm12};                                 // ze
assign SE_DAddr9 = {{55 {DAddr9[8]}}, DAddr9};                    // se
assign SE_CondAddr = {{45 {CondAddr19[18]}}, CondAddr19, 2'b00};  // se, <<2
assign SE_BrAddr = {{37 {BrAddr26[25]}}, BrAddr26, 2'b00};        // se, <<2

// ---------------- Control ----------------
logic [2:0] ALUOp;
logic RegWrite, Reg2Loc, ALUSrc, MemWrite, MemToReg;
logic is_branch, UncondBr, IsCBZ, IsLSR;
logic do_setflags;

// latched flags for B.cond
logic N_q, Z_q, C_q, V_q;

controller CTRL(.instr(Instruction), .N(N_q), .Z(Z_q), .C(C_q), .V(V_q), .alu_ctl(ALUOp),
                .do_setflags(do_setflags), .RegWrite(RegWrite), .Reg2Loc(Reg2Loc), .ALUSrc(ALUSrc),
                .MemWrite(MemWrite), .MemToReg(MemToReg), .is_branch(is_branch),
                .UncondBr(UncondBr), .IsCBZ(IsCBZ), .IsLSR(IsLSR));

// ---------------- Register file (Aw/Ab/Aa/Da/Db/Dw) ----------------
logic [4:0] Aw, Ab, Aa;
logic [63:0] Da, Db, Dw;
assign Aw = Rd;
// assign Aa = Rn; replaced with line 65 - 76

// Aa = (IsCBZ | is_branch) ? XZR : Rn   (keeps ALU A known on CBZ/B)
localparam logic [4:0] XZR_IDX = 5'd31;
logic aa_sel;
g_or2 OR_AA(aa_sel, IsCBZ, is_branch);

genvar ia;
generate for (ia = 0; ia < 5; ia++) begin : AA_MUX
    // mux2_1(y,a,b,s): s=0→a (Rn), s=1→b (XZR)
    mux2_1 M_AA(.y(Aa[ia]), .a(Rn[ia]), .b(XZR_IDX[ia]), .s(aa_sel));
end endgenerate

    // Ab = Reg2Loc ? Rd : Rm  (5× mux2_1)
    genvar bi;
generate for (bi = 0; bi < 5; bi++) begin : ABMUX
    // mux2_1(y,a,b,s) : y = s ? b : a
    mux2_1 M(.y(Ab[bi]), .a(Rm[bi]), .b(Rd[bi]), .s(Reg2Loc));
end endgenerate

    regfile RF(.ReadData1(Da), .ReadData2(Db), .WriteData(Dw), .ReadRegister1(Aa),
               .ReadRegister2(Ab), .WriteRegister(Aw), .RegWrite(RegWrite), .clk(clk));

// ---------------- ALU path ----------------
logic [63:0] ExtImm, ALU_B, ALU_Y;

// memOp = MemWrite OR MemToReg  (g_or2)
logic memOp;
g_or2 OR_MEMOP(memOp, MemWrite, MemToReg);

// ExtImm = memOp ? SE_DAddr9 : SE_Imm12
mux2_64 MUX_EXTIMM(.y(ExtImm), .a(SE_Imm12), .b(SE_DAddr9), .s(memOp));

// ALU_B = ALUSrc ? ExtImm : Db
mux2_64 MUX_ALUB(.y(ALU_B), .a(Db), .b(ExtImm), .s(ALUSrc));

// ALU proper
logic flagZ, flagN, flagV, flagC;
alu ALU(.A(Da), .B(ALU_B), .ALUControl(ALUOp), .Result(ALU_Y), .Zero(flagZ), .Overflow(flagV),
        .CarryOut(flagC), .Negative(flagN));

// Latch NZCV only when do_setflags=1
reg1_en FN(.q(N_q), .d(flagN), .en(do_setflags), .reset(reset), .clk(clk));
reg1_en FZ(.q(Z_q), .d(flagZ), .en(do_setflags), .reset(reset), .clk(clk));
reg1_en FC(.q(C_q), .d(flagC), .en(do_setflags), .reset(reset), .clk(clk));
reg1_en FV(.q(V_q), .d(flagV), .en(do_setflags), .reset(reset), .clk(clk));

// ---------------- Shifter (LSR) ----------------
logic [63:0] SHF_Y;
shifter SHIFT(.value(Da), .direction(1'b1), .distance(Shamt [5:0]), .result(SHF_Y));

// ---------------- Data memory ----------------
logic [63:0] DMEM_Dout;
datamem DMEM(.address(ALU_Y), .write_enable(MemWrite),
             .read_enable(MemToReg),  // LDUR when MemToReg=1
             .write_data(Db), .xfer_size(4'd8), .clk(clk), .read_data(DMEM_Dout));

// ---------------- Write-back muxes ----------------
logic [63:0] w_mem;
mux2_64 MUX_WB0(.y(w_mem), .a(ALU_Y), .b(DMEM_Dout), .s(MemToReg));
mux2_64 MUX_WB1(.y(Dw), .a(w_mem), .b(SHF_Y), .s(IsLSR));
/*
  // ---------------- PC + 4 ----------------
  logic [63:0] PC_plus4;
  alu ADD4(
    .A(PC_q), .B(64'd4), .ALUControl(3'b010),
    .Result(PC_plus4), .Zero(), .Overflow(), .CarryOut(), .Negative()
  );

  // ---------------- Branch target ----------------
  logic [63:0] BrOffset, PC_branch;
  // BrOffset = UncondBr ? SE_BrAddr : SE_CondAddr
  mux2_64 MUX_BROFF (.y(BrOffset), .a(SE_CondAddr), .b(SE_BrAddr), .s(UncondBr));

  // PC + offset
  alu ADD_BR(
    .A(PC_q), .B(BrOffset), .ALUControl(3'b010),
    .Result(PC_branch), .Zero(), .Overflow(), .CarryOut(), .Negative()
  );

  */

// ---------------- PC + 4 ----------------
logic pc4_cout, pc4_cinmsb;
logic [63:0] PC_plus4;
Big_adder64 ADD4(.sum(PC_plus4), .cout(pc4_cout), .cin_msb(pc4_cinmsb), .a(PC_q), .b(64'd4),
                 .cin(1'b0));

// ---------------- Branch target ----------------

logic [63:0] BrOffset, PC_branch;
// BrOffset = UncondBr ? SE_BrAddr : SE_CondAddr
mux2_64 MUX_BROFF(.y(BrOffset), .a(SE_CondAddr), .b(SE_BrAddr), .s(UncondBr));

logic pcbr_cout, pcbr_cinmsb;
Big_adder64 ADD_BR(.sum(PC_branch), .cout(pcbr_cout), .cin_msb(pcbr_cinmsb), .a(PC_q), .b(BrOffset),
                   .cin(1'b0));

// ---------------- Branch decision ----------------
// cond_lt = N ^ V
logic nN, nV, tNV, tVN, cond_lt;
g_inv INVN(nN, N_q);
g_inv INVV(nV, V_q);
g_and2 A1(tNV, N_q, nV);
g_and2 A2(tVN, nN, V_q);
g_or2 OX(cond_lt, tNV, tVN);

// db_is_zero = ~(|Db)
logic db_any, db_is_zero;
or_reduce64 OR_DB(.out_or(db_any), .din(Db));
g_inv INVZ(db_is_zero, db_any);

// BrTaken = (is_branch & UncondBr) OR (is_branch & ~UncondBr & cond_lt) OR (IsCBZ & db_is_zero)
logic nUncondBr, t_uncond, t_cond_pre, t_cond, t_cbz, t_or1;
g_inv NUC(nUncondBr, UncondBr);
g_and2 A_UNC(t_uncond, is_branch, UncondBr);
g_and2 A_PRE(t_cond_pre, is_branch, nUncondBr);
g_and2 A_COND(t_cond, t_cond_pre, cond_lt);
g_and2 A_CBZ(t_cbz, IsCBZ, db_is_zero);
g_or2 O1(t_or1, t_uncond, t_cond);
g_or2 O2(BrTaken, t_or1, t_cbz);

// ---------------- Next PC ----------------
mux2_64 MUX_NPC(.y(PC_d), .a(PC_plus4), .b(PC_branch), .s(BrTaken));

endmodule
