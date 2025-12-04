// EE469 Lab 4 — 5-stage Pipelined CPU (datapath)
// Control comes from controller.sv
`timescale 1ns / 10ps

    module
    pipecpu(input logic clk, input logic reset);

// ==============================================================
// Global condition flags (NZCV) — latched from EX stage
// ==============================================================
logic N_q, Z_q, C_q, V_q;

// ==============================================================
// IF STAGE: PC and Instruction Fetch
// ==============================================================
logic [63:0] pc_q_if, pc_next, pc_plus4_if;
logic [31:0] instr_if;

// PC register
reg64_en PC_IF(.q(pc_q_if), .d(pc_next), .en(1'b1), .reset(reset), .clk(clk));

// Compatibility aliases for cpustim
logic [63:0] PC_q;
logic [31:0] Instruction;
assign PC_q = pc_q_if;
assign Instruction = instr_if;

// PC + 4 using ALU
alu ADD_PC4(.A(pc_q_if), .B(64'd4), .ALUControl(3'b010), .Result(pc_plus4_if), .Zero(), .Overflow(),
            .CarryOut(), .Negative());

// Instruction memory
instructmem IMEM(.address(pc_q_if), .instruction(instr_if), .clk(clk));

// ==============================================================
// IF/ID PIPELINE REGISTER
// ==============================================================
logic [63:0] ifid_pc_q;
logic [31:0] ifid_instr_q;
logic ex_branch_taken;

// NOP instruction (ADDI X31, X31, #0 = 0x910003FF)
logic [31:0] ifid_instr_next;
logic [31:0] nop_instr;
assign nop_instr = 32'h910003FF;

// IF/ID PC
reg64_en IFID_PC(.q(ifid_pc_q), .d(pc_q_if), .en(1'b1), .reset(reset), .clk(clk));

// Flush the instruction in IF when branch is taken (delay slot is in ID)
mux2_32 IFID_FLUSH_MUX(.out(ifid_instr_next), .i0(instr_if), .i1(nop_instr), .sel(ex_branch_taken));
regN_en #(.N(32))IFID_IR(.q(ifid_instr_q), .d(ifid_instr_next), .en(1'b1), .reset(reset),
                         .clk(clk));

// ==============================================================
// ID STAGE: Decode, regfile read, immediates, control
// ==============================================================
logic [63:0] pc_id;
logic [31:0] instr_id;

assign pc_id = ifid_pc_q;
assign instr_id = ifid_instr_q;

// Field extracts
logic [4:0] Rd_id, Rn_id, Rm_id;
logic [5:0] Shamt_id;
logic [11:0] Imm12_id;
logic [18:0] CondAddr19_id;
logic [25:0] BrAddr26_id;
logic [8:0] DAddr9_id;

assign Rd_id = instr_id [4:0];
assign Rn_id = instr_id [9:5];
assign Rm_id = instr_id [20:16];
assign Shamt_id = instr_id [15:10];
assign Imm12_id = instr_id [21:10];
assign CondAddr19_id = instr_id [23:5];
assign BrAddr26_id = instr_id [25:0];
assign DAddr9_id = instr_id [20:12];

// Immediates (64-bit)
logic [63:0] SE_Imm12_id, SE_DAddr9_id, SE_CondAddr_id, SE_BrAddr_id;

assign SE_Imm12_id = {52'b0, Imm12_id};                                    // zero-extend
assign SE_DAddr9_id = {{55 {DAddr9_id[8]}}, DAddr9_id};                    // sign-extend
assign SE_CondAddr_id = {{45 {CondAddr19_id[18]}}, CondAddr19_id, 2'b00};  // sign-extend, <<2
assign SE_BrAddr_id = {{37 {BrAddr26_id[25]}}, BrAddr26_id, 2'b00};        // sign-extend, <<2

// Control (from controller.sv)
logic [2:0] ALUOp_id;
logic do_setflags_id;
logic RegWrite_id, Reg2Loc_id, ALUSrc_id;
logic MemWrite_id, MemToReg_id;
logic is_branch_id, UncondBr_id, IsCBZ_id, IsLSR_id;

controller CTRL_ID(.instr(instr_id), .N(N_q), .Z(Z_q), .C(C_q), .V(V_q), .alu_ctl(ALUOp_id),
                   .do_setflags(do_setflags_id), .RegWrite(RegWrite_id), .Reg2Loc(Reg2Loc_id),
                   .ALUSrc(ALUSrc_id), .MemWrite(MemWrite_id), .MemToReg(MemToReg_id),
                   .is_branch(is_branch_id), .UncondBr(UncondBr_id), .IsCBZ(IsCBZ_id),
                   .IsLSR(IsLSR_id));

// Register file and address muxes
logic [63:0] wb_write_data;
logic [4:0] wb_rd_addr;
logic wb_reg_write;

localparam logic [4:0] XZR_IDX = 5'd31;
logic [4:0] Aa_id, Ab_id;
logic aa_sel_id;

// Aa = (IsCBZ | is_branch) ? XZR : Rn
g_or2 OR_AA_ID(aa_sel_id, IsCBZ_id, is_branch_id);

genvar ia;
generate for (ia = 0; ia < 5; ia++) begin :
    GEN_AA_ID mux2_1 M_AA_ID(.y(Aa_id[ia]), .a(Rn_id[ia]), .b(XZR_IDX[ia]), .s(aa_sel_id));
end endgenerate

    // Ab = Reg2Loc ? Rd : Rm
    genvar ib;
generate for (ib = 0; ib < 5; ib++) begin :
    GEN_AB_ID mux2_1 M_AB_ID(.y(Ab_id[ib]), .a(Rm_id[ib]), .b(Rd_id[ib]), .s(Reg2Loc_id));
end endgenerate

// Register file
logic [63:0] Da_id,
    Db_id;
regfile RF(.ReadData1(Da_id), .ReadData2(Db_id), .WriteData(wb_write_data), .ReadRegister1(Aa_id),
           .ReadRegister2(Ab_id), .WriteRegister(wb_rd_addr), .RegWrite(wb_reg_write), .clk(clk));

// ---------------- ID stage bypass (WB to ID) ----------------
logic idA_sel_wb, idB_sel_wb;
logic [63:0] idA_val, idB_val;

// Compare WB dest with Aa_id
logic [4:0] xnor_a;
logic and_a_4, and_a_3, and_a_2, and_a_1, eq_a;

genvar xa;
generate for (xa = 0; xa < 5; xa++) begin :
    CMP_A xnor #(50)XNOR_A(xnor_a[xa], wb_rd_addr[xa], Aa_id[xa]);
end endgenerate

    and #(50)AND_A4(and_a_4, xnor_a[4], xnor_a[3]);
and#(50)AND_A3(and_a_3, xnor_a[2], xnor_a[1]);
and#(50)AND_A2(and_a_2, and_a_4, and_a_3);
and#(50)AND_A1(eq_a, and_a_2, xnor_a[0]);

// Check Aa_id != 31
logic [4:0] xnor_a_31;
logic and_a31_4, and_a31_3, and_a31_2, eq_a_31, not_eq_a_31;

genvar ya;
generate for (ya = 0; ya < 5; ya++) begin :
    CMP_A31 xnor #(50)XNOR_A31(xnor_a_31[ya], Aa_id[ya], XZR_IDX[ya]);
end endgenerate

    and #(50)AND_A31_4(and_a31_4, xnor_a_31[4], xnor_a_31[3]);
and#(50)AND_A31_3(and_a31_3, xnor_a_31[2], xnor_a_31[1]);
and#(50)AND_A31_2(and_a31_2, and_a31_4, and_a31_3);
and#(50)AND_A31_1(eq_a_31, and_a31_2, xnor_a_31[0]);
not #(50)NOT_A31(not_eq_a_31, eq_a_31);

and#(50)AND_BYPA(idA_sel_wb, wb_reg_write, eq_a, not_eq_a_31);

// Compare WB dest with Ab_id
logic [4:0] xnor_b;
logic and_b_4, and_b_3, and_b_2, and_b_1, eq_b;

genvar xb;
generate for (xb = 0; xb < 5; xb++) begin :
    CMP_B xnor #(50)XNOR_B(xnor_b[xb], wb_rd_addr[xb], Ab_id[xb]);
end endgenerate

    and #(50)AND_B4(and_b_4, xnor_b[4], xnor_b[3]);
and#(50)AND_B3(and_b_3, xnor_b[2], xnor_b[1]);
and#(50)AND_B2(and_b_2, and_b_4, and_b_3);
and#(50)AND_B1(eq_b, and_b_2, xnor_b[0]);

// Check Ab_id != 31
logic [4:0] xnor_b_31;
logic and_b31_4, and_b31_3, and_b31_2, eq_b_31, not_eq_b_31;

genvar yb;
generate for (yb = 0; yb < 5; yb++) begin :
    CMP_B31 xnor #(50)XNOR_B31(xnor_b_31[yb], Ab_id[yb], XZR_IDX[yb]);
end endgenerate

    and #(50)AND_B31_4(and_b31_4, xnor_b_31[4], xnor_b_31[3]);
and#(50)AND_B31_3(and_b31_3, xnor_b_31[2], xnor_b_31[1]);
and#(50)AND_B31_2(and_b31_2, and_b31_4, and_b31_3);
and#(50)AND_B31_1(eq_b_31, and_b31_2, xnor_b_31[0]);
not #(50)NOT_B31(not_eq_b_31, eq_b_31);

and#(50)AND_BYPB(idB_sel_wb, wb_reg_write, eq_b, not_eq_b_31);

// WB-to-ID bypass muxes
mux2_64 IDA_MUX(.y(idA_val), .a(Da_id), .b(wb_write_data), .s(idA_sel_wb));
mux2_64 IDB_MUX(.y(idB_val), .a(Db_id), .b(wb_write_data), .s(idB_sel_wb));

// ==============================================================
// ID/EX PIPELINE REGISTER
// ==============================================================
// Data signals
logic [63:0] idex_pc_q;
logic [63:0] idex_rs1_data_q, idex_rs2_data_q;
logic [63:0] idex_imm12_q, idex_daddr9_q, idex_condaddr_q, idex_braddr_q;
logic [5:0] idex_shamt_q;
logic [4:0] idex_rs1_addr_q, idex_rs2_addr_q, idex_rd_addr_q;

// Control signals
logic [2:0] idex_aluop_q;
logic idex_do_setflags_q;
logic idex_RegWrite_q, idex_Reg2Loc_q, idex_ALUSrc_q;
logic idex_MemWrite_q, idex_MemToReg_q;
logic idex_is_branch_q, idex_UncondBr_q, idex_IsCBZ_q, idex_IsLSR_q;

localparam logic ID_EX_EN = 1'b1;

// Data regs
reg64_en IDEX_PC(.q(idex_pc_q), .d(pc_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg64_en IDEX_RS1(.q(idex_rs1_data_q), .d(idA_val), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg64_en IDEX_RS2(.q(idex_rs2_data_q), .d(idB_val), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg64_en IDEX_IMM12(.q(idex_imm12_q), .d(SE_Imm12_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg64_en IDEX_DADDR9(.q(idex_daddr9_q), .d(SE_DAddr9_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg64_en IDEX_COND19(.q(idex_condaddr_q), .d(SE_CondAddr_id), .en(ID_EX_EN), .reset(reset),
                     .clk(clk));
reg64_en IDEX_BR26(.q(idex_braddr_q), .d(SE_BrAddr_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
regN_en #(.N(6))IDEX_SHAMT(.q(idex_shamt_q), .d(Shamt_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
regN_en #(.N(5))IDEX_RS1A(.q(idex_rs1_addr_q), .d(Aa_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
regN_en #(.N(5))IDEX_RS2A(.q(idex_rs2_addr_q), .d(Ab_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
regN_en #(.N(5))IDEX_RDA(.q(idex_rd_addr_q), .d(Rd_id), .en(ID_EX_EN), .reset(reset), .clk(clk));

// Control regs
regN_en #(.N(3))IDEX_ALUOP(.q(idex_aluop_q), .d(ALUOp_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_SETFL(.q(idex_do_setflags_q), .d(do_setflags_id), .en(ID_EX_EN), .reset(reset),
                   .clk(clk));
reg1_en IDEX_RW(.q(idex_RegWrite_q), .d(RegWrite_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_R2L(.q(idex_Reg2Loc_q), .d(Reg2Loc_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_AS(.q(idex_ALUSrc_q), .d(ALUSrc_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_MW(.q(idex_MemWrite_q), .d(MemWrite_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_MTR(.q(idex_MemToReg_q), .d(MemToReg_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_BR(.q(idex_is_branch_q), .d(is_branch_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_UBR(.q(idex_UncondBr_q), .d(UncondBr_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_CBZ(.q(idex_IsCBZ_q), .d(IsCBZ_id), .en(ID_EX_EN), .reset(reset), .clk(clk));
reg1_en IDEX_LSR(.q(idex_IsLSR_q), .d(IsLSR_id), .en(ID_EX_EN), .reset(reset), .clk(clk));

// ==============================================================
// EX STAGE: forwarding, ALU, shifter, branch
// ==============================================================
// Forwarding control
logic [1:0] fwdA_sel, fwdB_sel;

// EX/MEM + MEM/WB signals needed for forwarding
logic [4:0] exmem_rd_addr_q, memwb_rd_addr_q;
logic exmem_RegWrite_q, memwb_RegWrite_q;
logic exmem_MemToReg_q;  // acts as memread flag

forwarding_unit FWD(.idex_rs1(idex_rs1_addr_q), .idex_rs2(idex_rs2_addr_q),
                    .exmem_rd(exmem_rd_addr_q), .memwb_rd(memwb_rd_addr_q),
                    .exmem_regwrite(exmem_RegWrite_q), .memwb_regwrite(memwb_RegWrite_q),
                    .exmem_memread(exmem_MemToReg_q), .forwardA(fwdA_sel), .forwardB(fwdB_sel));

// Values forwarded from later stages
logic [63:0] exmem_alu_y_q;
logic [63:0] memwb_alu_y_q;
logic [63:0] memwb_mem_y_q;
logic [63:0] memwb_shf_y_q;
logic memwb_MemToReg_q;
logic memwb_IsLSR_q;
logic exmem_IsLSR_q;
logic [63:0] exmem_shf_y_q;

// Final WB data (to regfile and forwarding)
logic [63:0] wb_from_mem_or_alu;
mux2_64 WB_MEMMUX(.y(wb_from_mem_or_alu), .a(memwb_alu_y_q), .b(memwb_mem_y_q),
                  .s(memwb_MemToReg_q));
mux2_64 WB_SHIFTMUX(.y(wb_write_data), .a(wb_from_mem_or_alu), .b(memwb_shf_y_q),
                    .s(memwb_IsLSR_q));

// EX stage operands with forwarding
logic [63:0] ex_A_src0, ex_A_src;
logic [63:0] ex_B_src0, ex_B_src;

// Choose correct EX/MEM forwarding value based on IsLSR
logic [63:0] exmem_fwd_value;
mux2_64 EXMEM_FWD_MUX(.y(exmem_fwd_value), .a(exmem_alu_y_q), .b(exmem_shf_y_q), .s(exmem_IsLSR_q));

// Forwards: 00 = ID/EX, 01 = MEM/WB, 10 = EX/MEM
mux2_64 FWD_A0(.y(ex_A_src0), .a(idex_rs1_data_q), .b(wb_write_data), .s(fwdA_sel[0]));
mux2_64 FWD_A1(.y(ex_A_src), .a(ex_A_src0), .b(exmem_fwd_value), .s(fwdA_sel[1]));
mux2_64 FWD_B0(.y(ex_B_src0), .a(idex_rs2_data_q), .b(wb_write_data), .s(fwdB_sel[0]));
mux2_64 FWD_B1(.y(ex_B_src), .a(ex_B_src0), .b(exmem_fwd_value), .s(fwdB_sel[1]));

// ALU immediate selection
// memOp_ex = MemWrite OR MemToReg → use DAddr9 offset, otherwise Imm12
logic memOp_ex;
logic [63:0] ExtImm_ex;
logic [63:0] ALU_B_ex;

g_or2 OR_MEMOP_EX(memOp_ex, idex_MemWrite_q, idex_MemToReg_q);
mux2_64 MUX_EXTIMM_EX(.y(ExtImm_ex), .a(idex_imm12_q), .b(idex_daddr9_q), .s(memOp_ex));
mux2_64 MUX_ALUB_EX(.y(ALU_B_ex), .a(ex_B_src), .b(ExtImm_ex), .s(idex_ALUSrc_q));

// ALU
logic [63:0] ALU_Y_ex;
logic flagZ_ex, flagN_ex, flagV_ex, flagC_ex;

alu ALU_EX(.A(ex_A_src), .B(ALU_B_ex), .ALUControl(idex_aluop_q), .Result(ALU_Y_ex),
           .Zero(flagZ_ex), .Overflow(flagV_ex), .CarryOut(flagC_ex), .Negative(flagN_ex));

// Latch NZCV only when do_setflags is asserted
reg1_en FN(.q(N_q), .d(flagN_ex), .en(idex_do_setflags_q), .reset(reset), .clk(clk));
reg1_en FZ(.q(Z_q), .d(flagZ_ex), .en(idex_do_setflags_q), .reset(reset), .clk(clk));
reg1_en FC(.q(C_q), .d(flagC_ex), .en(idex_do_setflags_q), .reset(reset), .clk(clk));
reg1_en FV(.q(V_q), .d(flagV_ex), .en(idex_do_setflags_q), .reset(reset), .clk(clk));

// Shifter for LSR in EX stage
logic [63:0] SHF_Y_ex;
shifter SHIFT_EX(.value(ex_A_src), .direction(1'b1), .distance(idex_shamt_q),
                 .result(SHF_Y_ex));  // 1 = right shift

// Branch target computation
logic [63:0] BrOffset_ex, PC_branch_ex;
mux2_64 MUX_BROFF_EX(.y(BrOffset_ex), .a(idex_condaddr_q), .b(idex_braddr_q), .s(idex_UncondBr_q));

alu ADD_BR_EX(.A(idex_pc_q), .B(BrOffset_ex), .ALUControl(3'b010), .Result(PC_branch_ex), .Zero(),
              .Overflow(), .CarryOut(), .Negative());

// CBZ zero detection uses forwarded B source (ex_B_src)
logic db_any_ex, db_is_zero_ex;
or_reduce64 OR_DB_EX(.out_or(db_any_ex), .din(ex_B_src));
g_inv INVZ_EX(db_is_zero_ex, db_any_ex);

// cond_lt = N ^ V, using latched flags
logic nN_ex, nV_ex, tNV_ex, tVN_ex, cond_lt_ex;
g_inv INVN_EX(nN_ex, N_q);
g_inv INVV_EX(nV_ex, V_q);
g_and2 A1_EX(tNV_ex, N_q, nV_ex);
g_and2 A2_EX(tVN_ex, nN_ex, V_q);
g_or2 OX_EX(cond_lt_ex, tNV_ex, tVN_ex);

// BrTaken = (is_branch & UncondBr) OR (is_branch & ~UncondBr & cond_lt) OR (IsCBZ & db_is_zero)
logic nUncondBr_ex, t_uncond_ex, t_cond_pre_ex, t_cond_ex, t_cbz_ex, t_or1_ex;
g_inv NUC_EX(nUncondBr_ex, idex_UncondBr_q);
g_and2 A_UNC_EX(t_uncond_ex, idex_is_branch_q, idex_UncondBr_q);
g_and2 A_PRE_EX(t_cond_pre_ex, idex_is_branch_q, nUncondBr_ex);
g_and2 A_COND_EX(t_cond_ex, t_cond_pre_ex, cond_lt_ex);
g_and2 A_CBZ_EX(t_cbz_ex, idex_IsCBZ_q, db_is_zero_ex);
g_or2 O1_EX(t_or1_ex, t_uncond_ex, t_cond_ex);
g_or2 O2_EX(ex_branch_taken, t_or1_ex, t_cbz_ex);

// ==============================================================
// EX/MEM PIPELINE REGISTER
// ==============================================================
logic [63:0] exmem_pc_q;
logic [63:0] exmem_store_data_q;
logic exmem_MemWrite_q;

reg64_en EXMEM_PC(.q(exmem_pc_q), .d(idex_pc_q), .en(1'b1), .reset(reset), .clk(clk));
reg64_en EXMEM_ALU_Y(.q(exmem_alu_y_q), .d(ALU_Y_ex), .en(1'b1), .reset(reset), .clk(clk));
reg64_en EXMEM_STORE(.q(exmem_store_data_q), .d(ex_B_src), .en(1'b1), .reset(reset), .clk(clk));
reg64_en EXMEM_SHF(.q(exmem_shf_y_q), .d(SHF_Y_ex), .en(1'b1), .reset(reset), .clk(clk));
regN_en #(.N(5))EXMEM_RD(.q(exmem_rd_addr_q), .d(idex_rd_addr_q), .en(1'b1), .reset(reset),
                         .clk(clk));

reg1_en EXMEM_MW(.q(exmem_MemWrite_q), .d(idex_MemWrite_q), .en(1'b1), .reset(reset), .clk(clk));
reg1_en EXMEM_MTR(.q(exmem_MemToReg_q), .d(idex_MemToReg_q), .en(1'b1), .reset(reset), .clk(clk));
reg1_en EXMEM_LSR(.q(exmem_IsLSR_q), .d(idex_IsLSR_q), .en(1'b1), .reset(reset), .clk(clk));
reg1_en EXMEM_RW(.q(exmem_RegWrite_q), .d(idex_RegWrite_q), .en(1'b1), .reset(reset), .clk(clk));

// ==============================================================
// MEM STAGE: Data memory
// ==============================================================
logic [63:0] DMEM_Dout;

datamem DMEM(.address(exmem_alu_y_q), .write_enable(exmem_MemWrite_q),
             .read_enable(exmem_MemToReg_q),  // LDUR when MemToReg=1
             .write_data(exmem_store_data_q), .xfer_size(4'd8), .clk(clk), .read_data(DMEM_Dout));

// ==============================================================
// MEM/WB PIPELINE REGISTER
// ==============================================================
reg64_en MEMWB_ALU_Y(.q(memwb_alu_y_q), .d(exmem_alu_y_q), .en(1'b1), .reset(reset), .clk(clk));
reg64_en MEMWB_MEM_Y(.q(memwb_mem_y_q), .d(DMEM_Dout), .en(1'b1), .reset(reset), .clk(clk));
reg64_en MEMWB_SHF_Y(.q(memwb_shf_y_q), .d(exmem_shf_y_q), .en(1'b1), .reset(reset), .clk(clk));

regN_en #(.N(5))MEMWB_RD(.q(memwb_rd_addr_q), .d(exmem_rd_addr_q), .en(1'b1), .reset(reset),
                         .clk(clk));

reg1_en MEMWB_MTR(.q(memwb_MemToReg_q), .d(exmem_MemToReg_q), .en(1'b1), .reset(reset), .clk(clk));
reg1_en MEMWB_LSR(.q(memwb_IsLSR_q), .d(exmem_IsLSR_q), .en(1'b1), .reset(reset), .clk(clk));
reg1_en MEMWB_RW(.q(memwb_RegWrite_q), .d(exmem_RegWrite_q), .en(1'b1), .reset(reset), .clk(clk));

// WB control outputs
assign wb_rd_addr = memwb_rd_addr_q;
assign wb_reg_write = memwb_RegWrite_q;

// ==============================================================
// NEXT PC SELECTION (branch / fall-through)
// ==============================================================
// Branch delay slot semantics: instruction after branch always executes
mux2_64 MUX_NPC(.y(pc_next), .a(pc_plus4_if), .b(PC_branch_ex), .s(ex_branch_taken));

endmodule
