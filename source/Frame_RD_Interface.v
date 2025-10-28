`timescale 1ns / 1ps

//帧读接口
module Frame_RD_Interface
#(  
	parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter START_ADDRESS        = 32'h00000000
)
(
	input i_axi_aclk,
	input i_rstn,
	
	//--------------视频输入通道(参考视频信号)--------------//
	input i_video_clk,
	input i_video_vde,
	input i_video_hsync,
	input i_video_vsync,
	input i_video_vsync_valid,
	
	//---------------------视频输出通道---------------------//
	output [23:0]o_video_data,
	output o_video_vde,
	output o_video_hsync,
	output o_video_vsync,
	output o_video_clk,
	
	//-------------------外部读DDR控制总线------------------//
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_rdata,	//读数据
	input i_mbus_rdata_rq,									//读数据请求,上升沿代表开始需要读数据
	input i_mbus_rbusy,										//读忙信号,高电平代表忙碌
	input i_mbus_rsel,										//片选信号

	output o_mbus_rrq,										//读请求信号
	output [CTRL_ADDR_WIDTH - 1:0]o_mbus_raddr,    			//读初始地址信号
	output o_mbus_rready									//读数据准备好
);
	//数据信息
	localparam BURST_NUM = 10'd15;
	localparam FIFO_NUM  = 10'd512;
	
	//FIFO满空的参数
	localparam FIFO_ALMOST_FULL = FIFO_NUM - BURST_NUM - 2;
	localparam FIFO_ALMOST_EMPTY = BURST_NUM;
	
	//延时参数
	localparam DELAY_NUM = 3'd3;
	
	//状态参数
	localparam ST_RD_IDLE = 2'd0;
	localparam ST_RD_FIFO_WAIT = 2'd1;
	localparam ST_RD_FIFO = 2'd2;
	
	
	//FIFO信号
	wire fifo_wr_rst;
	wire fifo_wr_en;
	wire [127:0]fifo_wdata;
	wire [9:0]fifo_wr_water_level;
	wire fifo_rd_rst;
	wire fifo_rd_en;
	wire [15:0]fifo_rd_data;
	
	//状态机
	reg [1:0]state_current = 0;
	reg [1:0]state_next = 0;
	
	//输入缓存信号
	reg [1:0]mbus_rbusy_i = 0;
	reg [2:0]video_vsync_i = 0;
	reg [1:0]video_vsync_valid_i = 0;
	
	//视频缓存信号
	reg [DELAY_NUM * 24 - 1:0]video_data_buff = 0;
	reg [DELAY_NUM - 1:0]video_vde_buff = 0;
	reg [DELAY_NUM - 1:0]video_hsync_buff = 0;
	reg [DELAY_NUM - 1:0]video_vsync_buff = 0;
	reg video_vsync_valid_buff = 0;
	
	//读数据缓冲信号
	reg [23:0]rd_data_buff = 0;
	
	//输出信号
	reg mbus_rrq_o = 0;
	reg mbus_rready_o = 0;
	reg [CTRL_ADDR_WIDTH - 1:0]mbus_raddr_o = 0;
	reg [23:0]video_data_o = 0;
	
	//FIFO信号连线
	assign fifo_wr_rst = (state_current == ST_RD_IDLE);
	assign fifo_wr_en = (state_current == ST_RD_FIFO) & i_mbus_rdata_rq;
	assign fifo_wdata = i_mbus_rdata;
	assign fifo_rd_rst = (video_vsync_buff[1:0] == {~video_vsync_valid_buff,video_vsync_valid_buff});
	assign fifo_rd_en = i_video_vde;
	
	//输出信号--视频信号连线
	assign o_video_data = video_data_o;
	assign o_video_vde = video_vde_buff[DELAY_NUM - 1];
	assign o_video_hsync = video_hsync_buff[DELAY_NUM - 1];
	assign o_video_vsync = video_vsync_buff[DELAY_NUM - 1];
	assign o_video_clk = i_video_clk;
	
	//输出信号--总线信号连线
	assign o_mbus_rrq = mbus_rrq_o;
	assign o_mbus_raddr = mbus_raddr_o;
	assign o_mbus_rready = mbus_rready_o;
	
	//视频信号1输出
	always@(posedge i_video_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)video_data_o <= 24'd0;
		else video_data_o <= rd_data_buff;
	end
	
	//读请求信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rrq_o <= 1'b0;
		else if(state_current == ST_RD_FIFO_WAIT)mbus_rrq_o <= 1'b1;
		else mbus_rrq_o <= 1'b0;
	end
	
	//满信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rready_o <= 1'b0;
		else if(state_current == ST_RD_IDLE)mbus_rready_o <= 1'b0;
		else if(state_current == ST_RD_FIFO_WAIT && fifo_wr_water_level > FIFO_ALMOST_FULL)mbus_rready_o <= 1'b0;
		else mbus_rready_o <= 1'b1;
	end
	
	//地址信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_raddr_o <= {CTRL_ADDR_WIDTH{1'b0}};
		else if(state_current == ST_RD_IDLE)mbus_raddr_o <= START_ADDRESS;
		else if(state_current == ST_RD_FIFO && mbus_rbusy_i == 2'b10)mbus_raddr_o <= mbus_raddr_o + 128;
		else mbus_raddr_o <= mbus_raddr_o;
	end
	
	//主状态机
	always@(*)begin
		case(state_current)
			ST_RD_IDLE:begin
				if(video_vsync_i[2:1] == {video_vsync_valid_i[1],~video_vsync_valid_i[1]})state_next <= ST_RD_FIFO_WAIT;
				else state_next <= ST_RD_IDLE;
			end
			ST_RD_FIFO_WAIT:begin
				if(video_vsync_i[2:1] == {video_vsync_valid_i[1],video_vsync_valid_i[1]})state_next <= ST_RD_IDLE;
				else if(i_mbus_rsel == 1'b1)state_next <= ST_RD_FIFO;
				else state_next <= ST_RD_FIFO_WAIT;
			end
			ST_RD_FIFO:begin
				if(mbus_rbusy_i == 2'b10)state_next <= ST_RD_FIFO_WAIT;
				else state_next <= ST_RD_FIFO;
			end
			
			default:state_next <= ST_RD_IDLE;
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
	FIFO_128x512x16 FIFO_128x512x16_Inst(
		.wr_clk(i_axi_aclk),                	// input
		.wr_rst(fifo_wr_rst),                	// input
		.wr_en(fifo_wr_en),                  	// input
		.wr_data(fifo_wdata),              		// input [127:0]
		.wr_full(),              				// output
		.wr_water_level(fifo_wr_water_level),	// output [9:0]
		.almost_full(),      					// output
		.rd_clk(i_video_clk),                	// input
		.rd_rst(fifo_rd_rst),     				// input
		.rd_en(fifo_rd_en),                  	// input
		.rd_data(fifo_rd_data),              	// output [15:0]
		.rd_empty(),            				// output
		.rd_water_level(),						// output [12:0]
		.almost_empty()    						// output
	);
	
	//读FIFO视频信号缓存
	always@(posedge i_video_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)rd_data_buff <= 24'd0;
		else if(video_vde_buff[0] == 1'b1)rd_data_buff <= {fifo_rd_data[15:11],3'd0,fifo_rd_data[10:5],2'd0,fifo_rd_data[4:0],3'd0};
		else rd_data_buff <= rd_data_buff;
	end
	
	//视频信号缓存
	always@(posedge i_video_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			video_data_buff <= {(DELAY_NUM * 24){1'b0}};
			video_vde_buff <= {DELAY_NUM{1'b0}};
			video_hsync_buff <= {DELAY_NUM{1'b0}};
			video_vsync_buff <= {DELAY_NUM{1'b0}};
			video_vsync_valid_buff <= 1'b0;
		end else begin
			video_data_buff <= (DELAY_NUM == 1) ? 24'hffffff : ({video_data_buff[(DELAY_NUM -1) * 24 - 1:0],24'hffffff});
			video_vde_buff <= (DELAY_NUM == 1) ? i_video_vde : {video_vde_buff[DELAY_NUM - 2:0],i_video_vde};
			video_hsync_buff <= (DELAY_NUM == 1) ? i_video_hsync : {video_hsync_buff[DELAY_NUM - 2:0],i_video_hsync};
			video_vsync_buff <= (DELAY_NUM == 1) ? i_video_vsync : {video_vsync_buff[DELAY_NUM - 2:0],i_video_vsync};
			video_vsync_valid_buff <= i_video_vsync_valid;
		end
	end
	
	//输入信号缓存
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_rbusy_i <= 2'd0;
			video_vsync_i <= 3'd0;
			video_vsync_valid_i <= 2'd0;
		end else begin
			mbus_rbusy_i <= {mbus_rbusy_i[0],i_mbus_rbusy};
			video_vsync_i <= {video_vsync_i[1:0],i_video_vsync};
			video_vsync_valid_i <= {video_vsync_valid_i[0],i_video_vsync_valid};
		end
	end
endmodule