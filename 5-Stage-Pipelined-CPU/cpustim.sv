// EE469 Lab 3/4 — cpu testbench
`timescale 1ns / 10ps

    module cpustim;
parameter int ClockPeriodNS = 20000;
parameter int MaxCycles = 5000;

logic clk = 1'b0;
logic reset = 1'b1;
logic stur_q = 11'b0;  // debug

// B-type opcode (for HALT B #0 detect)
localparam logic [5:0] B_OPCODE = 6'h05;

// Clock
always #(ClockPeriodNS / 2) clk = ~clk;

// Reset high for a few edges
initial begin $timeformat(-9, 2, " ns", 10);
repeat(5) @(posedge clk);
reset = 1'b0;
end

    // DUT
    pipecpu dut(.clk(clk), .reset(reset));

// ------------------------------------------------------------
// Console trace (disabled block)
// ------------------------------------------------------------
integer cyc = 0;
always @(posedge clk) begin cyc <= cyc + 1;
/*
    $display("================================================================");
    $display("CYCLE %0d  time=%0t", cyc, $time);
    $display("B_OPCODE = %b", B_OPCODE);

    // Register file ports
    $display("RF: R1=%0d R2=%0d WReg=%0d",
             dut.RF.ReadRegister1,
             dut.RF.ReadRegister2,
             dut.RF.WriteRegister);
    $display("RF data: R1D=%h R2D=%h WD=%h",
             dut.RF.ReadData1,
             dut.RF.ReadData2,
             dut.RF.WriteData);

    // Memories
    $display("IMEM: instr=%h", dut.IMEM.instruction);
    $display("DMEM: addr=%h WE=%b WD=%h RE=%b RD=%h",
             dut.DMEM.address,
             dut.DMEM.write_enable,
             dut.DMEM.write_data,
             dut.DMEM.read_enable,
             dut.DMEM.read_data);

    // IF / IFID
    $display("IF:    PC_IF=%0d Instr_IF=%h", dut.pc_q_if, dut.instr_if);
    $display("IFID:  PC=%0d Instr=%h",      dut.ifid_pc_q, dut.ifid_instr_q);
    $display("PC_q (alias used by tb) = %0d", dut.PC_q);

    // ID/EX
    $display("IDEX:  PC=%0d RS1=%h RS2=%h RD=%0d",
             dut.IDEX_PC.q,
             dut.IDEX_RS1.q,
             dut.IDEX_RS2.q,
             dut.idex_rd_addr_q);
    $display("IDEX ctrl: ALUOP=%0b MW=%b MTR=%b RW=%b",
             dut.IDEX_ALUOP.q,
             dut.IDEX_MW.q,
             dut.IDEX_MTR.q,
             dut.IDEX_RW.q);

    // EX/MEM
    $display("EXMEM: PC=%0d ALU_Y=%h STORE=%h RD=%0d",
             dut.EXMEM_PC.q,
             dut.EXMEM_ALU_Y.q,
             dut.EXMEM_STORE.q,
             dut.EXMEM_RD.q);
    $display("EXMEM ctrl: MW=%b MTR=%b RW=%b",
             dut.EXMEM_MW.q,
             dut.EXMEM_MTR.q,
             dut.EXMEM_RW.q);

    // MEM/WB
    $display("MEMWB: ALU_Y=%h MEM_Y=%h SHF_Y=%h RD=%0d",
             dut.MEMWB_ALU_Y.q,
             dut.MEMWB_MEM_Y.q,
             dut.MEMWB_SHF_Y.q,
             dut.MEMWB_RD.q);
    $display("MEMWB ctrl: MTR=%b LSR=%b RW=%b",
             dut.MEMWB_MTR.q,
             dut.MEMWB_LSR.q,
             dut.MEMWB_RW.q);

    // Forwarding / ID-bypass debug
    $display("FWD Debug: Aa_id=%0d Ab_id=%0d", dut.Aa_id, dut.Ab_id);
    $display("FWD Debug: idex_rs1_addr=%0d idex_rs2_addr=%0d",
             dut.idex_rs1_addr_q, dut.idex_rs2_addr_q);
    $display("FWD Debug: fwdA_sel=%b fwdB_sel=%b",
             dut.fwdA_sel, dut.fwdB_sel);
    $display("FWD Debug: exmem_rd=%0d (RegWrite=%b MemToReg=%b) | memwb_rd=%0d (RegWrite=%b)",
             dut.exmem_rd_addr_q, dut.exmem_RegWrite_q, dut.exmem_MemToReg_q,
             dut.memwb_rd_addr_q, dut.memwb_RegWrite_q);
    $display("FWD Debug: ex_A_src=%h ex_B_src=%h",
             dut.ex_A_src, dut.ex_B_src);
    $display("FWD Debug: ID bypass: idA_sel_wb=%b idB_sel_wb=%b",
             dut.idA_sel_wb, dut.idB_sel_wb);
    $display("FWD Debug: idA_val=%h idB_val=%h",
             dut.idA_val, dut.idB_val);

    $display("FLAGS: N=%b Z=%b C=%b V=%b", dut.N_q, dut.Z_q, dut.C_q, dut.V_q);
    $display("BRANCH Debug: ex_branch_taken=%b idex_is_branch=%b idex_UncondBr=%b idex_IsCBZ=%b",
             dut.ex_branch_taken, dut.idex_is_branch_q, dut.idex_UncondBr_q, dut.idex_IsCBZ_q);

    // Architectural register dump (X0..X19)
    for (int i = 0; i < 20; i++) begin
      $display("  X%0d = %0d (0x%016h)", i, dut.RF.regs_q[i], dut.RF.regs_q[i]);
    end
*/
end

    // ------------------------------------------------------------
    // Run control / halt detection with pipeline drain
    // ------------------------------------------------------------
    int cycle;
bit halt_seen = 0;
int drain = 8;  // extra cycles after seeing B #0

initial begin
    // Wait for reset to deassert
    @(negedge reset);

// Wait until first non-X instruction
do @(posedge clk);
while ($isunknown(dut.Instruction));

for (cycle = 0; cycle < MaxCycles; cycle++) begin @(posedge clk);

// Detect B #0 once
if (!halt_seen && dut.Instruction [31:26] == B_OPCODE && dut.Instruction [25:0] == 26'd0 &&
    !dut.ex_branch_taken)
  begin halt_seen = 1;
$display("[%0t] HALT (B #0) fetched at PC=%0d, starting drain", $realtime, dut.PC_q);
end

    // After seeing B #0, run 'drain' more cycles to flush pipeline
    if (halt_seen) begin if (drain == 0) begin
// Let nonblocking writes settle
# 1;
        $display("Final register dump after drain:");
for (int i = 0; i < 20; i++)
  begin $display("X%0d = %0d (0x%016h)", i, dut.RF.regs_q[i], dut.RF.regs_q[i]);
end $stop;
end drain--;
end

    // Error if instruction bus goes X before halt
    if (!halt_seen && $isunknown(dut.Instruction))
        begin $display("[%0t] ERROR: Instruction bus became X at PC=%0d (cycle %0d)", $realtime,
                       dut.PC_q, cycle);
$stop;
end end

    $display("[%0t] Reached MaxCycles=%0d, stopping.", $realtime, MaxCycles);
# 1;
$stop;
end

    endmodule
