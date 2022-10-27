# 
# Synthesis run script generated by Vivado
# 

create_project -in_memory -part xc7a200tfbg676-2

set_param project.singleFileAddWarning.threshold 0
set_param project.compositeFile.enableAutoGeneration 0
set_param synth.vivado.isSynthRun true
set_msg_config -source 4 -id {IP_Flow 19-2162} -severity warning -new_severity info
set_property webtalk.parent_dir D:/vivadowork/pipeline/pipeline.cache/wt [current_project]
set_property parent.project_path D:/vivadowork/pipeline/pipeline.xpr [current_project]
set_property XPM_LIBRARIES XPM_MEMORY [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property target_language Verilog [current_project]
set_property ip_output_repo d:/vivadowork/pipeline/pipeline.cache/ip [current_project]
set_property ip_cache_permissions {read write} [current_project]
add_files D:/vivadowork/pipeline/instructions.coe
read_verilog -library xil_defaultlib {
  D:/vivadowork/8_pipeline_cpu/adder.v
  D:/vivadowork/8_pipeline_cpu/alu.v
  D:/vivadowork/8_pipeline_cpu/decode.v
  D:/vivadowork/8_pipeline_cpu/exe.v
  D:/vivadowork/pipeline/pipeline.srcs/sources_1/new/fetch1.v
  D:/vivadowork/pipeline/pipeline.srcs/sources_1/new/fetch2.v
  D:/vivadowork/pipeline/pipeline.srcs/sources_1/new/fetch3.v
  D:/vivadowork/8_pipeline_cpu/mem.v
  D:/vivadowork/8_pipeline_cpu/multiply.v
  D:/vivadowork/8_pipeline_cpu/regfile.v
  D:/vivadowork/8_pipeline_cpu/wb.v
  D:/vivadowork/8_pipeline_cpu/pipeline_cpu.v
}
read_ip -quiet D:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/data_ram/data_ram.xci
set_property used_in_implementation false [get_files -all d:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/data_ram/data_ram_ooc.xdc]
set_property is_locked true [get_files D:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/data_ram/data_ram.xci]

read_ip -quiet D:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/inst_rom/inst_rom.xci
set_property used_in_implementation false [get_files -all d:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/inst_rom/inst_rom_ooc.xdc]
set_property is_locked true [get_files D:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/inst_rom/inst_rom.xci]

# Mark all dcp files as not used in implementation to prevent them from being
# stitched into the results of this synthesis run. Any black boxes in the
# design are intentionally left as such for best results. Dcp files will be
# stitched into the design at a later time, either when this synthesis run is
# opened, or when it is stitched into a dependent implementation run.
foreach dcp [get_files -quiet -all -filter file_type=="Design\ Checkpoint"] {
  set_property used_in_implementation false $dcp
}
read_xdc dont_touch.xdc
set_property used_in_implementation false [get_files dont_touch.xdc]

synth_design -top pipeline_cpu -part xc7a200tfbg676-2


write_checkpoint -force -noxdef pipeline_cpu.dcp

catch { report_utilization -file pipeline_cpu_utilization_synth.rpt -pb pipeline_cpu_utilization_synth.pb }
