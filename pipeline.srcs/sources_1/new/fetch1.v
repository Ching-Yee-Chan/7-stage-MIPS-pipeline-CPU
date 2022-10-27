`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: fetch.v
//   > ����  :�弶��ˮCPU��ȡָģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
`define STARTADDR 32'H00000034   // ������ʼ��ַΪ34H
module fetch1(                    // ȡָ��
    input             clk,       // ʱ��
    input             resetn,    // ��λ�źţ��͵�ƽ��Ч
    input             IF1_valid,  // ȡָ����Ч�ź�
    input             next_fetch,// ȡ��һ��ָ���������PCֵ
    input      [32:0] jbr_bus,   // ��ת����
    output     [31:0] inst_addr, // ����inst_rom��ȡָ��ַ
    output            IF1_over,   // IFģ��ִ�����
    output     [31:0] IF1_IF2_bus, // IF->ID����
    output            flush, //����֧Ԥ��ʧ�ܣ�flush��IF2��IF3��ID
    
    //5����ˮ�����ӿ�
    input      [32:0] exc_bus,   // Exception pc����
        
    //չʾPC��ȡ����ָ��
    output     [31:0] IF1_pc
);

//-----{���������PC}begin
    wire [31:0] next_pc;
    wire [31:0] seq_pc;
    reg  [31:0] pc;
    
    //��תpc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {jbr_taken, jbr_target} = jbr_bus;  // ��ת���ߴ��Ƿ���ת��Ŀ���ַ
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    assign flush = jbr_taken | exc_valid;
    
    //pc+4
    assign seq_pc[31:2]    = pc[31:2] + 1'b1;  // ��һָ���ַ��PC=PC+4
    assign seq_pc[1:0]     = pc[1:0];

    // ��ָ�����Exception,��PCΪExceptio��ڵ�ַ
    //         ��ָ����ת����PCΪ��ת��ַ������Ϊpc+4
    assign next_pc = exc_valid ? exc_pc : 
                     jbr_taken ? jbr_target : seq_pc;
    always @(posedge clk)    // PC���������
    begin
        if (!resetn)
        begin
            pc <= `STARTADDR; // ��λ��ȡ������ʼ��ַ
        end
        else if (next_fetch)
        begin
            pc <= next_pc;    // ����λ��ȡ��ָ��
        end
    end
//-----{���������PC}end

//-----{����inst_rom��ȡָ��ַ}begin
    assign inst_addr = pc;
//-----{����inst_rom��ȡָ��ַ}end


    assign IF1_over = IF1_valid;
    //���ָ��romΪ�첽���ģ���IF_valid����IF_over�źţ�
    //��ȡָһ�����
//-----{IFִ�����}end

//-----{IF->ID����}begin
    assign IF1_IF2_bus = pc;  // ȡָ����Чʱ������PC��ָ��
//-----{IF->ID����}end

//-----{չʾIFģ���PCֵ��ָ��}begin
    assign IF1_pc   = pc;
//-----{չʾIFģ���PCֵ��ָ��}end
endmodule
