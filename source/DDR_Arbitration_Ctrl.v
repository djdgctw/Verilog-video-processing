`timescale 1ns/1ps

//DDR写仲裁控制器
module DDR_Arbitration_WR_Ctrl
#(  parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter BURST_NUM			   = 15,
	parameter BURST_WIDTH		   = 4,
	parameter DEVICE_NUM		   = 4
)
(
	input i_rstn,

	//----------------------外部控制总线--------------------//
	output o_mbus_wdata_rq,									//写数据请求,上升沿代表开始需要写入数据
	output o_mbus_wbusy,									//写忙信号,高电平代表忙碌
	output [DEVICE_NUM - 1:0]o_mbus_wsel,					//片选信号
	
	//外设0
	input i_mbus_wrq0,										//写请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_waddr0,    			//写初始地址信号
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_wdata0,	//写数据
	input i_mbus_wready0,									//写数据准备好
	
	//外设1
	input i_mbus_wrq1,										//写请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_waddr1,    			//写初始地址信号
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_wdata1,	//写数据
	input i_mbus_wready1,									//写数据准备好
	
	//外设2
	input i_mbus_wrq2,										//写请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_waddr2,    			//写初始地址信号
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_wdata2,	//写数据
	input i_mbus_wready2,									//写数据准备好
	
	//外设3
	input i_mbus_wrq3,										//写请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_waddr3,    			//写初始地址信号
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_wdata3,	//写数据
	input i_mbus_wready3,									//写数据准备好

		
	//-----------------------AXI4总线-----------------------//
	input i_axi_aclk,
	input i_init_ack,										//DDRC初始化应答,高电平代表初始化完成
	
	//写地址通道
	output [CTRL_ADDR_WIDTH - 1:0]o_axi_awaddr,				//写地址*
	output [BURST_WIDTH - 1:0]o_axi_awlen,					//突发长度*
	output o_axi_awvalid,									//写地址有效信号,有效时表示AWADDR上地址有效*
	input i_axi_awready,									//写从机就绪信号,有效时表示从机准备好接收地址*
	
	//写数据通道
	output [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]o_axi_wdata,	//写数据*
	output [MEM_DQ_WIDTH * BURST_LENGTH/8 - 1:0]o_axi_wstrb,//数据段有效,标记写数据中哪几个8位字段有效*
	output o_axi_wlast,										//last信号,有效时表示当前位突发传输最后一个数据
	output o_axi_wvalid,									//写有效信号,有效时表示写数据有效
	input i_axi_wready,										//写ready信号,有效时表示从机准备好接收数据*
	
	//写响应通道
	input i_axi_bvalid,										//写响应有效信号
	output o_axi_bready										//写响应ready,主机准备好接收写响应信号
);
	//状态参数
	localparam ST_WR_IDLE = 2'd0;
	localparam ST_WR_WAIT = 2'd1;
	localparam ST_WR_START = 2'd2;
	localparam ST_WR_END = 2'd3;
	
	//状态
	reg [1:0]state_current = 0;
	reg [1:0]state_next = 0;
	
	//设备编码
	wire [DEVICE_NUM - 1:0]device_encoder;
	
	//DDR写控制信号
	reg mbus_wrq = 0;
	reg [CTRL_ADDR_WIDTH - 1:0]mbus_waddr = 0;
	reg [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]mbus_wdata = 0;
	
	//其他缓存信号
	reg [DEVICE_NUM - 1:0]device_encoder_buff = 0;
	
	//输出信号
	reg [DEVICE_NUM - 1:0]mbus_wsel_o = 0;
	
	//设备编码连线
	assign device_encoder[0] = (i_mbus_wrq0 == 1'b1) && (i_mbus_wready0 == 1'b1);
	assign device_encoder[1] = (i_mbus_wrq1 == 1'b1) && (i_mbus_wready1 == 1'b1);
	assign device_encoder[2] = (i_mbus_wrq2 == 1'b1) && (i_mbus_wready2 == 1'b1);
	assign device_encoder[3] = (i_mbus_wrq3 == 1'b1) && (i_mbus_wready3 == 1'b1);
	
	//片选信号输出
	assign o_mbus_wsel = mbus_wsel_o;
	
	//片选信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wsel_o <= {DEVICE_NUM{1'b0}};
		else if(device_encoder_buff[0] == 1'b1)mbus_wsel_o <= {DEVICE_NUM{1'b0}} + 1'b1;
		else if(device_encoder_buff[1] == 1'b1)mbus_wsel_o <= {DEVICE_NUM{1'b0}} + 2'b10;
		else if(device_encoder_buff[2] == 1'b1)mbus_wsel_o <= {DEVICE_NUM{1'b0}} + 3'b100;
		else if(device_encoder_buff[3] == 1'b1)mbus_wsel_o <= {DEVICE_NUM{1'b0}} + 4'b1000;
		else mbus_wsel_o <= {DEVICE_NUM{1'b0}};
	end
	
	//主状态机
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(i_init_ack == 1'b1)state_next <= ST_WR_WAIT;
				else state_next <= ST_WR_IDLE;
			end
			ST_WR_WAIT:begin
				if(device_encoder == {DEVICE_NUM{1'b0}})state_next <= ST_WR_WAIT;
				else state_next <= ST_WR_START;
			end
			ST_WR_START:begin
				if(o_mbus_wbusy == 1'b1)state_next <= ST_WR_END;
				else state_next <= ST_WR_START;
			end
			ST_WR_END:begin
				if(o_mbus_wbusy == 1'b0)state_next <= ST_WR_WAIT;
				else state_next <= ST_WR_END;
			end
		endcase
	end
	
	//状态转换
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= 2'd0;
		end else begin
			state_current <= state_next;
		end
	end
	
	//DDR写请求
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wrq <= 1'b0;
		else if(state_current == ST_WR_START)mbus_wrq <= 1'b1;
		else mbus_wrq <= 1'b0; 
	end
	
	//DDR写地址
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_waddr <= {CTRL_ADDR_WIDTH{1'b0}};
		else if(state_current == ST_WR_START && device_encoder_buff[0] == 1'b1)mbus_waddr <= i_mbus_waddr0;
		else if(state_current == ST_WR_START && device_encoder_buff[1] == 1'b1)mbus_waddr <= i_mbus_waddr1;
		else if(state_current == ST_WR_START && device_encoder_buff[2] == 1'b1)mbus_waddr <= i_mbus_waddr2;
		else if(state_current == ST_WR_START && device_encoder_buff[3] == 1'b1)mbus_waddr <= i_mbus_waddr3;
		else mbus_waddr <= mbus_waddr;
	end
	
	//DDR写数据
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wdata <= {(MEM_DQ_WIDTH * BURST_LENGTH){1'b0}};
		else if(state_current == ST_WR_END && device_encoder_buff[0] == 1'b1)mbus_wdata <= i_mbus_wdata0;
		else if(state_current == ST_WR_END && device_encoder_buff[1] == 1'b1)mbus_wdata <= i_mbus_wdata1;
		else if(state_current == ST_WR_END && device_encoder_buff[2] == 1'b1)mbus_wdata <= i_mbus_wdata2;
		else if(state_current == ST_WR_END && device_encoder_buff[3] == 1'b1)mbus_wdata <= i_mbus_wdata3;
		else mbus_wdata <= {(MEM_DQ_WIDTH * BURST_LENGTH){1'b0}};
	end
	
	//DDR写控制模块实例化
	DDR_WR_Ctrl #(  .MEM_DQ_WIDTH(MEM_DQ_WIDTH),.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
					.BURST_LENGTH(BURST_LENGTH),.BURST_NUM(BURST_NUM),.BURST_WIDTH(BURST_WIDTH))DDR_WR_Ctrl_Inst(
		.i_rstn(i_rstn),
		
		//-----------------------AXI4总线-----------------------//
		.i_axi_aclk(i_axi_aclk),
		
		//写地址通道
		.o_axi_awaddr(o_axi_awaddr),						//写地址*
		.o_axi_awlen(o_axi_awlen),							//突发长度*
		.o_axi_awvalid(o_axi_awvalid),						//写地址有效信号,有效时表示AWADDR上地址有效*
		.i_axi_awready(i_axi_awready),						//写从机就绪信号,有效时表示从机准备好接收地址*
		
		//写数据通道
		.o_axi_wdata(o_axi_wdata),							//写数据*
		.o_axi_wstrb(o_axi_wstrb),							//数据段有效,标记写数据中哪几个8位字段有效*
		.o_axi_wlast(o_axi_wlast),							//last信号,有效时表示当前位突发传输最后一个数据
		.o_axi_wvalid(o_axi_wvalid),						//写有效信号,有效时表示写数据有效
		.i_axi_wready(i_axi_wready),						//写ready信号,有效时表示从机准备好接收数据*
		
		//写响应通道
		.i_axi_bvalid(i_axi_bvalid),						//写响应有效信号
		.o_axi_bready(o_axi_bready),						//写响应ready,主机准备好接收写响应信号
		
		//----------------------外部控制总线--------------------//
		.i_mbus_wrq(mbus_wrq),								//写请求信号
		.i_mbus_waddr(mbus_waddr),    						//写初始地址信号
		.i_mbus_wdata(mbus_wdata),							//写数据
		.o_mbus_wdata_rq(o_mbus_wdata_rq),					//写数据请求,上升沿代表开始需要写入数据
		.o_mbus_wbusy(o_mbus_wbusy)							//写忙信号,高电平代表忙碌
	);
	
	//其他信号缓存
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			device_encoder_buff <= {DEVICE_NUM{1'b0}};
		end else if(state_current == ST_WR_WAIT)begin
			device_encoder_buff <= device_encoder;
		end else if(state_current == ST_WR_END && o_mbus_wbusy == 1'b0)begin
			device_encoder_buff <= {DEVICE_NUM{1'b0}};
		end else begin
			device_encoder_buff <= device_encoder_buff;
		end
	end
	
endmodule

//DDR读仲裁控制器
module DDR_Arbitration_RD_Ctrl
#(  parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter BURST_NUM			   = 15,
	parameter BURST_WIDTH		   = 4,
	parameter DEVICE_NUM		   = 4
)
(
	
	input i_rstn,
	
	//----------------------外部控制总线--------------------//
	output [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]o_mbus_rdata,	//读数据
	output o_mbus_rdata_rq,									//读数据请求,上升沿代表开始需要读数据
	output o_mbus_rbusy,									//读忙信号,高电平代表忙碌
	output [DEVICE_NUM - 1:0]o_mbus_rsel,					//片选信号
	
	//外设0
	input i_mbus_rrq0,										//读请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_raddr0,    			//读初始地址信号
	input i_mbus_rready0,									//读数据准备好
	
	//外设1
	input i_mbus_rrq1,										//读请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_raddr1,    			//读初始地址信号
	input i_mbus_rready1,									//读数据准备好
	
	//外设2
	input i_mbus_rrq2,										//读请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_raddr2,    			//读初始地址信号
	input i_mbus_rready2,									//读数据准备好
	
	//外设3
	input i_mbus_rrq3,										//读请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_raddr3,    			//读初始地址信号
	input i_mbus_rready3,									//读数据准备好
	
	//-----------------------AXI4总线-----------------------//
	input i_axi_aclk,
	input i_init_ack,										//DDRC初始化应答,高电平代表初始化完成
	
	//读地址通道
	output [CTRL_ADDR_WIDTH - 1:0]o_axi_araddr,				//读地址*
	output [BURST_WIDTH - 1:0]o_axi_arlen,					//突发长度*
	output o_axi_arvalid,									//读地址有效信号,有效时表示AWADDR上地址有效*
	input i_axi_arready,									//写从机就绪信号,有效时表示从机准备好接收读地址*
	
	//读数据通道
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_axi_rdata,	//读数据*
	input i_axi_rlast,										//有效时表示当前位突发传输最后一个
	input i_axi_rvalid,										//读数据有效信号*
	output o_axi_rready										//主机就绪信号,有效时表示
);
	
	//状态参数
	localparam ST_RD_IDLE = 2'd0;
	localparam ST_RD_WAIT = 2'd1;
	localparam ST_RD_START = 2'd2;
	localparam ST_RD_END = 2'd3;
	
	//状态
	reg [1:0]state_current = 0;
	reg [1:0]state_next = 0;
	
	//设备编码
	wire [DEVICE_NUM - 1:0]device_encoder;
	
	//DDR读控制信号
	reg mbus_rrq = 0;
	reg [CTRL_ADDR_WIDTH - 1:0]mbus_raddr = 0;
	
	//其他缓存信号
	reg [DEVICE_NUM - 1:0]device_encoder_buff = 0;
	
	//输出信号
	reg [DEVICE_NUM - 1:0]mbus_rsel_o = 0;
	
	//设备编码连线
	assign device_encoder[0] = (i_mbus_rrq0 == 1'b1) && (i_mbus_rready0 == 1'b1);
	assign device_encoder[1] = (i_mbus_rrq1 == 1'b1) && (i_mbus_rready1 == 1'b1);
	assign device_encoder[2] = (i_mbus_rrq2 == 1'b1) && (i_mbus_rready2 == 1'b1);
	assign device_encoder[3] = (i_mbus_rrq3 == 1'b1) && (i_mbus_rready3 == 1'b1);
	
	//片选信号输出
	assign o_mbus_rsel = mbus_rsel_o;
	
	//片选信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rsel_o <= {DEVICE_NUM{1'b0}};
		else if(device_encoder_buff[0] == 1'b1)mbus_rsel_o <= {DEVICE_NUM{1'b0}} + 1'b1;
		else if(device_encoder_buff[1] == 1'b1)mbus_rsel_o <= {DEVICE_NUM{1'b0}} + 2'b10;
		else if(device_encoder_buff[2] == 1'b1)mbus_rsel_o <= {DEVICE_NUM{1'b0}} + 3'b100;
		else if(device_encoder_buff[3] == 1'b1)mbus_rsel_o <= {DEVICE_NUM{1'b0}} + 4'b1000;
		else mbus_rsel_o <= {DEVICE_NUM{1'b0}};
	end
	
	//主状态机
	always@(*)begin
		case(state_current)
			ST_RD_IDLE:begin
				if(i_init_ack == 1'b1)state_next <= ST_RD_WAIT;
				else state_next <= ST_RD_IDLE;
			end
			ST_RD_WAIT:begin
				if(device_encoder == {DEVICE_NUM{1'b0}})state_next <= ST_RD_WAIT;
				else state_next <= ST_RD_START;
			end
			ST_RD_START:begin
				if(o_mbus_rbusy == 1'b1)state_next <= ST_RD_END;
				else state_next <= ST_RD_START;
			end
			ST_RD_END:begin
				if(o_mbus_rbusy == 1'b0)state_next <= ST_RD_WAIT;
				else state_next <= ST_RD_END;
			end
		endcase
	end
	
	//状态转换
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= 2'd0;
		end else begin
			state_current <= state_next;
		end
	end
	
	//DDR读请求
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rrq <= 1'b0;
		else if(state_current == ST_RD_START)mbus_rrq <= 1'b1;
		else mbus_rrq <= 1'b0; 
	end
	
	//DDR读地址
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_raddr <= {CTRL_ADDR_WIDTH{1'b0}};
		else if(state_current == ST_RD_START && device_encoder_buff[0] == 1'b1)mbus_raddr <= i_mbus_raddr0;
		else if(state_current == ST_RD_START && device_encoder_buff[1] == 1'b1)mbus_raddr <= i_mbus_raddr1;
		else if(state_current == ST_RD_START && device_encoder_buff[2] == 1'b1)mbus_raddr <= i_mbus_raddr2;
		else if(state_current == ST_RD_START && device_encoder_buff[3] == 1'b1)mbus_raddr <= i_mbus_raddr3;
		else mbus_raddr <= mbus_raddr;
	end
	
	//DDR读控制模块实例化
	DDR_RD_Ctrl #(  .MEM_DQ_WIDTH(MEM_DQ_WIDTH),.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
					.BURST_LENGTH(BURST_LENGTH),.BURST_NUM(BURST_NUM),.BURST_WIDTH(BURST_WIDTH))DDR_RD_Ctrl_Inst(
		.i_rstn(i_rstn),
		
		//-----------------------AXI4总线-----------------------//
		.i_axi_aclk(i_axi_aclk),
		
		//读地址通道
		.o_axi_araddr(o_axi_araddr),							//读地址*
		.o_axi_arlen(o_axi_arlen),								//突发长度*
		.o_axi_arvalid(o_axi_arvalid),							//读地址有效信号,有效时表示AWADDR上地址有效*
		.i_axi_arready(i_axi_arready),							//写从机就绪信号,有效时表示从机准备好接收读地址*
		
		//读数据通道
		.i_axi_rdata(i_axi_rdata),								//读数据*
		.i_axi_rlast(i_axi_rlast),								//有效时表示当前位突发传输最后一个
		.i_axi_rvalid(i_axi_rvalid),							//读数据有效信号*
		.o_axi_rready(o_axi_rready),							//主机就绪信号,有效时表示
		
		//----------------------外部控制总线--------------------//
		.i_mbus_rrq(mbus_rrq),									//读请求信号
		.i_mbus_raddr(mbus_raddr),    							//读初始地址信号
		.o_mbus_rdata(o_mbus_rdata),							//读数据
		.o_mbus_rdata_rq(o_mbus_rdata_rq),						//读数据请求,上升沿代表开始需要读数据
		.o_mbus_rbusy(o_mbus_rbusy)								//读忙信号,高电平代表忙碌
	);
	
	//其他信号缓存
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			device_encoder_buff <= {DEVICE_NUM{1'b0}};
		end else if(state_current == ST_RD_WAIT)begin
			device_encoder_buff <= device_encoder;
		end else if(state_current == ST_RD_END && o_mbus_rbusy == 1'b0)begin
			device_encoder_buff <= {DEVICE_NUM{1'b0}};
		end else begin
			device_encoder_buff <= device_encoder_buff;
		end
	end
endmodule