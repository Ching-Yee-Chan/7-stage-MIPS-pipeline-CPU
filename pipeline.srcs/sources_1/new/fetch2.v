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
module fetch2(                    // ȡָ��
    input             IF2_valid,  // ȡָ����Ч�ź�
    input      [31:0] IF_IF2_bus_r,
    output            IF2_over,  // ȡָ����Ч�ź�
    output     [31:0] IF2_IF3_bus, // IF->ID����
        
    //չʾPC��ȡ����ָ��
    output     [31:0] IF2_pc
);
    assign IF2_IF3_bus = IF_IF2_bus_r;
    assign IF2_over = IF2_valid;

//-----{չʾIFģ���PCֵ��ָ��}begin
    assign IF2_pc   = IF_IF2_bus_r;
endmodule