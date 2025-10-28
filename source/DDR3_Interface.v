`timescale 1ns/1ps

//DDR接口
module DDR3_Interface
#(  parameter MEM_ROW_ADDR_WIDTH   = 15  , //@IPC int 13,16
	parameter MEM_COL_ADDR_WIDTH   = 10  , //@IPC int 10,11
	parameter MEM_BADDR_WIDTH      = 3   ,
	parameter MEM_DQ_WIDTH         = 16  ,
	parameter MEM_DM_WIDTH         = MEM_DQ_WIDTH/8,
	parameter MEM_DQS_WIDTH        = MEM_DQ_WIDTH/8,
	parameter CTRL_ADDR_WIDTH      = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH,
	parameter BURST_LENGTH		   = 8,
	parameter BURST_NUM			   = 15,
	parameter BURST_WIDTH		   = 4,
	parameter DEVICE_NUM		   = 4
	
)
(
	input i_clk,
	input i_rstn,
	output o_pll_locked,
	output o_clk_100MHz,
	
	//-------------------外部写DDR控制总线------------------//
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
	
	//-------------------外部读DDR控制总线------------------//
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
	
	//---------------------DDR管脚信号----------------------//
	output o_ddr3_rstn,
	output o_ddr3_clk_p,
	output o_ddr3_clk_n,
	output o_ddr3_cke,
	output o_ddr3_cs,
	output o_ddr3_ras,
	output o_ddr3_cas,
	output o_ddr3_we,
	output o_ddr3_odt,
	output [MEM_ROW_ADDR_WIDTH - 1 : 0]o_ddr3_address,
	output [MEM_BADDR_WIDTH - 1 : 0]o_ddr3_ba,
	output [MEM_DM_WIDTH - 1 : 0]o_ddr3_dm,
	inout [MEM_DQS_WIDTH - 1 : 0]o_ddr3_dqs_p,
	inout [MEM_DQS_WIDTH - 1 : 0]o_ddr3_dqs_n,
	inout [MEM_DQ_WIDTH - 1 : 0]o_ddr3_dq
);
	//时钟
	wire clk_100MHz;
	wire pll_locked;
	
	//仲裁器信号
	wire init_ack;
	
	//写地址通道信号
	wire [CTRL_ADDR_WIDTH - 1:0]axi_awaddr;
	wire [BURST_WIDTH - 1:0]axi_awlen;
	wire axi_awready;
	wire axi_awvalid;
	
	//写地址数据信号
	wire [MEM_DQ_WIDTH * BURST_LENGTH - 1 : 0]axi_wdata;
	wire [MEM_DQ_WIDTH * BURST_LENGTH / 8 - 1 : 0]axi_wstrb;
	wire axi_wready;
	
	//读地址通道信号
	wire [CTRL_ADDR_WIDTH - 1:0]axi_araddr;
	wire [BURST_WIDTH - 1:0]axi_arlen;
	wire axi_arready;
	wire axi_arvalid;
	
	//读数据信号
	wire [MEM_DQ_WIDTH * BURST_LENGTH - 1 :0]axi_rdata;
	wire axi_rvalid;
	wire axi_rlast;
	
	//输出时钟连线
	assign o_pll_locked = pll_locked;
	assign o_clk_100MHz = clk_100MHz;
	
	//DDR写仲裁控制器实例化
	DDR_Arbitration_WR_Ctrl #(  .MEM_DQ_WIDTH(MEM_DQ_WIDTH),.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
								.BURST_LENGTH(BURST_LENGTH),.BURST_NUM(BURST_NUM),
								.BURST_WIDTH(BURST_WIDTH),.DEVICE_NUM(DEVICE_NUM))DDR_Arbitration_WR_Ctrl_Inst(
		.i_rstn(pll_locked),

		//----------------------外部控制总线--------------------//
		.o_mbus_wdata_rq(o_mbus_wdata_rq),						//写数据请求,上升沿代表开始需要写入数据
		.o_mbus_wbusy(o_mbus_wbusy),							//写忙信号,高电平代表忙碌
		.o_mbus_wsel(o_mbus_wsel),								//片选信号
		
		//外设0
		.i_mbus_wrq0(i_mbus_wrq0),								//写请求信号
		.i_mbus_waddr0(i_mbus_waddr0),    						//写初始地址信号
		.i_mbus_wdata0(i_mbus_wdata0),							//写数据
		.i_mbus_wready0(i_mbus_wready0),						//写数据准备好
		
		//外设1
		.i_mbus_wrq1(i_mbus_wrq1),								//写请求信号
		.i_mbus_waddr1(i_mbus_waddr1),    						//写初始地址信号
		.i_mbus_wdata1(i_mbus_wdata1),							//写数据
		.i_mbus_wready1(i_mbus_wready1),						//写数据准备好
		
		//外设2
		.i_mbus_wrq2(i_mbus_wrq2),								//写请求信号
		.i_mbus_waddr2(i_mbus_waddr2),    						//写初始地址信号
		.i_mbus_wdata2(i_mbus_wdata2),							//写数据
		.i_mbus_wready2(i_mbus_wready2),						//写数据准备好
		
		//外设3
		.i_mbus_wrq3(i_mbus_wrq3),								//写请求信号
		.i_mbus_waddr3(i_mbus_waddr3),    						//写初始地址信号
		.i_mbus_wdata3(i_mbus_wdata3),							//写数据
		.i_mbus_wready3(i_mbus_wready3),						//写数据准备好

			
		//-----------------------AXI4总线-----------------------//
		.i_axi_aclk(clk_100MHz),
		.i_init_ack(init_ack),									//DDRC初始化应答,高电平代表初始化完成
		
		//写地址通道
		.o_axi_awaddr(axi_awaddr),								//写地址*
		.o_axi_awlen(axi_awlen),								//突发长度*
		.o_axi_awvalid(axi_awvalid),							//写地址有效信号,有效时表示AWADDR上地址有效*
		.i_axi_awready(axi_awready),							//写从机就绪信号,有效时表示从机准备好接收地址*
		
		//写数据通道
		.o_axi_wdata(axi_wdata),								//写数据*
		.o_axi_wstrb(axi_wstrb),								//数据段有效,标记写数据中哪几个8位字段有效*
		.o_axi_wlast(axi_wlast),								//last信号,有效时表示当前位突发传输最后一个数据
		.o_axi_wvalid(axi_wvalid),								//写有效信号,有效时表示写数据有效
		.i_axi_wready(axi_wready),								//写ready信号,有效时表示从机准备好接收数据*
		
		//写响应通道
		.i_axi_bvalid(1'b1),									//写响应有效信号
		.o_axi_bready()											//写响应ready,主机准备好接收写响应信号
	);
	
	//DDR读仲裁控制器
	DDR_Arbitration_RD_Ctrl #(  .MEM_DQ_WIDTH(MEM_DQ_WIDTH),.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
								.BURST_LENGTH(BURST_LENGTH),.BURST_NUM(BURST_NUM),
								.BURST_WIDTH(BURST_WIDTH),.DEVICE_NUM(DEVICE_NUM))DDR_Arbitration_RD_Ctrl_Inst(
		
		.i_rstn(pll_locked),
		
		//----------------------外部控制总线--------------------//
		.o_mbus_rdata(o_mbus_rdata),							//读数据
		.o_mbus_rdata_rq(o_mbus_rdata_rq),						//读数据请求,上升沿代表开始需要读数据
		.o_mbus_rbusy(o_mbus_rbusy),							//读忙信号,高电平代表忙碌
		.o_mbus_rsel(o_mbus_rsel),								//片选信号
		
		//外设0
		.i_mbus_rrq0(i_mbus_rrq0),								//读请求信号
		.i_mbus_raddr0(i_mbus_raddr0),    						//读初始地址信号
		.i_mbus_rready0(i_mbus_rready0),						//读数据准备好
		
		//外设1
		.i_mbus_rrq1(i_mbus_rrq1),								//读请求信号
		.i_mbus_raddr1(i_mbus_raddr1),    						//读初始地址信号
		.i_mbus_rready1(i_mbus_rready1),						//读数据准备好
		
		//外设2
		.i_mbus_rrq2(i_mbus_rrq2),								//读请求信号
		.i_mbus_raddr2(i_mbus_raddr2),    						//读初始地址信号
		.i_mbus_rready2(i_mbus_rready2),						//读数据准备好
		
		//外设3
		.i_mbus_rrq3(i_mbus_rrq3),								//读请求信号
		.i_mbus_raddr3(i_mbus_raddr3),    						//读初始地址信号
		.i_mbus_rready3(i_mbus_rready3),						//读数据准备好
		
		//-----------------------AXI4总线-----------------------//
		.i_axi_aclk(clk_100MHz),
		.i_init_ack(init_ack),									//DDRC初始化应答,高电平代表初始化完成
		
		//读地址通道
		.o_axi_araddr(axi_araddr),								//读地址*
		.o_axi_arlen(axi_arlen),								//突发长度*
		.o_axi_arvalid(axi_arvalid),							//读地址有效信号,有效时表示AWADDR上地址有效*
		.i_axi_arready(axi_arready),							//写从机就绪信号,有效时表示从机准备好接收读地址*
		
		//读数据通道
		.i_axi_rdata(axi_rdata),								//读数据*
		.i_axi_rlast(axi_rlast),								//有效时表示当前位突发传输最后一个
		.i_axi_rvalid(axi_rvalid),								//读数据有效信号*
		.o_axi_rready(axi_rready)								//主机就绪信号,有效时表示
	);

	//DDR3物理层驱动实例化
	DDR3_Inst DDR3_Inst(
	   .ref_clk(i_clk),
	   .resetn(i_rstn),
	   .ddr_init_done(init_ack),
	   .ddrphy_clkin(clk_100MHz),
	   .pll_lock(pll_locked), 

	   .axi_awaddr(axi_awaddr),
	   .axi_awuser_ap(1'b0),
	   .axi_awuser_id(4'd0),
	   .axi_awlen(axi_awlen),
	   .axi_awready(axi_awready),
	   .axi_awvalid(axi_awvalid),

	   .axi_wdata(axi_wdata),
	   .axi_wstrb(axi_wstrb),
	   .axi_wready(axi_wready),
	   .axi_wusero_id(),
	   .axi_wusero_last(),

	   .axi_araddr(axi_araddr),
	   .axi_aruser_ap(1'b0),
	   .axi_aruser_id(4'd0),
	   .axi_arlen(axi_arlen),
	   .axi_arready(axi_arready),
	   .axi_arvalid(axi_arvalid),

	   .axi_rdata(axi_rdata),
	   .axi_rid(),
	   .axi_rlast(axi_rlast),
	   .axi_rvalid(axi_rvalid),

	   .apb_clk(1'b0),
	   .apb_rst_n(1'b0),
	   .apb_sel(1'b0),
	   .apb_enable(1'b0),
	   .apb_addr(8'd0),
	   .apb_write(1'b0),
	   .apb_ready(),
	   .apb_wdata(16'd0),
	   .apb_rdata(),
	   .apb_int(),
	   .debug_data(),

	   .mem_rst_n(o_ddr3_rstn),
	   .mem_ck(o_ddr3_clk_p),
	   .mem_ck_n(o_ddr3_clk_n),
	   .mem_cke(o_ddr3_cke),
	   .mem_cs_n(o_ddr3_cs),
	   .mem_ras_n(o_ddr3_ras),
	   .mem_cas_n(o_ddr3_cas),
	   .mem_we_n(o_ddr3_we),
	   .mem_odt(o_ddr3_odt),
	   .mem_a(o_ddr3_address),
	   .mem_ba(o_ddr3_ba),
	   .mem_dqs(o_ddr3_dqs_p),
	   .mem_dqs_n(o_ddr3_dqs_n),
	   .mem_dq(o_ddr3_dq),
	   .mem_dm(o_ddr3_dm)
	);
	
endmodule