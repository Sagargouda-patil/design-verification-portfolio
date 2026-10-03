@echo off
cd /d "%~dp0.."
if /i "%1"=="questa" goto questa
iverilog -g2012 -o sim\a.out rtl\ahb2apb_bridge.sv tb\tb_ahb2apb_bridge.sv
if errorlevel 1 exit /b 1
vvp sim\a.out
goto :eof
:questa
vlib work
vlog -sv rtl\ahb2apb_bridge.sv tb\tb_ahb2apb_bridge.sv
vsim -c -do "run -all; quit" tb_ahb2apb_bridge
