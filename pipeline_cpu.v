`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: pipeline_cpu.v
//   > ����  :�弶��ˮCPUģ�飬��ʵ��XX��ָ��
//   >        ָ��rom������ram��ʵ����xilinx IP�õ���Ϊͬ����д
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
module pipeline_cpu(  // ������cpu
    input clk,           // ʱ��
    input resetn,        // ��λ�źţ��͵�ƽ��Ч
    
    //display data
    input  [ 4:0] rf_addr,
    input  [31:0] mem_addr,
    output [31:0] rf_data,
    output [31:0] mem_data,
    output [31:0] IF1_pc,
    output [31:0] IF2_pc, 
    output [31:0] IF3_pc, 
    output [31:0] IF_inst,
    output [31:0] ID_pc,
    output [31:0] EXE_pc,
    output [31:0] MEM_pc,
    output [31:0] WB_pc,
    
    output  _jbr,
    output _flush,
    output [31:0] exe_res, 
    output [31:0] alu_op_2, 
    
    //5����ˮ����
    output [31:0] cpu_5_valid,
    output [31:0] HI_data,
    output [31:0] LO_data
    );
    assign exe_res = rf_wdata;//dm_wdata;
    assign alu_op_2 = dm_wdata;
//------------------------{5����ˮ�����ź�}begin-------------------------//
    //5ģ���valid�ź�
    reg IF1_valid;
    reg IF2_valid;
    reg IF3_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5ģ��ִ������ź�,���Ը�ģ������
    wire IF1_over;
    wire IF2_over;
    wire IF3_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;
    //5ģ��������һ��ָ�����
    wire IF1_allow_in;
    wire IF2_allow_in;
    wire IF3_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    // syscall��eret����д�ؼ�ʱ�ᷢ��cancel�źţ�
    wire cancel;    // ȡ���Ѿ�ȡ��������������ˮ��ִ�е�ָ��
    //ð�ռ�ⵥԪ����֧Ԥ��ʧ��
    wire flush;
    wire ID_blocked;
    wire MEM_load;
    assign _flush = flush;
    assign _jbr = jbr_bus[32];
    
    //������������ź�:������Ч���򱾼�ִ��������¼��������
    assign IF1_allow_in  = (IF1_over & IF2_allow_in) | cancel;
    assign IF2_allow_in  = ~IF2_valid  | (IF2_over  & IF3_allow_in);
    assign IF3_allow_in  = ~IF3_valid  | (IF3_over  & ID_allow_in);
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid���ڸ�λ��һֱ��Ч
   always @(posedge clk)
    begin
        if (!resetn)
        begin
            IF1_valid <= 1'b0;
        end
        else
        begin
            IF1_valid <= 1'b1;
        end
    end
    
    always @(posedge clk)
    begin
        if (!resetn || cancel || (flush & ~ID_blocked))//������û������ֻflush IF2��IF3��ID�����ӳٲۣ�����������������IF2���ӳٲ�
        begin
            IF2_valid <= 1'b0;
        end
        else if (IF2_allow_in)
        begin
            IF2_valid <= IF1_over;
        end
    end
    
    always @(posedge clk)
    begin
        if (!resetn || cancel || flush)
        begin
            IF3_valid <= 1'b0;
        end
        else if (IF3_allow_in)
        begin
            IF3_valid <= IF2_over;
        end
    end
    
    //ID_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel || (flush & ID_over & ID_blocked)) //����������������Ϊ��תָ�ID flush
        begin
            ID_valid <= 1'b0;
        end
        else if (ID_allow_in)
        begin
            ID_valid <= IF3_over;
        end
    end
    
    //EXE_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            EXE_valid <= 1'b0;
        end
        else if (EXE_allow_in)
        begin
            EXE_valid <= ID_over;
        end
    end
    
    //MEM_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in)
        begin
            MEM_valid <= EXE_over;
        end
    end
    
    //WB_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            WB_valid <= 1'b0;
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;
        end
    end
    
    //չʾ5����valid�ź�
    assign cpu_5_valid = {4'd0         ,{4{IF1_valid }},{4{IF2_valid }},{4{IF3_valid }},{4{ID_valid}},
                          {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
//-------------------------{5����ˮ�����ź�}end--------------------------//

//--------------------------{5���������}begin---------------------------//
    wire [ 32:0] IF1_IF2_bus;
    wire [ 32:0] IF2_IF3_bus;
    wire [ 63:0] IF_ID_bus;   // IF->ID������
    wire [178:0] ID_EXE_bus;  // ID->EXE������
    wire [158:0] EXE_MEM_bus; // EXE->MEM������
    wire [117:0] MEM_WB_bus;  // MEM->WB������
    
    //�������������ź�
    reg [ 31:0] IF1_IF2_bus_r;
    reg [ 31:0] IF2_IF3_bus_r;
    reg [ 63:0] IF_ID_bus_r;
    reg [178:0] ID_EXE_bus_r;
    reg [158:0] EXE_MEM_bus_r;
    reg [117:0] MEM_WB_bus_r;
    
    always @(posedge clk)
    begin
        if(IF1_over && IF2_allow_in)
        begin
            IF1_IF2_bus_r <= IF1_IF2_bus;
        end
    end    always @(posedge clk)
        begin
            if(IF2_over && IF3_allow_in)
            begin
                IF2_IF3_bus_r <= IF2_IF3_bus;
            end
        end    
    //IF��ID�������ź�
    always @(posedge clk)
    begin
        if(IF3_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID��EXE�������ź�
    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE��MEM�������ź�
    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM��WB�������ź�
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
//---------------------------{5���������}end----------------------------//

//--------------------------{���������ź�}begin--------------------------//
    //��ת����
    wire [ 32:0] jbr_bus;    
    wire [ 32:0] jbr_bus_id;
    wire [ 32:0] jbr_bus_mem;
    wire [ 32:0] jbr_bus_exe;
    assign jbr_bus = jbr_bus_id[32] ? jbr_bus_id : jbr_bus_mem;
                     //jbr_bus_mem[32]? jbr_bus_mem : jbr_bus_exe;

    //IF��inst_rom����
    wire [31:0] inst_addr;
    wire [31:0] inst;

    //ID��EXE��MEM��WB����
    wire [ 4:0] EXE_wdest;
    wire [ 4:0] MEM_wdest;
    wire [ 4:0] WB_wdest;
    
    //MEM��data_ram����    
    wire [ 3:0] dm_wen;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;

    //ID��regfile����
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB��regfile����
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;    
    
    //WB��IF��Ľ����ź�
    wire [32:0] exc_bus;
    
    //��·���ר��
    wire        MEM_RegWrite;
    wire        WB_RegWrite;
    
    //ð�ռ��ר��
    wire        EX_MemRead;
    
//----------------------------{��·}-------------------------------------//
    //wire
    
//---------------------------{���������ź�}end---------------------------//

//-------------------------{��ģ��ʵ����}begin---------------------------//
    wire next_fetch; //��������ȡָģ�飬��Ҫ������PCֵ
    //IF�������ʱ��������PCֵ��ȡ��һ��ָ��
    assign next_fetch = IF1_allow_in;
    fetch1 IF_MODULE1(             // ȡָ��
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF1_valid  (IF1_valid  ),  // I, 1
        .next_fetch(next_fetch),  // I, 1
        .jbr_bus   (jbr_bus   ),  // I, 33
        .inst_addr (inst_addr ),  // O, 32
        .IF1_over   (IF1_over   ),  // O, 1
        .IF1_IF2_bus (IF1_IF2_bus ),  // O, 31
        .flush (flush), 
        
        //5����ˮ�����ӿ�
        .exc_bus   (exc_bus   ),  // I, 32
        
        //չʾPC��ȡ����ָ��
        .IF1_pc     (IF1_pc     )  // O, 32
    );
    
    fetch2 IF_MODULE2(                    // ȡָ��
        .IF2_valid (IF2_valid),  // ȡָ����Ч�ź�
        .IF_IF2_bus_r (IF1_IF2_bus_r),
        .IF2_over (IF2_over),  // ȡָ����Ч�ź�
        .IF2_IF3_bus (IF2_IF3_bus), // IF->ID����
            
        //չʾPC��ȡ����ָ��
        .IF2_pc (IF2_pc)
    );

    fetch3 IF_MODULE3(                    // ȡָ��
    .inst (inst),      // inst_romȡ����ָ��
    .IF3_valid (IF3_valid),  // ȡָ����Ч�ź�
    .IF2_IF3_bus_r (IF2_IF3_bus_r),
    .IF3_over (IF3_over),   // IFģ��ִ�����
    .IF_ID_bus (IF_ID_bus), // IF->ID����
        
    //չʾPC��ȡ����ָ��
    .IF3_pc (IF3_pc),
    .IF_inst (IF_inst)
    );

    decode ID_module(               // ���뼶
        .clk        (clk),
        .ID_valid   (ID_valid   ),  // I, 1
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        .rs_value_raw   (rs_value   ),  // I, 32
        .rt_value_raw   (rt_value   ),  // I, 32
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus_id   ),  // O, 33
//        .inst_jbr   (inst_jbr   ),  // O, 1
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        
        //5����ˮ����
        .IF_over     (IF1_over    ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .WB_wdest    (WB_wdest    ),// I, 5
        
        //��·ר��
        .MEM_RegWrite(MEM_RegWrite), 
        .MEM_data    (dm_addr), 
        .MEM_load    (MEM_load), //load-IDuse����ź�
        .load_MEM_data(dm_rdata), //load-IDuseר����· 
        
        //ð�ռ��ר��
        .EX_MemRead  (EX_MemRead), 
        .has_been_blocked (ID_blocked),
        .MEM_over    (MEM_over), 
        
        //չʾPC
        .ID_pc       (ID_pc       ) // O, 32
//        .rs_data     (exe_res), 
//        .rt_data     (alu_op_2)
    ); 

    exe EXE_module(                   // ִ�м�
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        //5����ˮ����
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ),  // O, 5
        
        //��·�����
        //MEM
        .MEM_RegWrite (MEM_RegWrite), 
        .MEM_wdest    (MEM_wdest), 
        //WB
        .WB_wdest     (WB_wdest), 
        .WB_RegWrite  (WB_RegWrite), 
        //����ͨ·
        .MEM_data     (dm_addr),      //==exe_result
        .WB_data      (rf_wdata),     //����Ҫд�ص�����
             
        //ð�ռ����
        .EX_MemRead   (EX_MemRead), 
        .jbr_bus      (jbr_bus_exe), 
        
        //չʾPC
        .EXE_pc      (EXE_pc      )   // O, 32
//        .realOp1     (exe_res), 
//        .realOp2     (alu_op_2)
    );

    mem MEM_module(                     // �ô漶
        .clk          (clk          ),  // I, 1 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .dm_rdata     (dm_rdata     ),  // I, 32
        .dm_addr      (dm_addr      ),  // O, 32
        .dm_wen       (dm_wen       ),  // O, 4 
        .dm_wdata     (dm_wdata     ),  // O, 32
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        
        //5����ˮ�����ӿ�
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest    (MEM_wdest    ),  // O, 5
        
        //��·ר��
        .RegWrite     (MEM_RegWrite), 
        .WB_RegWrite  (WB_RegWrite), 
        .WB_wdest     (WB_wdest), 
        .WB_data      (rf_wdata),     //����Ҫд�ص�����
        .MEM_load     (MEM_load), 
        
        //ð������
        .jbr_bus      (jbr_bus_mem), 
        
        //չʾPC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(                     // д�ؼ�
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        
        //5����ˮ�����ӿ�
        .clk         (clk         ),  // I, 1
      .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest    (WB_wdest    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        //��·ר��
         .regWrite   (WB_RegWrite), 
        
        //չʾPC��HI/LOֵ
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     )   // O, 32
    );

    inst_rom inst_rom_module(         // ָ��洢��
        .clka       (clk           ),  // I, 1 ,ʱ��
        .addra      (inst_addr[9:2]),  // I, 8 ,ָ���ַ
        .douta      (inst          )   // O, 32,ָ��
    );

    regfile rf_module(        // �Ĵ�����ģ��
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value ),  // O, 32

        //display rf
        .test_addr(rf_addr),  // I, 5
        .test_data(rf_data)   // O, 32
    );
    
    data_ram data_ram_module(   // ���ݴ洢ģ��
        .clka   (clk         ),  // I, 1,  ʱ��
        .wea    (dm_wen      ),  // I, 1,  дʹ��
        .addra  (dm_addr[9:2]),  // I, 8,  ����ַ
        .dina   (dm_wdata    ),  // I, 32, д����
        .douta  (dm_rdata    ),  // O, 32, ������

        //display mem
        .clkb   (clk          ),  // I, 1,  ʱ��
        .web    (4'd0         ),  // ��ʹ�ö˿�2��д����
        .addrb  (mem_addr[9:2]),  // I, 8,  ����ַ
        .doutb  (mem_data     ),  // I, 32, д����
        .dinb   (32'd0        )   // ��ʹ�ö˿�2��д����
    );
//--------------------------{��ģ��ʵ����}end----------------------------//
endmodule
