`include "ctrl_encode_def.v"
module PLCPU(
    input      clk,            // clock
    input      reset,          // reset
    input [31:0]  inst_in,     // instruction
    input [31:0]  Data_in,     // data from data memory
    output [31:0] PC_out,     // PC address
    output [31:0] Addr_out,   // ALU output
    output [31:0] Data_out,   // data to data memory
    output    mem_w,          // output: memory write signal
    output    mem_r           // output: memory read signal
);
    // ========= 全局控制信号：由 ctrl 在译码阶段产生，随后跟随指令进入流水线 =========
    wire        RegWrite;    // control signal to register write
    wire [5:0]  EXTOp;      // control signal to signed extension
    wire [4:0]  ALUOp;       // ALU opertion
    wire [4:0]  NPCOp;       // next PC operation
    wire [1:0]  WDSel;       // (register) write data selection
   
    wire        ALUSrc;      // ALU source for B
    wire        Zero;        // ALU ouput zero

    wire [31:0] NPC;         // next PC

    wire [4:0]  rs1;          // rs
    wire [4:0]  rs2;          // rt
    wire [4:0]  rd;          // rd
    wire [6:0]  Op;          // opcode
    wire [6:0]  Funct7;       // funct7
    wire [2:0]  Funct3;       // funct3
    wire [11:0] Imm12;       // 12-bit immediate
    wire [31:0] Imm32;       // 32-bit immediate
    wire [19:0] IMM;         // 20-bit immediate (address)
    wire [4:0]  A3;          // register address for write
    reg [31:0] WD;           // register write data
    reg [31:0] memdata_wr;    // memory write data
    wire [31:0] RD1,RD2;         // register data specified by rs
    wire [31:0] A;            //operator for ALU A
    wire [31:0] B;           // operator for ALU B

    // ========= 指令立即数字段：从 32 位指令中拆出不同格式的立即数 =========
	wire [4:0] iimm_shamt;
	wire [11:0] iimm,simm,bimm;
	wire [19:0] uimm,jimm;
	wire [31:0] immout;
    wire [2:0] EX_DMType;
    wire [2:0] MEM_DMType;
	
	// ========= EX 阶段信号：ID/EX 流水寄存器输出，供 ALU 和 NPC 使用 =========
	wire [4:0] EX_rd;
    wire [4:0] EX_rs1;
    wire [4:0] EX_rs2;
    wire [31:0] EX_immout;
    wire [31:0] EX_RD1;
    wire [31:0] EX_RD2;
    wire        EX_RegWrite;//RFWr
    wire        EX_MemWrite;//DMWr
    wire        EX_MemRead;//DMRe
    wire [4:0] EX_ALUOp;
    wire [4:0] EX_NPCOp;
    wire       EX_ALUSrc;
    wire [1:0] EX_WDSel;
    wire [31:0] EX_pc;
	
	// ========= MEM 阶段信号：EX/MEM 流水寄存器输出，控制数据存储器访问 =========
	wire [4:0] MEM_rd;
	wire [4:0] MEM_rs2;
	wire [31:0] MEM_RD2;
	wire [31:0] MEM_aluout;
	wire        MEM_RegWrite;
	wire        MEM_MemWrite;
	wire        MEM_MemRead;
	wire [1:0] MEM_WDSel;

    assign mem_w = MEM_MemWrite;
    assign mem_r = MEM_MemRead;
    
    // ========= WB 阶段信号：MEM/WB 流水寄存器输出，用于写回寄存器堆 =========
    wire [4:0] WB_rd;
    wire [31:0] WB_aluout;
    wire [31:0] WB_MemData;
    wire        WB_RegWrite;
    wire [1:0]  WB_WDSel;
	wire [31:0] WB_pc;
	
    wire[31:0] aluout;
    assign Addr_out = MEM_aluout;
	assign Data_out = memdata_wr;
	
	wire [31:0] instr;
	
    // ========= ID 阶段取字段：把 IF/ID 中的指令拆成 opcode、寄存器编号和立即数 =========
	assign iimm_shamt=instr[24:20];
	assign iimm=instr[31:20];
	assign simm={instr[31:25],instr[11:7]};
	assign bimm={instr[31],instr[7],instr[30:25],instr[11:8]};
	assign uimm=instr[31:12];
	assign jimm={instr[31],instr[19:12],instr[20],instr[30:21]};
   
    assign Op = instr[6:0];  // instruction
    assign Funct7 = instr[31:25]; // funct7
    assign Funct3 = instr[14:12]; // funct3
    assign rs1 = instr[19:15];  // rs1
    assign rs2 = instr[24:20];  // rs2
    assign rd = instr[11:7];  // rd
    assign Imm12 = instr[31:20];// 12-bit immediate
    assign IMM = instr[31:12];  // 20-bit immediate
    
      
    wire ID_MemWrite; // MemWrite from ctrl in ID
    wire ID_MemRead; // MemRead from ctrl in ID

   // ========= 控制器：根据 opcode/funct3/funct7 译码，产生当前指令的控制信号 =========
	ctrl U_ctrl(
	    .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero), 
		.RegWrite(RegWrite), .MemWrite(ID_MemWrite), .MemRead(ID_MemRead),
		.EXTOp(EXTOp), .ALUOp(ALUOp), .NPCOp(NPCOp), 
		.ALUSrc(ALUSrc), .WDSel(WDSel)
	);
 // ========= PC 和 NPC：PC 保存取指地址，NPC 计算下一条指令地址 =========
	PC U_PC(.clk(~clk), .rst(reset), .NPC(NPC), .PC(PC_out) );
    // 分支和 jal 在 EX 阶段用 EX_pc + imm 计算目标地址；jalr 用 RS1(A) + imm。
	NPC U_NPC(.PC(PC_out), .NPCOp(EX_NPCOp),
	          .JumpPC(EX_pc), .IMM(EX_immout), .RS1(A), .NPC(NPC));
    // ========= 立即数扩展：把 I/S/B/U/J 型立即数扩展成 32 位 immout =========
	EXT U_EXT(
		.iimm(iimm), .simm(simm), .bimm(bimm),
		.uimm(uimm), .jimm(jimm), .EXTOp(EXTOp), .immout(immout)
	);
    // ========= 寄存器堆：ID 阶段读 rs1/rs2，WB 阶段把结果写回 rd =========
	RF U_RF(
		.clk(clk), .rst(reset),
		.RFWr(WB_RegWrite), 
		.A1(rs1), .A2(rs2), .A3(WB_rd), 
		.WD(WD), 
		.RD1(RD1), .RD2(RD2)
	);
// ========= ALU：EX 阶段执行算术逻辑运算，并给分支指令产生 Zero 条件 =========
	alu U_alu(.A(A), .B(B), .ALUOp(EX_ALUOp), .C(aluout), .Zero(Zero));
	
// ========= 数据转发 forwarding：解决相邻指令之间的寄存器数据相关 =========

    wire [31:0] mem_forward_value;
    wire [31:0] wb_forward_value;
    wire [31:0] forward_RD1;
    wire [31:0] forward_RD2;

    assign mem_forward_value =
        (MEM_WDSel == `WDSel_FromPC)  ? (EX_MEM_out[31:0] + 4) :
        (MEM_WDSel == `WDSel_FromMEM) ? Data_in :
                                         MEM_aluout;

    assign wb_forward_value =
        (WB_WDSel == `WDSel_FromPC)  ? (WB_pc + 4) :
        (WB_WDSel == `WDSel_FromMEM) ? WB_MemData :
                                       WB_aluout;

    assign forward_RD1 =
        (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs1)) ? mem_forward_value :
        (WB_RegWrite  && (WB_rd  != 5'b0) && (WB_rd  == EX_rs1)) ? wb_forward_value  :
                                                                   EX_RD1;

    assign forward_RD2 =
        (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs2)) ? mem_forward_value :
        (WB_RegWrite  && (WB_rd  != 5'b0) && (WB_rd  == EX_rs2)) ? wb_forward_value  :
                                                                   EX_RD2;

// ========= 写回数据选择：根据 WB_WDSel 选择 ALU、内存或 PC+4 写回寄存器 =========
always @(*)
begin
	case(WB_WDSel)
		`WDSel_FromALU: WD=WB_aluout;
		`WDSel_FromMEM: WD=WB_MemData;
		`WDSel_FromPC:  WD<=WB_pc+4;  
	endcase
end

// ========= ALU 输入选择：A/B 优先使用转发后的最新数据，B 可选择立即数 =========
    reg [31:0] alu_in1;  
    reg [31:0] alu_in2;  

    always @(*) 
    begin
        alu_in1 = forward_RD1; //from regfile or forwarding paths
        alu_in2 = forward_RD2; //from regfile or forwarding paths
    end
    
    always @(*) 
        memdata_wr = MEM_RD2;//from MEM
        
    assign A = alu_in1;
    assign B = (EX_ALUSrc) ? EX_immout : alu_in2;//whether from EXT

    // ========= 控制冒险处理：EX 阶段发现跳转/分支成立时，清空前面取错的指令 =========
    wire jump_flush;
    assign jump_flush = (EX_NPCOp != `NPC_PLUS4);

//-----pipe registers--------------

    // ========= IF/ID 流水寄存器：保存取指阶段得到的 PC 和指令 =========
    // IF_ID: [31:0] PC [31:0]instr
    wire [63:0] IF_ID_raw_in;
    wire [63:0] IF_ID_in;
    assign IF_ID_raw_in[31:0] = PC_out;//original addr of the current ins in ID, not PC+4
    assign IF_ID_raw_in[63:32] = inst_in;
    assign IF_ID_in = jump_flush ? 64'b0 : IF_ID_raw_in;

    wire [63:0] IF_ID_out;
    assign instr = IF_ID_out[63:32];
    pl_reg #(.WIDTH(64))
    IF_ID
    (.clk(~clk), .rst(reset), 
    .in(IF_ID_in), .out(IF_ID_out));


    // ========= ID/EX 流水寄存器：保存译码结果、寄存器读数、立即数和控制信号 =========
    wire [193:0] ID_EX_raw_in;
    wire [193:0] ID_EX_in;
    assign ID_EX_raw_in[31:0] = IF_ID_out[31:0];//PC
    assign ID_EX_raw_in[36:32] = rd;
    assign ID_EX_raw_in[41:37] = rs1;
    assign ID_EX_raw_in[46:42] = rs2;
    assign ID_EX_raw_in[78:47] = immout;
    assign ID_EX_raw_in[110:79] = RD1;
    assign ID_EX_raw_in[142:111] = RD2;
    assign ID_EX_raw_in[143] = RegWrite;//RFWr
    assign ID_EX_raw_in[144] = ID_MemWrite;//DMWr
    assign ID_EX_raw_in[149:145] = ALUOp;
    assign ID_EX_raw_in[154:150] = NPCOp;
    assign ID_EX_raw_in[155] = ALUSrc;
    assign ID_EX_raw_in[158:156] = 3'b000;  //nop, reserved for mem access
    assign ID_EX_raw_in[160:159] = WDSel;
    assign ID_EX_raw_in[161] = ID_MemRead;
    assign ID_EX_raw_in[193:162] = IF_ID_out[63:32];
    assign ID_EX_in = jump_flush ? 194'b0 : ID_EX_raw_in;

    wire [193:0] ID_EX_out;
    //wire [31:0] EX_inst;
    assign EX_rd = ID_EX_out[36:32];
    assign EX_rs1 = ID_EX_out[41:37];
    assign EX_rs2 = ID_EX_out[46:42];
    assign EX_immout = ID_EX_out[78:47];
    assign EX_RD1 = ID_EX_out[110:79];
    assign EX_RD2 = ID_EX_out[142:111];
    assign EX_RegWrite = ID_EX_out[143];//RFWr
    assign EX_MemWrite = ID_EX_out[144];//DMWr
    assign EX_ALUOp = ID_EX_out[149:145];
    assign EX_NPCOp = {ID_EX_out[154:151], ID_EX_out[150] & Zero};
    assign EX_ALUSrc = ID_EX_out[155];
    assign EX_DMType = ID_EX_out[158:156];
    assign EX_WDSel = ID_EX_out[160:159];
    assign EX_MemRead = ID_EX_out[161];
    assign EX_pc = ID_EX_out[31:0];
    //assign EX_inst = ID_EX_out[193:162];
    
    pl_reg #(.WIDTH(194))
    ID_EX
    (.clk(~clk), .rst(reset), 
    .in(ID_EX_in), .out(ID_EX_out));

    
    // ========= EX/MEM 流水寄存器：保存 ALU 结果、写内存数据和访存控制信号 =========
    wire [145:0] EX_MEM_in;
    assign EX_MEM_in[31:0] = ID_EX_out[31:0];//PC
    assign EX_MEM_in[36:32] = EX_rd;//rd
    assign EX_MEM_in[68:37] = alu_in2;//RD2 updated!!!
    assign EX_MEM_in[100:69] = aluout;
    assign EX_MEM_in[101] = EX_RegWrite;
    assign EX_MEM_in[102] = EX_MemWrite;
    assign EX_MEM_in[105:103] = EX_DMType;
    assign EX_MEM_in[107:106] = EX_WDSel;
    assign EX_MEM_in[112:108] = EX_rs2;
    assign EX_MEM_in[113] = EX_MemRead;
    assign EX_MEM_in[145:114] = ID_EX_out[193:162];

    wire [145:0] EX_MEM_out;
    assign MEM_rd = EX_MEM_out[36:32];
    assign MEM_RD2 = EX_MEM_out[68:37];
    assign MEM_aluout = EX_MEM_out[100:69];
    assign MEM_RegWrite = EX_MEM_out[101];
    assign MEM_MemWrite = EX_MEM_out[102];
    assign MEM_DMType = EX_MEM_out[105:103];
    assign MEM_WDSel = EX_MEM_out[107:106];
    assign MEM_rs2 = EX_MEM_out[112:108];
    assign MEM_MemRead = EX_MEM_out[113];  
    //assign MEM_inst = EX_MEM_out[145:114];  
 
    pl_reg #(.WIDTH(146))
    EX_MEM
    (.clk(~clk), .rst(reset), 
    .in(EX_MEM_in), .out(EX_MEM_out));
    

    // ========= MEM/WB 流水寄存器：保存访存读出数据和最终写回控制信号 =========
    wire [135:0] MEM_WB_in;
    wire [31:0] WB_inst;
    assign MEM_WB_in[31:0] = EX_MEM_out[31:0]; //PC
    assign MEM_WB_in[36:32] = MEM_rd;
    assign MEM_WB_in[68:37] = MEM_aluout;
    assign MEM_WB_in[100:69] = Data_in;  //data from dmem
    assign MEM_WB_in[101] = MEM_RegWrite;
    assign MEM_WB_in[103:102] = MEM_WDSel;
    assign MEM_WB_in[135:104] = EX_MEM_out[145:114];
 
    wire [135:0] MEM_WB_out;
    assign WB_pc = MEM_WB_out[31:0];
    assign WB_rd = MEM_WB_out[36:32];
    assign WB_aluout = MEM_WB_out[68:37];
    assign WB_MemData = MEM_WB_out[100:69];
    assign WB_RegWrite = MEM_WB_out[101];
    assign WB_WDSel = MEM_WB_out[103:102];
    assign WB_inst = MEM_WB_out[135:104];

    pl_reg #(.WIDTH(136))
    MEM_WB
    (.clk(~clk), .rst(reset), 
    .in(MEM_WB_in), .out(MEM_WB_out));

endmodule
