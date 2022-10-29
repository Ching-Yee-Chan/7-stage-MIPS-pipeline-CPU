`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: exe.v
//   > ����  :�弶��ˮCPU��ִ��ģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
module exe(                         // ִ�м�
    input              EXE_valid,   // ִ�м���Ч�ź�
    input      [178:0] ID_EXE_bus_r,// ID->EXE����
    output             EXE_over,    // EXEģ��ִ�����
    output     [158:0] EXE_MEM_bus, // EXE->MEM����
    
     //5����ˮ����
     input             clk,       // ʱ��
     output     [  4:0] EXE_wdest,   // EXE��Ҫд�ؼĴ����ѵ�Ŀ���ַ��

     //��·�����
     //MEM
     input              MEM_RegWrite, 
     input      [  4:0] MEM_wdest, 
     //WB
     input      [  4:0] WB_wdest, 
     input              WB_RegWrite, 
     input      [ 31:0] MEM_data, 
     input      [ 31:0] WB_data, 
     
     //ð�ռ����
     output             EX_MemRead, 
     output     [ 32:0] jbr_bus, 
     
    //չʾPC
    output     [ 31:0] EXE_pc
//    output     [ 31:0] realOp1, 
//    output     [ 31:0] realOp2 
);

//-----{ID->EXE����}begin
    //EXE��Ҫ�õ�����Ϣ
    wire multiply;            //�˷�
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    //�ô���Ҫ�õ���load/store��Ϣ
    wire [3:0] mem_control;  //MEM��Ҫʹ�õĿ����ź�
    wire [31:0] store_data_raw;
    wire [31:0] store_data;  //store�����Ĵ������
                          
    //д����Ҫ�õ�����Ϣ
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall��eret��д�ؼ�������Ĳ��� 
    wire       eret;
    wire       rf_wen;    //д�صļĴ���дʹ��
    wire [4:0] rf_wdest;  //д�ص�Ŀ�ļĴ���
    
    //��·ר��
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
            //��·ר��
            inst_no_rs, 
            inst_no_rt, 
            rs, 
            rt,
            //��·ר�ý���
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
//-----{ID->EXE����}end

//��·����
//MEM->EX����������
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
                      (~MEMToEx_rs) &     //��������MEM->EX
                      (~inst_no_rs) & 
                      (WB_wdest == rs);
    wire WBToEx_rt;
    assign WBToEx_rt = WB_RegWrite &
                      (|WB_wdest) &       //MEM_wdest!=0
                      (~MEMToEx_rt) &     //��������MEM->EX
                      (~inst_no_rt) & 
                      (WB_wdest == rt);
//operandMux
    wire [31:0] realOp1;
    wire [31:0] realOp2;
    assign realOp1 = MEMToEx_rs ? MEM_data : 
                     WBToEx_rs ? WB_data :
                     alu_operand1;
    assign realOp2 = (MEMToEx_rt & ~inst_store) ? MEM_data : 
                     (WBToEx_rt & ~inst_store) ? WB_data :    //storeָ����·��store_data��Op2
                     alu_operand2;
    assign store_data = (MEMToEx_rt & inst_store) ? MEM_data :
                        (WBToEx_rt & inst_store) ? WB_data : store_data_raw;
    
//ð�ռ��ר��
    assign EX_MemRead = mem_control[3] | mfc0;//mfc0�ý��Ҳ��Ҫ�������У����Ҫ����

//-----{ALU}begin
    wire [31:0] alu_result;

    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU�����ź�
        .alu_src1     (realOp1),  // I, 32, ALU������1
        .alu_src2     (realOp2),  // I, 32, ALU������2
        .alu_result   (alu_result  )   // O, 32, ALU���
    );
//-----{ALU}end

//-----{�˷���}begin
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
//-----{�˷���}end

//-----{EXEִ�����}begin
    //����ALU����������1�Ŀ���ɣ�
    //�����ڳ˷���������Ҫ�������
    assign EXE_over = EXE_valid & (~multiply | mult_end);
//-----{EXEִ�����}end

//��������
    assign jbr_bus = {EXE_valid & multiply & mult_end, pc+8};

//-----{EXEģ���destֵ}begin
   //ֻ����EXEģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXEģ���destֵ}end

//-----{EXE->MEM����}begin
    wire [31:0] exe_result;   //��exe����ȷ��������д�ؽ��
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //Ҫд��HI��ֵ����exe_result�����MULT��MTHIָ��,
    //Ҫд��LO��ֵ����lo_result�����MULT��MTLOָ��,
    assign exe_result = mthi     ? realOp1 :
                        mtc0     ? realOp2 : 
                        multiply ? product[63:32] : alu_result;
    assign lo_result  = mtlo ? realOp1 : product[31:0];
    assign hi_write   = multiply | mthi;
    assign lo_write   = multiply | mtlo;
    
    assign EXE_MEM_bus = {mem_control,store_data,          //load/store��Ϣ��store����
                          exe_result,                      //exe������
                          rt,                              //��·ר��
                          lo_result,                       //�˷���32λ���������
                          hi_write,lo_write,               //HI/LOдʹ�ܣ�����
                          mfhi,mflo,                       //WB���õ��ź�,����
                          mtc0,mfc0,cp0r_addr,syscall,eret,//WB���õ��ź�,����
                          rf_wen,rf_wdest,                 //WB���õ��ź�
                          pc};                             //PC
//-----{EXE->MEM����}end

//-----{չʾEXEģ���PCֵ}begin
    assign EXE_pc = pc;
//-----{չʾEXEģ���PCֵ}end
endmodule
