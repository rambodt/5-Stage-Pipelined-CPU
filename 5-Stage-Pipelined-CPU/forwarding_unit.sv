// Forwarding unit for 5-stage pipelined CPU.
// Selects EX stage operands from:
//   00: ID/EX register file outputs
//   10: EX/MEM result
//   01: MEM/WB writeback value
module forwarding_unit(input logic [4 : 0] idex_rs1, input logic [4 : 0] idex_rs2,
                       input logic [4 : 0] exmem_rd, input logic [4 : 0] memwb_rd,
                       input logic exmem_regwrite, input logic memwb_regwrite,
                       input logic exmem_memread,  // 1 when EX/MEM instruction is LDUR
                       output logic [1 : 0] forwardA, output logic [1 : 0] forwardB);
logic [4:0] XZR_IDX = 5'd31;

always_comb begin
    // Defaults: no forwarding
    forwardA = 2'b00;
forwardB = 2'b00;

// EX/MEM hazards (one cycle back), except loads (result not ready yet)
if (exmem_regwrite && !exmem_memread && (exmem_rd != XZR_IDX))
  begin if (exmem_rd == idex_rs1) forwardA = 2'b10;
if (exmem_rd == idex_rs2) forwardB = 2'b10;
end

    // MEM/WB hazards (two cycles back)
    if (memwb_regwrite && (memwb_rd != XZR_IDX))
        begin if ((memwb_rd == idex_rs1) && (forwardA == 2'b00)) forwardA = 2'b01;
if ((memwb_rd == idex_rs2) && (forwardB == 2'b00)) forwardB = 2'b01;
end end endmodule
