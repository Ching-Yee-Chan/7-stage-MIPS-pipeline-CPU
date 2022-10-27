`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2022 05:05:39 PM
// Design Name: 
// Module Name: fetch2
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
module fetch2(                    // 取指级
    input             IF2_valid,  // 取指级有效信号
    input      [31:0] IF_IF2_bus_r,
    output            IF2_over,  // 取指级有效信号
    output     [31:0] IF2_IF3_bus, // IF->ID总线
        
    //展示PC和取出的指令
    output     [31:0] IF2_pc
);
    assign IF2_IF3_bus = IF_IF2_bus_r;
    assign IF2_over = IF2_valid;

//-----{展示IF模块的PC值和指令}begin
    assign IF2_pc   = IF_IF2_bus_r;
endmodule