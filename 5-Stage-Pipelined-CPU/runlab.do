# Create work library
vlib work

# Compile Verilog
#     All Verilog files that are part of this design should have
#     their own "vlog" line below.
vlog "./mux2_1.sv"
vlog "./mux4_1.sv"
vlog "./gate_lib.sv"
vlog "./mux2.sv"
vlog "./mux32.sv"
vlog "./decoder.sv"
vlog "./reg_en.sv"
vlog "./regfile.sv"
vlog "./regstim.sv"
vlog "./adder1bit.sv"
vlog "./or_reduce64.sv"
vlog "./alu.sv"
vlog "./alustim.sv"
vlog "./cpu.sv"
vlog "./math.sv"
vlog "./controller.sv"
vlog "./instructmem.sv"
vlog "./datamem.sv"
vlog "./cpustim.sv"
vlog "./forwarding_unit.sv"
vlog "./pipecpu.sv"

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the
#     testbench module you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work cpustim

# Source the wave do file
#     This should be the file that sets up the signal window for
#     the module you are testing.
do cpustim_wave.do

# Set the window types
view wave
view structure
view signals

# Run the simulation
run -all

# End
