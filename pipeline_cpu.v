`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: pipeline_cpu.v
//   > 描述  :五级流水CPU模块，共实现XX条指令
//   >        指令rom和数据ram均实例化xilinx IP得到，为同步读写
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module pipeline_cpu(  // 多周期cpu
    input clk,           // 时钟
    input resetn,        // 复位信号，低电平有效
    
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
    
    //5级流水新增
    output [31:0] cpu_5_valid,
    output [31:0] HI_data,
    output [31:0] LO_data
    );
    assign exe_res = rf_wdata;//dm_wdata;
    assign alu_op_2 = dm_wdata;
//------------------------{5级流水控制信号}begin-------------------------//
    //5模块的valid信号
    reg IF1_valid;
    reg IF2_valid;
    reg IF3_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5模块执行完成信号,来自各模块的输出
    wire IF1_over;
    wire IF2_over;
    wire IF3_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;
    //5模块允许下一级指令进入
    wire IF1_allow_in;
    wire IF2_allow_in;
    wire IF3_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    // syscall和eret到达写回级时会发出cancel信号，
    wire cancel;    // 取消已经取出的正在其他流水级执行的指令
    //冒险检测单元：分支预测失败
    wire flush;
    wire ID_blocked;
    wire MEM_load;
    assign _flush = flush;
    assign _jbr = jbr_bus[32];
    
    //各级允许进入信号:本级无效，或本级执行完成且下级允许进入
    assign IF1_allow_in  = (IF1_over & IF2_allow_in) | cancel;
    assign IF2_allow_in  = ~IF2_valid  | (IF2_over  & IF3_allow_in);
    assign IF3_allow_in  = ~IF3_valid  | (IF3_over  & ID_allow_in);
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid，在复位后，一直有效
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
        if (!resetn || cancel || (flush & ~ID_blocked))//上周期没阻塞，只flush IF2、IF3，ID留给延迟槽；上周阻塞过，保留IF2给延迟槽
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
        if (!resetn || cancel || (flush & ID_over & ID_blocked)) //上周期阻塞过，且为跳转指令，ID flush
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
    
    //展示5级的valid信号
    assign cpu_5_valid = {4'd0         ,{4{IF1_valid }},{4{IF2_valid }},{4{IF3_valid }},{4{ID_valid}},
                          {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
//-------------------------{5级流水控制信号}end--------------------------//

//--------------------------{5级间的总线}begin---------------------------//
    wire [ 32:0] IF1_IF2_bus;
    wire [ 32:0] IF2_IF3_bus;
    wire [ 63:0] IF_ID_bus;   // IF->ID级总线
    wire [178:0] ID_EXE_bus;  // ID->EXE级总线
    wire [158:0] EXE_MEM_bus; // EXE->MEM级总线
    wire [117:0] MEM_WB_bus;  // MEM->WB级总线
    
    //锁存以上总线信号
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
    //IF到ID的锁存信号
    always @(posedge clk)
    begin
        if(IF3_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID到EXE的锁存信号
    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE到MEM的锁存信号
    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM到WB的锁存信号
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
//---------------------------{5级间的总线}end----------------------------//

//--------------------------{其他交互信号}begin--------------------------//
    //跳转总线
    wire [ 32:0] jbr_bus;    
    wire [ 32:0] jbr_bus_id;
    wire [ 32:0] jbr_bus_mem;
    wire [ 32:0] jbr_bus_exe;
    assign jbr_bus = jbr_bus_id[32] ? jbr_bus_id : jbr_bus_mem;
                     //jbr_bus_mem[32]? jbr_bus_mem : jbr_bus_exe;

    //IF与inst_rom交互
    wire [31:0] inst_addr;
    wire [31:0] inst;

    //ID与EXE、MEM、WB交互
    wire [ 4:0] EXE_wdest;
    wire [ 4:0] MEM_wdest;
    wire [ 4:0] WB_wdest;
    
    //MEM与data_ram交互    
    wire [ 3:0] dm_wen;
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;

    //ID与regfile交互
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB与regfile交互
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;    
    
    //WB与IF间的交互信号
    wire [32:0] exc_bus;
    
    //旁路检测专用
    wire        MEM_RegWrite;
    wire        WB_RegWrite;
    
    //冒险检测专用
    wire        EX_MemRead;
    
//----------------------------{旁路}-------------------------------------//
    //wire
    
//---------------------------{其他交互信号}end---------------------------//

//-------------------------{各模块实例化}begin---------------------------//
    wire next_fetch; //即将运行取指模块，需要先锁存PC值
    //IF允许进入时，即锁存PC值，取下一条指令
    assign next_fetch = IF1_allow_in;
    fetch1 IF_MODULE1(             // 取指级
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF1_valid  (IF1_valid  ),  // I, 1
        .next_fetch(next_fetch),  // I, 1
        .jbr_bus   (jbr_bus   ),  // I, 33
        .inst_addr (inst_addr ),  // O, 32
        .IF1_over   (IF1_over   ),  // O, 1
        .IF1_IF2_bus (IF1_IF2_bus ),  // O, 31
        .flush (flush), 
        
        //5级流水新增接口
        .exc_bus   (exc_bus   ),  // I, 32
        
        //展示PC和取出的指令
        .IF1_pc     (IF1_pc     )  // O, 32
    );
    
    fetch2 IF_MODULE2(                    // 取指级
        .IF2_valid (IF2_valid),  // 取指级有效信号
        .IF_IF2_bus_r (IF1_IF2_bus_r),
        .IF2_over (IF2_over),  // 取指级有效信号
        .IF2_IF3_bus (IF2_IF3_bus), // IF->ID总线
            
        //展示PC和取出的指令
        .IF2_pc (IF2_pc)
    );

    fetch3 IF_MODULE3(                    // 取指级
    .inst (inst),      // inst_rom取出的指令
    .IF3_valid (IF3_valid),  // 取指级有效信号
    .IF2_IF3_bus_r (IF2_IF3_bus_r),
    .IF3_over (IF3_over),   // IF模块执行完成
    .IF_ID_bus (IF_ID_bus), // IF->ID总线
        
    //展示PC和取出的指令
    .IF3_pc (IF3_pc),
    .IF_inst (IF_inst)
    );

    decode ID_module(               // 译码级
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
        
        //5级流水新增
        .IF_over     (IF1_over    ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .WB_wdest    (WB_wdest    ),// I, 5
        
        //旁路专用
        .MEM_RegWrite(MEM_RegWrite), 
        .MEM_data    (dm_addr), 
        .MEM_load    (MEM_load), //load-IDuse检测信号
        .load_MEM_data(dm_rdata), //load-IDuse专用旁路 
        
        //冒险检测专用
        .EX_MemRead  (EX_MemRead), 
        .has_been_blocked (ID_blocked),
        .MEM_over    (MEM_over), 
        
        //展示PC
        .ID_pc       (ID_pc       ) // O, 32
//        .rs_data     (exe_res), 
//        .rt_data     (alu_op_2)
    ); 

    exe EXE_module(                   // 执行级
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        //5级流水新增
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ),  // O, 5
        
        //旁路检测用
        //MEM
        .MEM_RegWrite (MEM_RegWrite), 
        .MEM_wdest    (MEM_wdest), 
        //WB
        .WB_wdest     (WB_wdest), 
        .WB_RegWrite  (WB_RegWrite), 
        //数据通路
        .MEM_data     (dm_addr),      //==exe_result
        .WB_data      (rf_wdata),     //就是要写回的数据
             
        //冒险检测用
        .EX_MemRead   (EX_MemRead), 
        .jbr_bus      (jbr_bus_exe), 
        
        //展示PC
        .EXE_pc      (EXE_pc      )   // O, 32
//        .realOp1     (exe_res), 
//        .realOp2     (alu_op_2)
    );

    mem MEM_module(                     // 访存级
        .clk          (clk          ),  // I, 1 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .dm_rdata     (dm_rdata     ),  // I, 32
        .dm_addr      (dm_addr      ),  // O, 32
        .dm_wen       (dm_wen       ),  // O, 4 
        .dm_wdata     (dm_wdata     ),  // O, 32
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        
        //5级流水新增接口
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest    (MEM_wdest    ),  // O, 5
        
        //旁路专用
        .RegWrite     (MEM_RegWrite), 
        .WB_RegWrite  (WB_RegWrite), 
        .WB_wdest     (WB_wdest), 
        .WB_data      (rf_wdata),     //就是要写回的数据
        .MEM_load     (MEM_load), 
        
        //冒险阻塞
        .jbr_bus      (jbr_bus_mem), 
        
        //展示PC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(                     // 写回级
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        
        //5级流水新增接口
        .clk         (clk         ),  // I, 1
      .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest    (WB_wdest    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        //旁路专用
         .regWrite   (WB_RegWrite), 
        
        //展示PC和HI/LO值
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     )   // O, 32
    );

    inst_rom inst_rom_module(         // 指令存储器
        .clka       (clk           ),  // I, 1 ,时钟
        .addra      (inst_addr[9:2]),  // I, 8 ,指令地址
        .douta      (inst          )   // O, 32,指令
    );

    regfile rf_module(        // 寄存器堆模块
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
    
    data_ram data_ram_module(   // 数据存储模块
        .clka   (clk         ),  // I, 1,  时钟
        .wea    (dm_wen      ),  // I, 1,  写使能
        .addra  (dm_addr[9:2]),  // I, 8,  读地址
        .dina   (dm_wdata    ),  // I, 32, 写数据
        .douta  (dm_rdata    ),  // O, 32, 读数据

        //display mem
        .clkb   (clk          ),  // I, 1,  时钟
        .web    (4'd0         ),  // 不使用端口2的写功能
        .addrb  (mem_addr[9:2]),  // I, 8,  读地址
        .doutb  (mem_data     ),  // I, 32, 写数据
        .dinb   (32'd0        )   // 不使用端口2的写功能
    );
//--------------------------{各模块实例化}end----------------------------//
endmodule
