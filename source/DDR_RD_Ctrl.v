`timescale 1ns/1ps

//DDR读控制
module DDR_RD_Ctrl
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
	
	//读地址通道
	output [CTRL_ADDR_WIDTH - 1:0]o_axi_araddr,				//读地址*
	output [BURST_WIDTH - 1:0]o_axi_arlen,					//突发长度*
	output o_axi_arvalid,									//读地址有效信号,有效时表示AWADDR上地址有效*
	input i_axi_arready,									//写从机就绪信号,有效时表示从机准备好接收读地址*
	
	//读数据通道
	input [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]i_axi_rdata,	//读数据*
	input i_axi_rlast,										//有效时表示当前位突发传输最后一个
	input i_axi_rvalid,										//读数据有效信号*
	output o_axi_rready,									//主机就绪信号,有效时表示
	
	//----------------------外部控制总线--------------------//
	input i_mbus_rrq,										//读请求信号
	input [CTRL_ADDR_WIDTH - 1:0]i_mbus_raddr,    			//读初始地址信号
	output [MEM_DQ_WIDTH * BURST_LENGTH - 1:0]o_mbus_rdata,	//读数据
	output o_mbus_rdata_rq,									//读数据请求,上升沿代表开始需要读数据
	output o_mbus_rbusy										//读忙信号,高电平代表忙碌
);
	
	//状态参数
	localparam ST_RD_IDLE  = 3'd0;
	localparam ST_RA_WAIT  = 3'd1;
	localparam ST_RA_START = 3'd2;
	localparam ST_RD_WAIT  = 3'd3;
	localparam ST_RD_PROC  = 3'd4;
	localparam ST_RD_DONE  = 3'd5;
	
	//状态
	reg [2:0]state_current = 0;
	reg [2:0]state_next = 0;
	
	//输入缓存信号
	reg [1:0]mbus_rrq_i = 0;
	
	//输出信号----读地址
	reg [CTRL_ADDR_WIDTH - 1:0]axi_araddr_o = 0;			//读地址*
	reg axi_arvalid_o = 0;									//读地址有效信号,有效时表示AWADDR上地址有效*
	
	//输出信号----其他BUS信号
	reg [MEM_DQ_WIDTH * BURST_LENGTH-1:0]mbus_rdata_o = 0;	//读数据
	reg mbus_rdata_rq_o = 0;								//读数据请求,上升沿代表现在读的数据开始有效
	reg mbus_rbusy_o = 0;									//读应答信号,上升沿代表DDR读完毕
	
	//信号连线----读地址信号
	assign o_axi_araddr = axi_araddr_o;
	assign o_axi_arlen = BURST_NUM;
	assign o_axi_arvalid = axi_arvalid_o;
	
	//信号连线----读数据信号
	assign o_axi_rready = i_axi_rvalid;
	
	//信号连线----其他BUS信号
	assign o_mbus_rdata = mbus_rdata_o;
	assign o_mbus_rdata_rq = mbus_rdata_rq_o;
	assign o_mbus_rbusy = mbus_rbusy_o;
	
	//固定数据输出----读信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			axi_araddr_o <= {CTRL_ADDR_WIDTH{1'b0}};
			mbus_rdata_o <= {(MEM_DQ_WIDTH*BURST_LENGTH){1'b0}};
		end else begin
			axi_araddr_o <= i_mbus_raddr;
			mbus_rdata_o <= i_axi_rdata;
		end
	end
	
	//读地址有效信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)axi_arvalid_o <= 1'b0;
		else if(state_current == ST_RD_IDLE)axi_arvalid_o <= 1'b0;
		else if(state_current == ST_RA_START)axi_arvalid_o <= 1'b1;
		else if(state_current == ST_RD_WAIT && i_axi_arready == 1'b1)axi_arvalid_o <= 1'b0;
		else axi_arvalid_o <= axi_arvalid_o;
	end
	
	//读数据请求信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rdata_rq_o <= 1'b0;
		else if(state_current == ST_RD_PROC && i_axi_rvalid == 1'b1)mbus_rdata_rq_o <= 1'b1;
		else mbus_rdata_rq_o <= 1'b0;
	end
	
	//忙信号
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rbusy_o <= 1'b0;
		else if(state_current == ST_RA_WAIT)mbus_rbusy_o <= 1'b1;
		else if(state_current == ST_RD_DONE)mbus_rbusy_o <= 1'b0;
		else mbus_rbusy_o <= mbus_rbusy_o;
	end
	
	//状态机
	always@(*)begin
		case(state_current)
			ST_RD_IDLE:begin
				if(mbus_rrq_i == 2'b01)state_next <= ST_RA_WAIT;
				else state_next <= ST_RD_IDLE;
			end
			ST_RA_WAIT:state_next <= ST_RA_START;
			ST_RA_START:state_next <= ST_RD_WAIT;
			ST_RD_WAIT:begin
				if(i_axi_arready == 1'b1)state_next <= ST_RD_PROC;
				else state_next <= ST_RD_WAIT;
			end
			ST_RD_PROC:begin
				if(i_axi_rlast == 1'b1 && i_axi_rvalid == 1'b1)state_next <= ST_RD_DONE;
				else state_next <= ST_RD_PROC;
			end
			ST_RD_DONE:state_next <= ST_RD_IDLE;
			default:state_next <= ST_RD_IDLE;
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
	
	//输入信号缓存
	always@(posedge i_axi_aclk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_rrq_i <= 2'd0;
		end else begin
			mbus_rrq_i <= {mbus_rrq_i[0],i_mbus_rrq};
		end
	end
	
endmodule