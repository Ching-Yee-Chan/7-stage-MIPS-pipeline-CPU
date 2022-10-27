@echo off
set xv_path=E:\\vivado\\Vivado\\2017.1\\bin
call %xv_path%/xsim tb_func_synth -key {Post-Synthesis:sim_1:Functional:tb} -tclbatch tb.tcl -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
