#!/bin/bash
# Icarus Verilog (open source):   ./sim/run.sh
# ModelSim/Questa:                ./sim/run.sh questa
cd "$(dirname "$0")/.."
if [ "$1" == "questa" ]; then
  vlib work && vlog -sv rtl/ahb2apb_bridge.sv tb/tb_ahb2apb_bridge.sv \
  && vsim -c -do "run -all; quit" tb_ahb2apb_bridge
else
  iverilog -g2012 -o sim/a.out rtl/ahb2apb_bridge.sv tb/tb_ahb2apb_bridge.sv && vvp sim/a.out
fi
