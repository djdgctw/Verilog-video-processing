`timescale 1ns / 1ps

module Lab8_DDR_HDMI_Loop
#(  
	parameter MEM_ROW_ADDR_WIDTH   = 15  , //@IPC int 13,16
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
	//控制信号
	input        zoom_in,
	input        zoom_out,
    input        move_up,
    input        move_down,
    input        move_left,
    input        move_right,
	//------------------HDMI通道数据------------------------//
	//HDMI1输入
	input [23:0]i_hdmi1_data,
	input i_hdmi1_vde,
	input i_hdmi1_hsync,
	input i_hdmi1_vsync,
	input i_hdmi1_clk,
	input [3:0]i_video_proc_sel,
	output o_hdmi1_resetn,
	
	//HDMI3输出
	output [23:0]o_hdmi3_data,
	output o_hdmi3_vde,
	output o_hdmi3_hsync,
	output o_hdmi3_vsync,
	output o_hdmi3_clk,
    output o_hdmi3_resetn,
	
	//HDMI驱动芯片IIC信号
	output o_hdmi1_scl,
	inout io_hdmi1_sda,
	output o_hdmi3_scl,
	inout io_hdmi3_sda,
	
	//-----------------DDR管脚信号-----------------------//
	output o_ddr3_rstn,
	output o_ddr3_clk_p,
	output o_ddr3_clk_n,
	output o_ddr3_cke,
	output o_ddr3_cs,
	output o_ddr3_ras,
	output o_ddr3_cas,
	output o_ddr3_we,
	output o_ddr3_odt,
	output [MEM_ROW_ADDR_WIDTH-1:0]o_ddr3_address,
	output [MEM_BADDR_WIDTH-1:0]o_ddr3_ba,
	output [MEM_DM_WIDTH-1:0]o_ddr3_dm,
	inout [MEM_DQS_WIDTH-1:0]o_ddr3_dqs_p,
	inout [MEM_DQS_WIDTH-1:0]o_ddr3_dqs_n,
	inout [MEM_DQ_WIDTH-1:0]o_ddr3_dq
);
   
	//系统时钟
	wire clk_system;
	wire pll_locked;
	wire axi_clk;

	//HDMI时钟BUFG信号
	wire hdmi1_clk_bufg;
	wire hdmi2_clk_bufg;
	wire hdmi3_clk;
	
	//IIC信号
	wire LT8619_1_SDA_O;
    wire LT8619_1_SDA_I;
    wire LT8619_1_SDA_T;
	wire LT8619_1_SCL;
	
	wire LT8618_SDA_O;
    wire LT8618_SDA_I;
    wire LT8618_SDA_T;
	wire LT8618_SCL;
	
	//-------------------外部写DDR控制总线------------------//
	wire ddr_mbus_wdata_rq;									//写数据请求,上升沿代表开始需要写入数据
	wire ddr_mbus_wbusy;										//写忙信号,高电平代表忙碌
	wire [DEVICE_NUM - 1:0]ddr_mbus_wsel;					//片选信号
	
	//外设0
	wire ddr_mbus_wrq0;										//写请求信号
	wire [CTRL_ADDR_WIDTH - 1:0]ddr_mbus_waddr0;    		//写初始地址信号
	wire [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]ddr_mbus_wdata0;//写数据
	wire ddr_mbus_wready0;									//写数据准备好
	
	//-------------------外部读DDR控制总线------------------//
	wire [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]ddr_mbus_rdata;	//读数据
	wire ddr_mbus_rdata_rq;									//读数据请求,上升沿代表开始需要读数据
	wire ddr_mbus_rbusy;									//读忙信号,高电平代表忙碌
	wire [DEVICE_NUM - 1:0]ddr_mbus_rsel;					//片选信号
	
	//外设0
	wire ddr_mbus_rrq0;										//读请求信号
	wire [CTRL_ADDR_WIDTH - 1:0]ddr_mbus_raddr0;    		//读初始地址信号
	wire ddr_mbus_rready0;									//读数据准备好

    //IIC信号输出----LT8618,HDMI_OUT
	assign LT8618_SDA_I = io_hdmi3_sda;
	assign io_hdmi3_sda = LT8618_SDA_T == 1'b1 ? LT8618_SDA_O : 1'bz;
	assign o_hdmi3_scl = LT8618_SCL;
	assign o_hdmi3_resetn = pll_locked;
	
	//IIC信号输出----LT8619,HDMI_IN
	assign LT8619_1_SDA_I = io_hdmi1_sda;
	assign io_hdmi1_sda = LT8619_1_SDA_T == 1'b1 ? LT8619_1_SDA_O : 1'bz;
	assign o_hdmi1_scl = LT8619_1_SCL;
	assign o_hdmi1_resetn = pll_locked;
	
	//时钟BUFG
	GTP_CLKBUFG LT8619_BUFG0(.CLKOUT(hdmi1_clk_bufg),.CLKIN(i_hdmi1_clk));
	GTP_CLKBUFG LT8618_BUFG0(.CLKOUT(o_hdmi3_clk),.CLKIN(hdmi3_clk));
	GTP_CLKBUFG AXI4_BUFG0(.CLKOUT(axi_clk),.CLKIN(clk_system));
	
	//视频图像处理接口实例化
	Image_Process_Interface #(	
		.MEM_DQ_WIDTH(MEM_DQ_WIDTH),
		.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
		.BURST_LENGTH(BURST_LENGTH),
		.DEVICE_NUM(DEVICE_NUM)
	)Image_Process_Interface_Inst(
		.i_axi_aclk(axi_clk),
		.i_rstn(pll_locked),
        //控制信号
		.zoom_in(zoom_in),
        .zoom_out(zoom_out),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
	//外设0
		//-----------------VIDEO_IN1信号-----------------//
		.i_video1_data(i_hdmi1_data),
		.i_video1_vde(i_hdmi1_vde),
		.i_video1_hsync(i_hdmi1_hsync),
		.i_video1_vsync(i_hdmi1_vsync),
		.i_video1_clk(hdmi1_clk_bufg),
		.i_video1_proc_sel(i_video_proc_sel),
		
		//-----------------VIDEO_OUT1信号-----------------//
		.o_video1_data(o_hdmi3_data),
		.o_video1_vde(o_hdmi3_vde),
		.o_video1_hsync(o_hdmi3_hsync),
		.o_video1_vsync(o_hdmi3_vsync),
		.o_video1_clk(hdmi3_clk),

		//-------------------外部写DDR控制总线------------------//
		.i_mbus_wdata_rq(ddr_mbus_wdata_rq),					//写数据请求,上升沿代表开始需要写入数据
		.i_mbus_wbusy(ddr_mbus_wbusy),							//写忙信号,高电平代表忙碌
		.i_mbus_wsel(ddr_mbus_wsel),							//片选信号
		
		//外设0
		.o_mbus_wrq0(ddr_mbus_wrq0),							//写请求信号
		.o_mbus_waddr0(ddr_mbus_waddr0),    					//写初始地址信号
		.o_mbus_wdata0(ddr_mbus_wdata0),						//写数据
		.o_mbus_wready0(ddr_mbus_wready0),						//写数据准备好
		
		//-------------------外部读DDR控制总线------------------//
		.i_mbus_rdata(ddr_mbus_rdata),							//读数据
		.i_mbus_rdata_rq(ddr_mbus_rdata_rq),					//读数据请求,上升沿代表开始需要读数据
		.i_mbus_rbusy(ddr_mbus_rbusy),							//读忙信号,高电平代表忙碌
		.i_mbus_rsel(ddr_mbus_rsel),							//片选信号
		
		//外设0
		.o_mbus_rrq0(ddr_mbus_rrq0),							//读请求信号
		.o_mbus_raddr0(ddr_mbus_raddr0),    					//读初始地址信号
		.o_mbus_rready0(ddr_mbus_rready0)						//读数据准备好
	);

	//DDR3接口实例化
	DDR3_Interface #(
		.MEM_ROW_ADDR_WIDTH(MEM_ROW_ADDR_WIDTH),
		.MEM_COL_ADDR_WIDTH(MEM_COL_ADDR_WIDTH),
		.MEM_BADDR_WIDTH(MEM_BADDR_WIDTH),
		.MEM_DQ_WIDTH(MEM_DQ_WIDTH),
		.MEM_DM_WIDTH(MEM_DM_WIDTH),
		.MEM_DQS_WIDTH(MEM_DQS_WIDTH),
		.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
		.BURST_LENGTH(BURST_LENGTH),
		.BURST_NUM(BURST_NUM),
		.BURST_WIDTH(BURST_WIDTH),
		.DEVICE_NUM(DEVICE_NUM)
	)DDR3_Interface_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.o_pll_locked(pll_locked),
		.o_clk_100MHz(clk_system),
	
		//-------------------外部写DDR控制总线------------------//
		.o_mbus_wdata_rq(ddr_mbus_wdata_rq),					//写数据请求,上升沿代表开始需要写入数据
		.o_mbus_wbusy(ddr_mbus_wbusy),							//写忙信号,高电平代表忙碌
		.o_mbus_wsel(ddr_mbus_wsel),							//片选信号
		
		//外设0
		.i_mbus_wrq0(ddr_mbus_wrq0),							//写请求信号
		.i_mbus_waddr0(ddr_mbus_waddr0),    					//写初始地址信号
		.i_mbus_wdata0(ddr_mbus_wdata0),						//写数据
		.i_mbus_wready0(ddr_mbus_wready0),						//写数据准备好
		
		//外设1
		.i_mbus_wrq1(1'b0),										//写请求信号
		.i_mbus_waddr1(28'd0),    								//写初始地址信号
		.i_mbus_wdata1(128'd0),									//写数据
		.i_mbus_wready1(1'b0),									//写数据准备好
		
		//外设2
		.i_mbus_wrq2(1'b0),										//写请求信号
		.i_mbus_waddr2(28'd0),    								//写初始地址信号
		.i_mbus_wdata2(128'd0),									//写数据
		.i_mbus_wready2(1'b0),									//写数据准备好
		
		//外设3
		.i_mbus_wrq3(1'b0),										//写请求信号
		.i_mbus_waddr3(28'd0),    								//写初始地址信号
		.i_mbus_wdata3(128'd0),									//写数据
		.i_mbus_wready3(1'b0),									//写数据准备好
		
		//-------------------外部读DDR控制总线------------------//
		.o_mbus_rdata(ddr_mbus_rdata),							//读数据
		.o_mbus_rdata_rq(ddr_mbus_rdata_rq),					//读数据请求,上升沿代表开始需要读数据
		.o_mbus_rbusy(ddr_mbus_rbusy),							//读忙信号,高电平代表忙碌
		.o_mbus_rsel(ddr_mbus_rsel),							//片选信号
		
		//外设0
		.i_mbus_rrq0(ddr_mbus_rrq0),							//读请求信号
		.i_mbus_raddr0(ddr_mbus_raddr0),    					//读初始地址信号
		.i_mbus_rready0(ddr_mbus_rready0),						//读数据准备好
		
		//外设1
		.i_mbus_rrq1(1'b0),										//读请求信号
		.i_mbus_raddr1(28'd0),    								//读初始地址信号
		.i_mbus_rready1(1'b0),									//读数据准备好
		
		//外设2
		.i_mbus_rrq2(1'b0),										//读请求信号
		.i_mbus_raddr2(28'd0),    								//读初始地址信号
		.i_mbus_rready2(1'b0),									//读数据准备好
		
		//外设3
		.i_mbus_rrq3(1'b0),										//读请求信号
		.i_mbus_raddr3(28'd0),    								//读初始地址信号
		.i_mbus_rready3(1'b0),									//读数据准备好
		
		//------------------DDR管脚信号---------------------//
		.o_ddr3_rstn(o_ddr3_rstn),
		.o_ddr3_clk_p(o_ddr3_clk_p),
		.o_ddr3_clk_n(o_ddr3_clk_n),
		.o_ddr3_cke(o_ddr3_cke),
		.o_ddr3_cs(o_ddr3_cs),
		.o_ddr3_ras(o_ddr3_ras),
		.o_ddr3_cas(o_ddr3_cas),
		.o_ddr3_we(o_ddr3_we),
		.o_ddr3_odt(o_ddr3_odt),
		.o_ddr3_address(o_ddr3_address),
		.o_ddr3_ba(o_ddr3_ba),
		.o_ddr3_dm(o_ddr3_dm),
		.o_ddr3_dqs_p(o_ddr3_dqs_p),
		.o_ddr3_dqs_n(o_ddr3_dqs_n),
		.o_ddr3_dq(o_ddr3_dq)
	);

	//LT8618接口实例化
	LT8618_Interface #(.CLOCK_FREQ_MHZ(13'd100),.IIC_Clock_KHz(13'd100))LT8618_Interface_Inst(
		.i_clk(clk_system),
		.i_rstn(pll_locked),
		
		//--------------IIC管脚信号-------------//
		.i_iic_sda(LT8618_SDA_I),
		.o_iic_scl(LT8618_SCL),          		//IIC时钟线
		.o_iic_sda_dir(LT8618_SDA_T),     		//IIC数据线方向,1代表输出
		.o_iic_sda(LT8618_SDA_O)          		//IIC数据线
	);
	
	//LT8619接口实例化,HDMI1
	LT8619_Interface #(.CLOCK_FREQ_MHZ(13'd100),.IIC_Clock_KHz(13'd100))LT8619_Interface_Inst1(
		.i_clk(clk_system),
		.i_rstn(pll_locked),
		
		//--------------IIC管脚信号-------------//
		.i_iic_sda(LT8619_1_SDA_I),
		.o_iic_scl(LT8619_1_SCL),          		//IIC时钟线
		.o_iic_sda_dir(LT8619_1_SDA_T),     	//IIC数据线方向,1代表输出
		.o_iic_sda(LT8619_1_SDA_O)          	//IIC数据线
	);
	
endmodule
