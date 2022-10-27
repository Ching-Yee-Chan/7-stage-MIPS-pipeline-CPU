`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2022 05:25:27 PM
// Design Name: 
// Module Name: fetch3
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module fetch3(                    // 取指级
    input      [31:0] inst,      // inst_rom取出的指令
    input      IF3_valid,  // 取指级有效信号
    input      [31:0] IF2_IF3_bus_r,
    output     IF3_over,   // IF模块执行完成
    output     [63:0] IF_ID_bus, // IF->ID总线
        
    //展示PC和取出的指令
    output     [31:0] IF3_pc,
    output     [31:0] IF_inst
);

//-----{IF->ID总线}begin
    assign IF_ID_bus = {IF2_IF3_bus_r, inst};  // 取指级有效时，锁存PC和指令
//-----{IF->ID总线}end

    assign IF3_over = IF3_valid;

//-----{展示IF模块的PC值和指令}begin
    assign IF3_pc   = IF2_IF3_bus_r;
    assign IF_inst = inst;
//-----{展示IF模块的PC值和指令}end
endmodule