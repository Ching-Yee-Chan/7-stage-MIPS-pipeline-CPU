@echo off
set xv_path=E:\\vivado\\Vivado\\2017.1\\bin
call %xv_path%/xelab  -wto fb1cff9766e84610876396cbf61fcacf -m64 --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L secureip --snapshot tb_func_synth xil_defaultlib.tb xil_defaultlib.glbl -log elaborate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
