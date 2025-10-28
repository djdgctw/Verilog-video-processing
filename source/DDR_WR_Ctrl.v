`timescale 1ns/1ps

//DDR写控制
module DDR_WR_Ctrl
#(  parameter MEM_DQ_WIDTH         = 16,
	parameter CTRL_ADDR_WIDTH      = 28,
	parameter BURST_LENGTH		   = 8,
	parameter BURST_NUM			   = 15,
	parameter BURST_WIDTH		   = 4
)
(
	input i_rstn,
	
	//-----------------------AXI4总线-----------------------//
	input i_axi_aclk,
	
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
	output o_axi_bready,									//写响应ready,主机准备好接收写响应信号
	
	//----------------------外部控制总线--------------------//
	input i_mbus_wrq,										//写请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_waddr,    			//写初始地址信号
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_mbus_wdata,	//写数据
	output o_mbus_wdata_rq,									//写数据请求,上升沿代表开始需要写入数据
	output o_mbus_wbusy										//写忙信号,高电平代表忙碌
);
	
	//状态参数
	localparam ST_WR_IDLE  = 3'd0;
	localparam ST_WA_WAIT  = 3'd1;
	localparam ST_WA_START = 3'd2;
	localparam ST_WD_WAIT  = 3'd3;
	localparam ST_WD_PROC  = 3'd4;
	localparam ST_WR_WAIT  = 3'd5;
	localparam ST_WR_DONE  = 3'd6;
	
	//发送计数
	reg [BURST_WIDTH - 1:0]send_cnt = 0;
	
	//状态
	reg [2:0]state_current = 0;
	reg [2:0]state_next = 0;

	//输入缓存信号
	reg [1:0]mbus_wrq_i = 0;
	
	//输出信号----写地址
	reg [CTRL_ADDR_WIDTH - 1:0]axi_awaddr_o = 0;				//写地址*
	reg axi_awvalid_o = 0;										//写地址有效信号,有效时表示AWADDR上地址有效*
	
	//输出信号----写数据
	reg axi_wlast_o = 0;										//last信号,有效时表示当前位突发传输最后一个数据
	reg axi_wvalid_o = 0;										//写有效信号,有效时表示写数据有效
	
	//输出信号----写响应
	reg axi_bready_o = 0;										//写响应ready,主机准备好接收写响应信号
	
	//输出信号----其他BUS信号
	reg mbus_wdata_rq_o = 0;
	reg mbus_wbusy_o = 0;										//写忙信号,高电平代表忙碌
	
	//信号连线----写地址信号
	assign o_axi_awaddr = axi_awaddr_o;
	assign o_axi_awlen = BURST_NUM;
	assign o_axi_awvalid = axi_awvalid_o;
	
	//信号连线----写数据信号
	assign o_axi_wdata = i_mbus_wdata;
	assign o_axi_wstrb = {(MEM_DQ_WIDTH * BURST_LENGTH/8){1'b1}};
	assign o_axi_wlast = axi_wlast_o;
	assign o_axi_wvalid = axi_wvalid_o;
	
	//信号连线----写响应信号
	assign o_axi_bready = axi_bready_o;
	
	//信号连线----其他BUS信号
	assign o_mbus_wdata_rq = mbus_wdata_rq_o | (i_axi_wready & send_cnt < BURST_NUM);
	assign o_mbus_wbusy = mbus_wbusy_o;
	
	//固定信号输出----写信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			axi_awaddr_o <= {CTRL_ADDR_WIDTH{1'b0}};
		end else begin
			axi_awaddr_o <= i_mbus_waddr;
		end
	end
	
	//写地址有效信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)axi_awvalid_o <= 1'b0;
		else if(state_current == ST_WR_IDLE)axi_awvalid_o <= 1'b0;
		else if(state_current == ST_WA_START)axi_awvalid_o <= 1'b1;
		else if(state_current == ST_WD_WAIT && i_axi_awready == 1'b1)axi_awvalid_o <= 1'b0;
		else axi_awvalid_o <= axi_awvalid_o;
	end
	
	//写数据有效信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)axi_wvalid_o <= 1'b0;
		else if(state_current == ST_WD_PROC)axi_wvalid_o <= 1'b1;
		else if(axi_wlast_o == 1'b1)axi_wvalid_o <= 1'b0;
		else axi_wvalid_o <= axi_wvalid_o;
	end
	
	//写数据结尾信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)axi_wlast_o <= 1'b0;
		else if(state_current == ST_WD_PROC && send_cnt == {BURST_WIDTH{1'b0}})axi_wlast_o <= 1'b0;
		else if(state_current == ST_WD_PROC && send_cnt == BURST_NUM)axi_wlast_o <= 1'b1;
		else axi_wlast_o <= axi_wlast_o;
	end
	
	//写响应信号输出
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)axi_bready_o <= 1'b0;
		else axi_bready_o <= i_axi_bvalid;
	end
	
	//忙信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_DONE)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WA_WAIT)mbus_wbusy_o <= 1'b1;
		else mbus_wbusy_o <= mbus_wbusy_o;
	end
	
	//外部控制信号--写请求信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wdata_rq_o <= 1'b0;
		else if(state_current == ST_WA_WAIT)mbus_wdata_rq_o <= 1'b1;
		else mbus_wdata_rq_o <= 1'b0;
	end
	
	//状态机
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(mbus_wrq_i == 2'b01)state_next <= ST_WA_WAIT;
				else state_next <= ST_WR_IDLE;
			end
			ST_WA_WAIT:state_next <= ST_WA_START;
			ST_WA_START:state_next <= ST_WD_WAIT;
			ST_WD_WAIT:begin
				if(i_axi_awready == 1'b1)state_next <= ST_WD_PROC;
				else state_next <= ST_WD_WAIT;
			end
			ST_WD_PROC:begin
				if(i_axi_wready == 1'b1 && send_cnt == BURST_NUM - 1)state_next <= ST_WR_WAIT;
				else state_next <= ST_WD_PROC;
			end
			ST_WR_WAIT:begin
				if(i_axi_bvalid == 1'b1)state_next <= ST_WR_DONE;
				else state_next <= ST_WR_WAIT;
			end
			ST_WR_DONE:state_next <= ST_WR_IDLE;
			default:state_next <= ST_WR_IDLE;
		endcase
	end
	
	//状态转换
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= 3'd0;
		end else begin
			state_current <= state_next;
		end
	end
	
	//发送数据计数
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)send_cnt <= {BURST_WIDTH{1'b0}};
		else if(state_current == ST_WD_PROC && i_axi_wready == 1'b1)send_cnt <= send_cnt + 1'b1;
		else if(state_current == ST_WA_WAIT)send_cnt <= {BURST_WIDTH{1'b0}};
		else send_cnt <= send_cnt;
	end
	
	//输入信号缓存
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_wrq_i <= 2'd0;
		end else begin
			mbus_wrq_i <= {mbus_wrq_i[0],i_mbus_wrq};
		end
	end
endmodule
