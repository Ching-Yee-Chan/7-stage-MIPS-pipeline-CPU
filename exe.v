`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: exe.v
//   > 描述  :五级流水CPU的执行模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module exe(                         // 执行级
    input              EXE_valid,   // 执行级有效信号
    input      [178:0] ID_EXE_bus_r,// ID->EXE总线
    output             EXE_over,    // EXE模块执行完成
    output     [158:0] EXE_MEM_bus, // EXE->MEM总线
    
     //5级流水新增
     input             clk,       // 时钟
     output     [  4:0] EXE_wdest,   // EXE级要写回寄存器堆的目标地址号

     //旁路检测用
     //MEM
     input              MEM_RegWrite, 
     input      [  4:0] MEM_wdest, 
     //WB
     input      [  4:0] WB_wdest, 
     input              WB_RegWrite, 
     input      [ 31:0] MEM_data, 
     input      [ 31:0] WB_data, 
     
     //冒险检测用
     output             EX_MemRead, 
     output     [ 32:0] jbr_bus, 
     
    //展示PC
    output     [ 31:0] EXE_pc
//    output     [ 31:0] realOp1, 
//    output     [ 31:0] realOp2 
);

//-----{ID->EXE总线}begin
    //EXE需要用到的信息
    wire multiply;            //乘法
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    //访存需要用到的load/store信息
    wire [3:0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data_raw;
    wire [31:0] store_data;  //store操作的存的数据
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    
    //旁路专用
    wire        inst_no_rs;
    wire        inst_no_rt;
    wire [4 :0] rs;
    wire [4: 0] rt;
    
    //pc
    wire [31:0] pc;
    assign {multiply,
            mthi,
            mtlo,
            alu_control,
            alu_operand1,
            alu_operand2,
            //旁路专用
            inst_no_rs, 
            inst_no_rt, 
            rs, 
            rt,
            //旁路专用结束
            mem_control,
            store_data_raw,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            rf_wen,
            rf_wdest,
            pc          } = ID_EXE_bus_r;
//-----{ID->EXE总线}end

//旁路机制
//MEM->EX：优先满足
    wire inst_store;
    assign inst_store = mem_control[2];
    
    wire MEMToEx_rs;
    assign MEMToEx_rs = MEM_RegWrite &
                     (|MEM_wdest) &       //MEM_wdest!=0
                     (~inst_no_rs) & 
                     (MEM_wdest == rs);
    wire MEMToEx_rt;
    assign MEMToEx_rt = MEM_RegWrite &
                      (|MEM_wdest) &       //MEM_wdest!=0
                      (~inst_no_rt) & 
                      (MEM_wdest == rt);
//WB->EX
    wire WBToEx_rs;
    assign WBToEx_rs = WB_RegWrite &
                      (|WB_wdest) &       //MEM_wdest!=0
                      (~MEMToEx_rs) &     //优先满足MEM->EX
                      (~inst_no_rs) & 
                      (WB_wdest == rs);
    wire WBToEx_rt;
    assign WBToEx_rt = WB_RegWrite &
                      (|WB_wdest) &       //MEM_wdest!=0
                      (~MEMToEx_rt) &     //优先满足MEM->EX
                      (~inst_no_rt) & 
                      (WB_wdest == rt);
//operandMux
    wire [31:0] realOp1;
    wire [31:0] realOp2;
    assign realOp1 = MEMToEx_rs ? MEM_data : 
                     WBToEx_rs ? WB_data :
                     alu_operand1;
    assign realOp2 = (MEMToEx_rt & ~inst_store) ? MEM_data : 
                     (WBToEx_rt & ~inst_store) ? WB_data :    //store指令旁路至store_data而Op2
                     alu_operand2;
    assign store_data = (MEMToEx_rt & inst_store) ? MEM_data :
                        (WBToEx_rt & inst_store) ? WB_data : store_data_raw;
    
//冒险检测专用
    assign EX_MemRead = mem_control[3] | mfc0;//mfc0得结果也需要在最后才有，因此要阻塞

//-----{ALU}begin
    wire [31:0] alu_result;

    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU控制信号
        .alu_src1     (realOp1),  // I, 32, ALU操作数1
        .alu_src2     (realOp2),  // I, 32, ALU操作数2
        .alu_result   (alu_result  )   // O, 32, ALU结果
    );
//-----{ALU}end

//-----{乘法器}begin
    wire        mult_begin; 
    wire [63:0] product; 
    wire        mult_end;
    
    assign mult_begin = multiply & EXE_valid;
    multiply multiply_module (
        .clk       (clk       ),
        .mult_begin(mult_begin  ),
        .mult_op1  (realOp1), 
        .mult_op2  (realOp2),
        .product   (product   ),
        .mult_end  (mult_end  )
    );
//-----{乘法器}end

//-----{EXE执行完成}begin
    //对于ALU操作，都是1拍可完成，
    //但对于乘法操作，需要多拍完成
    assign EXE_over = EXE_valid & (~multiply | mult_end);
//-----{EXE执行完成}end

//阻塞控制
    assign jbr_bus = {EXE_valid & multiply & mult_end, pc+8};

//-----{EXE模块的dest值}begin
   //只有在EXE模块有效时，其写回目的寄存器号才有意义
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXE模块的dest值}end

//-----{EXE->MEM总线}begin
    wire [31:0] exe_result;   //在exe级能确定的最终写回结果
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //要写入HI的值放在exe_result里，包括MULT和MTHI指令,
    //要写入LO的值放在lo_result里，包括MULT和MTLO指令,
    assign exe_result = mthi     ? realOp1 :
                        mtc0     ? realOp2 : 
                        multiply ? product[63:32] : alu_result;
    assign lo_result  = mtlo ? realOp1 : product[31:0];
    assign hi_write   = multiply | mthi;
    assign lo_write   = multiply | mtlo;
    
    assign EXE_MEM_bus = {mem_control,store_data,          //load/store信息和store数据
                          exe_result,                      //exe运算结果
                          rt,                              //旁路专用
                          lo_result,                       //乘法低32位结果，新增
                          hi_write,lo_write,               //HI/LO写使能，新增
                          mfhi,mflo,                       //WB需用的信号,新增
                          mtc0,mfc0,cp0r_addr,syscall,eret,//WB需用的信号,新增
                          rf_wen,rf_wdest,                 //WB需用的信号
                          pc};                             //PC
//-----{EXE->MEM总线}end

//-----{展示EXE模块的PC值}begin
    assign EXE_pc = pc;
//-----{展示EXE模块的PC值}end
endmodule
