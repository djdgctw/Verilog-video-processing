`timescale 1ns/1ps

//视频图像处理接口
module Image_Process_Interface
#(  
	parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter DEVICE_NUM		   = 4
)
(
	input i_axi_aclk,
	input i_rstn,
	
	//-----------------VIDEO_IN1信号-----------------//
	input [23:0]i_video1_data,
	input i_video1_vde,
	input i_video1_hsync,
	input i_video1_vsync,
	input i_video1_clk,
	input [3:0]i_video1_proc_sel,
	
	//-----------------VIDEO_OUT1信号-----------------//
	output [23:0]o_video1_data,
	output o_video1_vde,
	output o_video1_hsync,
	output o_video1_vsync,
	output o_video1_clk,
	
	//-------------------外部写DDR控制总线------------------//
	input i_mbus_wdata_rq,									//写数据请求,上升沿代表开始需要写入数据
	input i_mbus_wbusy,										//写忙信号,高电平代表忙碌
	input [DEVICE_NUM - 1:0]i_mbus_wsel,					//片选信号
	
	//外设0
	output o_mbus_wrq0,										//写请求信号
	output [CTRL_ADDR_WIDTH - 1:0]o_mbus_waddr0,    		//写初始地址信号
	output [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]o_mbus_wdata0,//写数据
	output o_mbus_wready0,									//写数据准备好
	
	//-------------------外部读DDR控制总线------------------//
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_rdata,	//读数据
	input i_mbus_rdata_rq,									//读数据请求,上升沿代表开始需要读数据
	input i_mbus_rbusy,										//读忙信号,高电平代表忙碌
	input [DEVICE_NUM - 1:0]i_mbus_rsel,					//片选信号
	
	//输入控制信号
	input        zoom_in,
	input        zoom_out,
    input        move_up,
    input        move_down,
    input        move_left,
    input        move_right,
	//外设0
	output o_mbus_rrq0,										//读请求信号
	output [CTRL_ADDR_WIDTH - 1:0]o_mbus_raddr0,    		//读初始地址信号
	output o_mbus_rready0									//读数据准备好
);
	//-------------解析输出1---------------//
	wire [3:0]video1_mode;										//视频格式
	wire [11:0]video1_format_x;									//像素长度X
	wire [11:0]video1_format_y;									//像素长度Y
	wire [11:0]video1_x;										//解析坐标X
	wire [11:0]video1_y;										//解析坐标Y
	wire video1_hsync_valid;									//行信号有效电平
	wire video1_vsync_valid;									//场信号有效电平
	wire video1_end;											//帧结束,上升沿有效
	wire video1_change;											//帧图像分辨率改变,高电平有效
	
	//-------------视频信号1---------------//
	wire [23:0]video1_data0;
	wire video1_vde0;
	wire video1_hsync0;
	wire video1_vsync0;

	//-------------视频处理输出1-----------//
	wire [23:0]video1_proc_data;
	wire video1_proc_vde;
	wire video1_proc_hsync;
	wire video1_proc_vsync;
	
	//-------------解析输出2---------------//
	wire [3:0]video2_mode;										//视频格式
	wire [11:0]video2_format_x;									//像素长度X
	wire [11:0]video2_format_y;									//像素长度Y
	wire [11:0]video2_x;										//解析坐标X
	wire [11:0]video2_y;										//解析坐标Y
	wire video2_hsync_valid;									//行信号有效电平
	wire video2_vsync_valid;									//场信号有效电平
	wire video2_end;											//帧结束,上升沿有效
	wire video2_change;											//帧图像分辨率改变,高电平有效
	
	//-------------视频信号2---------------//
	wire [23:0]video2_data0;
	wire video2_vde0;
	wire video2_hsync0;
	wire video2_vsync0;
	
	//输出信号
	wire [23:0]video1_data_o;
	wire video1_vde_o;
	wire video1_hsync_o;
	wire video1_vsync_o;
	wire video1_clk_o;
	wire [23:0]video2_data_o;
	wire video2_vde_o;
	wire video2_hsync_o;
	wire video2_vsync_o;
	wire video2_clk_o;
	
	//输出连线
	assign o_video1_data = video1_data_o;
	assign o_video1_vde = video1_vde_o;
	assign o_video1_hsync = video1_hsync_o;
	assign o_video1_vsync = video1_vsync_o;
	assign o_video1_clk = video1_clk_o;
	
	//视频图像预处理接口实例化
	Video_Analyze_Interface Video_Analyze_Interface_Inst(
		.i_pclk(i_video1_clk),
		.i_rstn(i_rstn),
		
		//-------------视频输入通道---------------//
		.i_video_data(i_video1_data),
		.i_video_vde(i_video1_vde),
		.i_video_hsync(i_video1_hsync),
		.i_video_vsync(i_video1_vsync),
		
		//-------------视频输出通道---------------//
		.o_video_data(video1_data0),
		.o_video_vde(video1_vde0),
		.o_video_hsync(video1_hsync0),
		.o_video_vsync(video1_vsync0),
		
		//-------------解析输出通道---------------//
		.o_video_mode(video1_mode),					//视频格式
		.o_video_format_x(video1_format_x),			//像素长度X
		.o_video_format_y(video1_format_y),			//像素长度Y
		.o_video_x(video1_x),						//解析坐标X
		.o_video_y(video1_y),						//解析坐标Y
		.o_video_hsync_valid(video1_hsync_valid),	//行信号有效电平
		.o_video_vsync_valid(video1_vsync_valid),	//场信号有效电平
		.o_video_end(video1_end),					//帧结束,上升沿有效
		.o_video_change(video1_change)				//帧图像分辨率改变,高电平有效
	);

	//灰度处理IP实例化
	vip_gray Video1_Proc_Inst(
		.clk(i_video1_clk),
		.rst_n(i_rstn),
		.pre_frame_vsync(video1_vsync0),
		.pre_frame_href(video1_hsync0),
		.pre_frame_de(video1_vde0),
		.pre_rgb(video1_data0),
		.proc_sel(i_video1_proc_sel),
		.post_frame_vsync(video1_proc_vsync),
		.post_frame_href(video1_proc_hsync),
		.post_frame_de(video1_proc_vde),
		.post_rgb(video1_proc_data),
		.zoom_in(zoom_in)  ,
        .zoom_out(zoom_out),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right)
	);
	
	//帧写接口实例化
	Frame_WR_Interface #(  	
		.MEM_DQ_WIDTH(MEM_DQ_WIDTH),
		.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
		.BURST_LENGTH(BURST_LENGTH),
		.START_ADDRESS(28'h0000000)
	)Frame_WR_Interface_Inst(
		.i_axi_aclk(i_axi_aclk),
		.i_rstn(i_rstn),
		
		//-----------------------视频通道-----------------------//
		//视频解析信号
		.i_video_vsync_valid(video1_vsync_valid),				//场信号有效电平
		
		//视频帧信号
		.i_video_data(video1_proc_data),
		.i_video_vde(video1_proc_vde),
		.i_video_vsync(video1_proc_vsync),
		.i_video_clk(i_video1_clk),
		
		//-------------------外部写DDR控制总线------------------//
		.i_mbus_wdata_rq(i_mbus_wdata_rq),						//写数据请求,上升沿代表开始需要写入数据
		.i_mbus_wbusy(i_mbus_wbusy),							//写忙信号,高电平代表忙碌
		.i_mbus_wsel(i_mbus_wsel[0]),							//片选信号
		
		.o_mbus_wrq(o_mbus_wrq0),								//写请求信号
		.o_mbus_waddr(o_mbus_waddr0),    						//写初始地址信号
		.o_mbus_wdata(o_mbus_wdata0),							//写数据
		.o_mbus_wready(o_mbus_wready0)							//写数据准备好
	);

	//帧读接口实例化
	Frame_RD_Interface #(  	
		.MEM_DQ_WIDTH(MEM_DQ_WIDTH),
		.CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
		.BURST_LENGTH(BURST_LENGTH),
		.START_ADDRESS(28'h0000000)
	)Frame_RD_Interface_Inst(
		.i_axi_aclk(i_axi_aclk),
		.i_rstn(i_rstn),
		
		//--------------视频输入通道(参考视频信号)--------------//
		.i_video_clk(i_video1_clk),
		.i_video_vde(video1_proc_vde),
		.i_video_hsync(video1_proc_hsync),
		.i_video_vsync(video1_proc_vsync),
		.i_video_vsync_valid(video1_vsync_valid),
		
		//---------------------视频输出通道---------------------//
		.o_video_data(video1_data_o),
		.o_video_vde(video1_vde_o),
		.o_video_hsync(video1_hsync_o),
		.o_video_vsync(video1_vsync_o),
		.o_video_clk(video1_clk_o),
		
		//-------------------外部读DDR控制总线------------------//
		.i_mbus_rdata(i_mbus_rdata),							//读数据
		.i_mbus_rdata_rq(i_mbus_rdata_rq),						//读数据请求,上升沿代表开始需要读数据
		.i_mbus_rbusy(i_mbus_rbusy),							//读忙信号,高电平代表忙碌
		.i_mbus_rsel(i_mbus_rsel[0]),							//片选信号
		
		.o_mbus_rrq(o_mbus_rrq0),								//读请求信号
		.o_mbus_raddr(o_mbus_raddr0),    						//读初始地址信号
		.o_mbus_rready(o_mbus_rready0)							//读数据准备好
	);

endmodule