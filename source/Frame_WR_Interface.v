`timescale 1ns / 1ps

//帧写接口
module Frame_WR_Interface
#(  
	parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter START_ADDRESS        = 32'h00000000
)
(
	input i_axi_aclk,
	input i_rstn,
	
	//-----------------------视频通道-----------------------//
	//视频解析信号
	input i_video_vsync_valid,								//场信号有效电平
	
	//视频帧信号
	input [23:0]i_video_data,
	input i_video_vde,
	input i_video_vsync,
	input i_video_clk,
	
	//-------------------外部写DDR控制总线------------------//
	input i_mbus_wdata_rq,									//写数据请求,上升沿代表开始需要写入数据
	input i_mbus_wbusy,										//写忙信号,高电平代表忙碌
	input i_mbus_wsel,										//片选信号
	
	output o_mbus_wrq,										//写请求信号
	output [CTRL_ADDR_WIDTH - 1:0]o_mbus_waddr,    			//写初始地址信号
	output [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]o_mbus_wdata,	//写数据
	output o_mbus_wready									//写数据准备好
);
	//数据信息
	localparam BURST_NUM = 10'd15;
	localparam FIFO_NUM  = 10'd512;
	
	//FIFO满空的参数
	localparam FIFO_ALMOST_FULL = FIFO_NUM - BURST_NUM - 2;
	localparam FIFO_ALMOST_EMPTY = BURST_NUM;
	
	//状态参数
	localparam ST_WR_IDLE = 2'd0;
	localparam ST_WR_FIFO_WAIT = 2'd1;
	localparam ST_WR_FIFO = 2'd2;
	
	//FIFO信号
	wire fifo_wr_rst;
	wire fifo_wr_en;
	wire [15:0]fifo_wr_data;
	wire fifo_rd_rst;
	wire fifo_rd_en;
	wire [127:0]fifo_rdata;
	wire [9:0]fifo_rd_water_level;
	
	//状态机
	reg [1:0]state_current = 0;
	reg [1:0]state_next = 0;
	
	//视频缓存信号
	reg video_vsync_valid_buff = 0;
	reg [1:0]video_vsync_buff = 0;
	
	//输入缓存信号
	reg [1:0]mbus_wbusy_i = 0;
	reg [2:0]video_vsync_i = 0;
	reg [1:0]video_vsync_valid_i = 0;
	
	//输出信号
	reg mbus_wrq_o = 0;
	reg mbus_wready_o = 0;
	reg [CTRL_ADDR_WIDTH - 1 : 0]mbus_waddr_o = 0;
	
	//FIFO信号连线
	assign fifo_wr_rst = (video_vsync_buff == {video_vsync_valid_buff,~video_vsync_valid_buff});
	assign fifo_wr_en = i_video_vde;
	assign fifo_wr_data = {i_video_data[23:19],i_video_data[15:10],i_video_data[7:3]};
	assign fifo_rd_rst = (state_current == ST_WR_IDLE);
	assign fifo_rd_en = (state_current == ST_WR_FIFO) & i_mbus_wdata_rq;
	
	//输出信号连线
	assign o_mbus_wrq = mbus_wrq_o;
	assign o_mbus_wready = mbus_wready_o;
	assign o_mbus_waddr = mbus_waddr_o;
	assign o_mbus_wdata = fifo_rdata;
	
	//写请求信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wrq_o <= 1'b0;
		else if(state_current == ST_WR_FIFO_WAIT)mbus_wrq_o <= 1'b1;
		else mbus_wrq_o <= 1'b0;
	end
	
	//空信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wready_o <= 1'b0;
		else if(state_current == ST_WR_IDLE)mbus_wready_o <= 1'b0;
		else if(state_current == ST_WR_FIFO_WAIT && fifo_rd_water_level < FIFO_ALMOST_EMPTY)mbus_wready_o <= 1'b0;
		else mbus_wready_o <= 1'b1;
	end
	
	//地址信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_waddr_o <= {CTRL_ADDR_WIDTH{1'b0}};
		else if(state_current == ST_WR_IDLE)mbus_waddr_o <= START_ADDRESS;
		else if(state_current == ST_WR_FIFO && mbus_wbusy_i == 2'b10)mbus_waddr_o <= mbus_waddr_o + 128;
		else mbus_waddr_o <= mbus_waddr_o;
	end
	
	//主状态机
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(video_vsync_i[2:1] == {video_vsync_valid_i[1],~video_vsync_valid_i[1]})state_next <= ST_WR_FIFO_WAIT;
				else state_next <= ST_WR_IDLE;
			end
			ST_WR_FIFO_WAIT:begin
				if(video_vsync_i[2:1] == {video_vsync_valid_i[1],video_vsync_valid_i[1]})state_next <= ST_WR_IDLE;
				else if(i_mbus_wsel == 1'b1)state_next <= ST_WR_FIFO;
				else state_next <= ST_WR_FIFO_WAIT;
			end
			ST_WR_FIFO:begin
				if(mbus_wbusy_i == 2'b10)state_next <= ST_WR_FIFO_WAIT;
				else state_next <= ST_WR_FIFO;
			end
			
			default:state_next <= ST_WR_IDLE;
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
	
	//缓冲FIFO
	FIFO_16x4096x128 FIFO_16x4096x128_Inst(
		.wr_clk(i_video_clk),           		// input
		.wr_rst(fifo_wr_rst),         			// input
		.wr_en(fifo_wr_en),                 	// input
		.wr_data(fifo_wr_data),              	// input [15:0]
		.wr_full(),              				// output
		.wr_water_level(),						// output [12:0]
		.almost_full(),    						// output
		.rd_clk(i_axi_aclk),              		// input
		.rd_rst(fifo_rd_rst),              		// input
		.rd_en(fifo_rd_en),                		// input
		.rd_data(fifo_rdata),              		// output [127:0]
		.rd_empty(),            				// output
		.rd_water_level(fifo_rd_water_level),	// output [9:0]
		.almost_empty()   						// output
	);
	
	//视频信号缓存
	always@(posedge i_video_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			video_vsync_valid_buff <= 1'b0;
			video_vsync_buff <= 2'd0;
		end else begin
			video_vsync_valid_buff <= i_video_vsync_valid;
			video_vsync_buff <= {video_vsync_buff[0],i_video_vsync};
		end
	end
	
	//输入信号缓存,两级同步,跨时钟域处理
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_wbusy_i <= 2'd0;
			video_vsync_i <= 3'd0;
			video_vsync_valid_i <= 2'd0;
		end else begin
			mbus_wbusy_i <= {mbus_wbusy_i[0],i_mbus_wbusy};
			video_vsync_i <= {video_vsync_i[1:0],i_video_vsync};
			video_vsync_valid_i <= {video_vsync_valid_i[0],i_video_vsync_valid};
		end
	end
	
endmodule