`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: fetch.v
//   > 描述  :五级流水CPU的取指模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
`define STARTADDR 32'H00000034   // 程序起始地址为34H
module fetch1(                    // 取指级
    input             clk,       // 时钟
    input             resetn,    // 复位信号，低电平有效
    input             IF1_valid,  // 取指级有效信号
    input             next_fetch,// 取下一条指令，用来锁存PC值
    input      [32:0] jbr_bus,   // 跳转总线
    output     [31:0] inst_addr, // 发往inst_rom的取指地址
    output            IF1_over,   // IF模块执行完成
    output     [31:0] IF1_IF2_bus, // IF->ID总线
    output            flush, //若分支预测失败，flush掉IF2、IF3、ID
    
    //5级流水新增接口
    input      [32:0] exc_bus,   // Exception pc总线
        
    //展示PC和取出的指令
    output     [31:0] IF1_pc
);

//-----{程序计数器PC}begin
    wire [31:0] next_pc;
    wire [31:0] seq_pc;
    reg  [31:0] pc;
    
    //跳转pc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {jbr_taken, jbr_target} = jbr_bus;  // 跳转总线传是否跳转和目标地址
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    assign flush = jbr_taken | exc_valid;
    
    //pc+4
    assign seq_pc[31:2]    = pc[31:2] + 1'b1;  // 下一指令地址：PC=PC+4
    assign seq_pc[1:0]     = pc[1:0];

    // 新指令：若有Exception,则PC为Exceptio入口地址
    //         若指令跳转，则PC为跳转地址；否则为pc+4
    
    assign next_pc = exc_valid ? exc_pc : 
                     jbr_taken ? jbr_target : seq_pc;
    always @(posedge clk)    // PC程序计数器
    begin
        if ((!resetn) || next_pc > 32'h1b4)    //小心！跳转不能越界
        begin
            pc <= `STARTADDR; // 复位，取程序起始地址
        end
        else if (next_fetch || flush)
        begin
            pc <= next_pc;    // 不复位，取新指令
        end
    end
//-----{程序计数器PC}end

//-----{发往inst_rom的取指地址}begin
    assign inst_addr = pc;
//-----{发往inst_rom的取指地址}end


    assign IF1_over = IF1_valid;
    //如果指令rom为异步读的，则IF_valid即是IF_over信号，
    //即取指一拍完成
//-----{IF执行完成}end

//-----{IF->ID总线}begin
    assign IF1_IF2_bus = pc;  // 取指级有效时，锁存PC和指令
//-----{IF->ID总线}end

//-----{展示IF模块的PC值和指令}begin
    assign IF1_pc   = pc;
//-----{展示IF模块的PC值和指令}end
endmodule
