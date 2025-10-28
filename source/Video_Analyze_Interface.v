`timescale 1ns / 1ps

/*
	Video Format  o_video_mode
		未知		4'b1xxx					
	 1920*1080p		4'b0000
	 1280*720p      4'b0001
	 1024*768p      4'b0010
	 800*600p       4'b0011
	 800*480p       4'b0100
	 720*480p       4'b0101
	 640*480p       4'b0110
	 480*272p       4'b0111
*/

//视频帧分析接口
module Video_Analyze_Interface(
	input i_pclk,
	input i_rstn,
	
	//-------------视频输入通道---------------//
	input [23:0]i_video_data,
	input i_video_vde,
	input i_video_hsync,
	input i_video_vsync,
	
	//-------------视频输出通道---------------//
	output [23:0]o_video_data,
	output o_video_vde,
	output o_video_hsync,
	output o_video_vsync,
	
	//-------------解析输出通道---------------//
	output [3:0]o_video_mode,						//视频格式
	output [11:0]o_video_format_x,					//像素长度X
	output [11:0]o_video_format_y,					//像素长度Y
	output [11:0]o_video_x,							//解析坐标X
	output [11:0]o_video_y,							//解析坐标Y
	output o_video_hsync_valid,						//行信号有效电平
	output o_video_vsync_valid,						//场信号有效电平
	output o_video_end,								//帧信号,上升沿代表帧结束,下降沿代表帧开始
	output o_video_change							//帧图像分辨率改变,高电平有效
);
	localparam DELAY_NUM = 3'd3;
	
	//当前视频帧模式
	reg [11:0]hsync_pixel_current = 0;
	reg [11:0]vsync_pixel_current = 0;
	reg hsync_valid_current = 1'b1;
	reg vsync_valid_current = 1'b1;
	
	//下一个视频帧模式
	reg [11:0]hsync_pixel_next = 0;
	reg [11:0]vsync_pixel_next = 0;
	reg hsync_valid_next = 1'b1;
	reg vsync_valid_next = 1'b1;
	
	//行场计数
	reg [11:0]hsync_cnt = 0;
	reg [11:0]vsync_cnt = 0;
	
	//输入缓存信号
	reg [DELAY_NUM * 24 - 1:0]video_data_i = 0;
	reg [DELAY_NUM - 1:0]video_vde_i = 0;
	reg [DELAY_NUM - 1:0]video_hsync_i = 0;
	reg [DELAY_NUM - 1:0]video_vsync_i = 0;
	
	//输出信号
	reg [3:0]video_mode_o = 0;
	reg [11:0]video_format_x_o = 0;
	reg [11:0]video_format_y_o = 0;
	reg [11:0]video_x_o = 0;
	reg [11:0]video_y_o = 0;
	reg video_hsync_valid_o = 1'b1;
	reg video_vsync_valid_o = 1'b1;
	reg video_end_o = 0;
	reg video_change_o = 0;
	
	//视频输出通道信号连线
	assign o_video_data = video_data_i[DELAY_NUM * 24 - 1:(DELAY_NUM - 1)*24];
	assign o_video_vde = video_vde_i[DELAY_NUM - 1];
	assign o_video_hsync = video_hsync_i[DELAY_NUM - 1];
	assign o_video_vsync = video_vsync_i[DELAY_NUM - 1];
	
	//解析输出信号连线
	assign o_video_mode = video_mode_o;
	assign o_video_format_x = video_format_x_o;
	assign o_video_format_y = video_format_y_o;
	assign o_video_x = video_x_o;
	assign o_video_y = video_y_o;
	assign o_video_hsync_valid = video_hsync_valid_o;
	assign o_video_vsync_valid = video_vsync_valid_o;
	assign o_video_end = video_end_o;
	assign o_video_change = video_change_o;
	 
	//视频模式输出
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)video_mode_o <= 4'd0;
		else if(hsync_pixel_current == 12'd1920&& vsync_pixel_current == 12'd1080)video_mode_o <= 4'b0000;
		else if(hsync_pixel_current == 12'd1280&& vsync_pixel_current == 12'd720)video_mode_o <= 4'b0001;
		else if(hsync_pixel_current == 12'd1024&& vsync_pixel_current == 12'd768)video_mode_o <= 4'b0010;
		else if(hsync_pixel_current == 12'd800&& vsync_pixel_current == 12'd600)video_mode_o <= 4'b0011;
		else if(hsync_pixel_current == 12'd800&& vsync_pixel_current == 12'd480)video_mode_o <= 4'b0100;
		else if(hsync_pixel_current == 12'd720&& vsync_pixel_current == 12'd480)video_mode_o <= 4'b0101;
		else if(hsync_pixel_current == 12'd640&& vsync_pixel_current == 12'd480)video_mode_o <= 4'b0110;
		else if(hsync_pixel_current == 12'd480&& vsync_pixel_current == 12'd272)video_mode_o <= 4'b0111;
		else video_mode_o <= 4'b1000;
	end
	
	//视频坐标,行场有效信号输出
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			video_format_x_o <= 12'd0;
			video_format_y_o <= 12'd0;
			video_x_o <= 12'd0;
			video_y_o <= 12'd0;
			video_hsync_valid_o <= 1'b1;
			video_vsync_valid_o <= 1'b1;
		end else begin
			video_format_x_o <= hsync_pixel_current;
			video_format_y_o <= vsync_pixel_current;
			video_x_o <= hsync_cnt;
			video_y_o <= vsync_cnt;
			video_hsync_valid_o <= hsync_valid_current;
			video_vsync_valid_o <= vsync_valid_current;
		end
	end
	
	//视频帧尾信号输出
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)video_end_o <= 1'b0;
		else if(video_vsync_i[1:0] == {~vsync_valid_current,vsync_valid_current})video_end_o <= 1'b1;
		else if(video_vde_i[1:0] == 2'b01)video_end_o <= 1'b0;
		else video_end_o <= video_end_o;
	end
	
	//视频帧改变信号输出
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)video_change_o <= 1'b0;
		else if(video_vsync_i[1:0] == {~vsync_valid_current,vsync_valid_current}&&hsync_pixel_current != hsync_pixel_next)video_change_o <= 1'b1;
		else if(video_vsync_i[1:0] == {~vsync_valid_current,vsync_valid_current}&&vsync_pixel_current != vsync_pixel_next)video_change_o <= 1'b1;
		else if(video_vde_i[1:0] == 2'b01)video_change_o <= 1'b0;
		else video_change_o <= video_change_o;
	end
	
	//视频帧模式
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			hsync_pixel_current <= 12'd0;
			vsync_pixel_current <= 12'd0;
		end else if(video_vsync_i[1:0] == {~vsync_valid_current,vsync_valid_current})begin
			hsync_pixel_current <= hsync_pixel_next;
			vsync_pixel_current <= vsync_pixel_next;
		end else begin
			hsync_pixel_current <= hsync_pixel_current;
			vsync_pixel_current <= vsync_pixel_current;
		end
	end
	
	//行场像素
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			hsync_pixel_next <= 12'd0;
			vsync_pixel_next <= 12'd0;
		end else if(video_vde_i[1:0] == 2'b10)begin
			hsync_pixel_next <= hsync_cnt;
			vsync_pixel_next <= vsync_cnt;
		end else begin
			hsync_pixel_next <= hsync_pixel_next;
			vsync_pixel_next <= vsync_pixel_next;
		end
	end

	//行计数
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)hsync_cnt <= 12'd0;
		else if(video_vde_i[0] == 1'b1)hsync_cnt <= hsync_cnt + 12'd1;
		else if(video_vde_i[1:0] == 2'b10)hsync_cnt <= 12'd0;
		else hsync_cnt <= hsync_cnt;
	end
	
	//场计数
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)vsync_cnt <= 12'd0;
		else if(video_vde_i[1:0] == 2'b01)vsync_cnt <= vsync_cnt + 12'd1;
		else if(video_vsync_i[1:0] == {vsync_valid_current,~vsync_valid_current})vsync_cnt <= 12'd0;
		else vsync_cnt <= vsync_cnt;
	end
	
	//行有效信号赋值
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)hsync_valid_current <= 1'b1;
		else if(hsync_valid_current == hsync_valid_next)hsync_valid_current <= hsync_valid_current;
		else hsync_valid_current <= hsync_valid_next;
	end
	
	//场有效信号赋值
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)vsync_valid_current <= 1'b1;
		else if(vsync_valid_current == vsync_valid_next)vsync_valid_current <= vsync_valid_current;
		else vsync_valid_current <= vsync_valid_next;
	end
	
	//行场有效电平判断
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			hsync_valid_next <= 1'b1;
			vsync_valid_next <= 1'b1;
		end else if(video_vde_i[0] == 1'b1)begin
			hsync_valid_next <= ~video_hsync_i[0];
			vsync_valid_next <= ~video_vsync_i[0];
		end else begin
			hsync_valid_next <= hsync_valid_next;
			vsync_valid_next <= vsync_valid_next;
		end
	end
	
	//输入信号缓存
	always@(posedge i_pclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			video_data_i <= {(DELAY_NUM * 24){1'b0}};
			video_vde_i <= {DELAY_NUM{1'b0}};
			video_hsync_i <= {DELAY_NUM{1'b0}};
			video_vsync_i <= {DELAY_NUM{1'b0}};
		end else begin
			video_data_i <= (DELAY_NUM == 1) ? i_video_data : ({video_data_i[(DELAY_NUM -1) * 24 - 1:0],i_video_data});
			video_vde_i <= (DELAY_NUM == 1) ? i_video_vde : {video_vde_i[DELAY_NUM - 2:0],i_video_vde};
			video_hsync_i <= (DELAY_NUM == 1) ? i_video_hsync : {video_hsync_i[DELAY_NUM - 2:0],i_video_hsync};
			video_vsync_i <= (DELAY_NUM == 1) ? i_video_vsync : {video_vsync_i[DELAY_NUM - 2:0],i_video_vsync};
		end
	end
	
endmodule