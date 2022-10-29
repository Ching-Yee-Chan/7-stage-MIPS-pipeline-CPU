`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   11:57:16 04/23/2016
// Design Name:   pipeline_cpu
// Module Name:   F:/new_lab/8_pipeline_cpu/tb.v
// Project Name:  pipeline_cpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: pipeline_cpu
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb;

    // Inputs
    reg clk;
    reg resetn;
    reg [4:0] rf_addr;
    reg [31:0] mem_addr;

    // Outputs
    wire [31:0] rf_data;
    wire [31:0] mem_data;
    wire [31:0] IF1_pc;
    wire [31:0] IF2_pc;
    wire [31:0] IF3_pc;
    wire [31:0] IF_inst;
    wire [31:0] ID_pc;
    wire [31:0] EXE_pc;
    wire [31:0] MEM_pc;
    wire [31:0] WB_pc;
    wire [31:0] cpu_5_valid;
    
    wire [31:0] exe_res;
    wire [31:0] alu_op2;

    // Instantiate the Unit Under Test (UUT)
    pipeline_cpu uut (
        .clk(clk), 
        .resetn(resetn), 
        .rf_addr(rf_addr), 
        .mem_addr(mem_addr), 
        .rf_data(rf_data), 
        .mem_data(mem_data), 
        .IF1_pc(IF1_pc), 
        .IF2_pc(IF2_pc), 
        .IF3_pc(IF3_pc), 
        .IF_inst(IF_inst), 
        .ID_pc(ID_pc), 
        .EXE_pc(EXE_pc), 
        .MEM_pc(MEM_pc), 
        .WB_pc(WB_pc), 
        
        ._jbr(jbr), 
        ._flush(flush),
        .exe_res(exe_res), 
        .alu_op_2(alu_op2), 
        
        .cpu_5_valid(cpu_5_valid)
    );

    initial begin
        // Initialize Inputs
        clk = 0;
        resetn = 0;
        rf_addr = 0;
        mem_addr = 20;

        // Wait 100 ns for global reset to finish
        #100;
      resetn = 1;
        // Add stimulus here
        #65;
      rf_addr = 1;
        #40;
      rf_addr = 2;
        #50;
      rf_addr = 3;
        #30;
      rf_addr = 4;
        #40;
      rf_addr = 25;
        #50;
      rf_addr = 12;
        #30;
      rf_addr = 26;
        #50;
      rf_addr = 27;
        #30;
      rf_addr = 31;
        #30;
      rf_addr = 5;
        #30;
      mem_addr = 20;
        #30;
      rf_addr = 6;
        #30;
      rf_addr = 7;
        #30;
      rf_addr = 8;
        #30;
      mem_addr = 28;
      rf_addr = 3;
        #30;
      rf_addr = 1;
        #70;
      rf_addr = 10;
        #140;
      rf_addr = 31;
        #70;
      mem_addr = 22;
        #70;
       rf_addr = 13;
         #110;
       rf_addr = 14;
         #70;
       rf_addr = 15;
         #70;
       rf_addr = 16;
         #180;
       rf_addr = 11;
         #110;
       rf_addr = 24;
         #70;
       rf_addr = 29;
         #30;
       rf_addr = 11;
         #90;
       rf_addr = 28;
         #40;
       rf_addr = 29;
         #70;
       mem_addr = 21;
         #80;
       rf_addr = 18;
         #80;
       rf_addr = 19;
         #70;
       rf_addr = 24;
         #70;
       rf_addr = 29;
         #120;
       rf_addr = 28;
         #40;
       rf_addr = 29;
         #70;
       rf_addr = 20;
         #70;
       rf_addr = 21;
         #70;
       rf_addr = 22;
    end
   always #5 clk=~clk;
endmodule

