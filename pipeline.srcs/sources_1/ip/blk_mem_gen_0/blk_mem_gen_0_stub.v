// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.1 (win64) Build 1846317 Fri Apr 14 18:55:03 MDT 2017
// Date        : Wed Oct 19 08:24:59 2022
// Host        : LAPTOP-P861Q9K2 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/vivadowork/pipeline/pipeline.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0_stub.v
// Design      : blk_mem_gen_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_3_6,Vivado 2017.1" *)
module blk_mem_gen_0(clka, wea, addra, dina, douta, clkb, web, addrb, dinb, 
  doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[3:0],addra[7:0],dina[31:0],douta[31:0],clkb,web[3:0],addrb[7:0],dinb[31:0],doutb[31:0]" */;
  input clka;
  input [3:0]wea;
  input [7:0]addra;
  input [31:0]dina;
  output [31:0]douta;
  input clkb;
  input [3:0]web;
  input [7:0]addrb;
  input [31:0]dinb;
  output [31:0]doutb;
endmodule
