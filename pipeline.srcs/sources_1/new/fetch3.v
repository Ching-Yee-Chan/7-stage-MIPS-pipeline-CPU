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
module fetch3(                    // ȡָ��
    input      [31:0] inst,      // inst_romȡ����ָ��
    input      IF3_valid,  // ȡָ����Ч�ź�
    input      [31:0] IF2_IF3_bus_r,
    output     IF3_over,   // IFģ��ִ�����
    output     [63:0] IF_ID_bus, // IF->ID����
        
    //չʾPC��ȡ����ָ��
    output     [31:0] IF3_pc,
    output     [31:0] IF_inst
);

//-----{IF->ID����}begin
    assign IF_ID_bus = {IF2_IF3_bus_r, inst};  // ȡָ����Чʱ������PC��ָ��
//-----{IF->ID����}end

    assign IF3_over = IF3_valid;

//-----{չʾIFģ���PCֵ��ָ��}begin
    assign IF3_pc   = IF2_IF3_bus_r;
    assign IF_inst = inst;
//-----{չʾIFģ���PCֵ��ָ��}end
endmodule