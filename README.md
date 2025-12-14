# 64-bit ARM CPU (Single-Cycle and 5-Stage Pipelined)

This repository contains a **64-bit ARM-style CPU** implemented in **SystemVerilog**, including both a **single-cycle** and a **5-stage pipelined** design.  
The project focuses on a clean datapath implementation, explicit hazard handling, and modular hardware design.

## Implementations

### Single-Cycle CPU
- Implemented in `singlecpu.sv`
- Executes one instruction per clock cycle
- Serves as a functional reference for the pipelined CPU

### 5-Stage Pipelined CPU
- Implemented in `pipecpu.sv`
- Uses a classic pipeline structure:
  1. Instruction Fetch (IF)
  2. Instruction Decode / Register Fetch (ID)
  3. Execute (EX)
  4. Memory Access (MEM)
  5. Write Back (WB)
- Pipeline registers separate each stage to enable instruction overlap

## Instruction Support

The CPU supports the following instruction subset:

- `ADDI`
- `ADDS`
- `SUBS`
- `AND`
- `EOR`
- `LSR`
- `LDUR`
- `STUR`
- `CBZ`
- `B`
- `B.LT`

## Hazard Handling (Pipelined CPU)

- **Load-use hazards** are detected and handled with a single-cycle stall
- **Data hazards** are resolved using forwarding logic
- Forwarding paths exist from EX/MEM and MEM/WB pipeline stages

## Module Overview

### Top-Level
- `singlecpu.sv` – Single-cycle CPU
- `pipecpu.sv` – 5-stage pipelined CPU
- `controller.sv` – Instruction decode and control logic

### Datapath Components
- `alu.sv` – Arithmetic Logic Unit
- `adder1bit.sv` – 1-bit adder used in arithmetic construction
- `math.sv` – Supporting arithmetic logic
- `regfile.sv` – 32×64 register file
- `reg_en.sv` – Register modules with enable
- `decoder.sv` – Instruction decoding logic
- `forwarding_unit.sv` – Data forwarding logic
- `or_reduce64.sv` – Reduction logic
- `mux2.sv` – 2:1 multiplexer
- `mux32.sv` – 32:1 multiplexer
- `gate_lib.sv` – Basic gate-level primitives

### Memory & Testbench
- `instructmem.sv` – Instruction memory
- `datamem.sv` – Data memory
- `cpustim.sv` – CPU testbench
- `runlab.do` – ModelSim run script

## Simulation & Verification

The design is verified using waveform-based simulation.  
Verification includes:
- Correct instruction execution
- Proper pipeline operation
- Correct stall and forwarding behavior
- Correct register and memory updates

## Notes

- Datapath logic is primarily structural
- Control logic uses RTL where appropriate

## Status

The CPU successfully executes the supported instruction set in both single-cycle and pipelined configurations with correct hazard handling.
