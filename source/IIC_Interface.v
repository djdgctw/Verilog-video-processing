`timescale 1ns / 1ps
// Company:			TWX Techonology Co., Ltd.
// Engineer:		Erie
// 
// Create Date: 	2019/10/07 15:32:10
// Design Name: 	IIC Driver
// Module Name: 	IIC_Interface
// Description: 	None
// 
// Dependencies: 	None
//
// Dependent modules:
// 	 Module Name				    Version
// Clock_Interface					 V2.3
//
// Version:			V2.0
// Revision Date:	2021/10/16 13:51:24	
	
module IIC_Interface
#(
	parameter CLOCK_FREQ_MHZ 	= 13'd100,                                                                                                                       
	parameter IIC_Clock_KHz 	= 13'd100
)
(
	input i_clk,
	input i_rstn,
	
	input i_mbus_rwslave_addr_mode,				
	input i_mbus_rwaddr_mode,					
	input i_mbus_rack,			            	
	input i_mbus_wack_enable,					
	input i_mbus_wack,			        		
	input i_mbus_rwmode,						

	input [7:0]i_mbus_rwslave_addr,				
	input [7:0]i_mbus_rwaddr_h,					
	input [7:0]i_mbus_rwaddr_l,					

	input i_mbus_wrq,							
	input [7:0]i_mbus_wdata,					
	input i_mbus_wvalid,						
	input i_mbus_wlast,							
	output o_mbus_wready,						

	input i_mbus_rrq,							
	input i_mbus_rready,						
	input i_mbus_rlast,							
	output [7:0]o_mbus_rdata,					
	output o_mbus_rvalid,						

	output o_mbus_rwbusy,						
	output o_mbus_rwack_err,					

	input i_iic_sda,							
	output o_iic_scl,							
	output o_iic_sda,							
	output o_iic_sda_dir						
);
	localparam CLOCK_FACTOR = (CLOCK_FREQ_MHZ * 500) / (IIC_Clock_KHz);				
	localparam FACTOR_BIT = 5'd16;
	localparam CLOCK_MODE = 1'b1;													
	localparam NEGEDGE_ENABLE = 1'b0;												
	localparam DIVIDER_MODE = {1'b0,~CLOCK_FACTOR[0],CLOCK_FACTOR[0],1'b0};			
	
	localparam ST_IDLE = 7'b0000001;
	localparam ST_WR_WAIT = 7'b0000010;
	localparam ST_RD_ADDR = 7'b0000100;
	localparam ST_RD_START = 7'b0001000;
	localparam ST_RD_DATA = 7'b0010000;
	localparam ST_RD_WAIT = 7'b0100000;
	localparam ST_END = 7'b1000000;
		
	reg [1:0]wr_mbus_wslave_addr_mode = 0;
	reg [3:0]wr_mbus_wmode = 0;
	reg wr_mbus_wrq = 0;
	wire wr_mbus_werr;
	wire wr_mbus_wbusy;

	reg rd_dbus_rstop = 0;
		
	reg rd_dbus_rrq = 0;
	reg rd_dbus_rlast = 0;
	wire [7:0]rd_dbus_rdata;
	wire rd_dbus_rvalid;
	wire rd_dbus_rbusy;
	
	wire rd_dbus_iic_sda;
	wire rd_dbus_iic_sda_dir;

	wire wr_dbus_wstart;
	wire wr_dbus_wstop_is;
	wire wr_dbus_wchange;
	
	wire wr_dbus_wack_sel;
	wire wr_dbus_wack;
	
	wire wr_dbus_wrq;
	wire [7:0]wr_dbus_wdata;
	wire wr_dbus_wvalid;
	wire wr_dbus_wlast;
	wire wr_dbus_wready;
	wire wr_dbus_wstop;
	wire wr_dbus_wbusy;
	
	wire wr_dbus_iic_sda;
	wire wr_dbus_iic_sda_dir;
		
	wire clk_IIC;
	reg [1:0]clk_IIC_buffer = 0;
	
	wire flag_scl_hs;								
	wire flag_scl_hc;								
	wire flag_scl_ls;								
	wire flag_scl_lc;								
	
	reg [6:0]state_current = 0;
	reg [6:0]state_next = 0;
	
	reg [1:0]wr_mbus_wbusy_buff = 0;
	reg [1:0]rd_dbus_rbusy_buff = 0;
	
	reg mbus_rwmode_i = 0;
	
	reg mbus_rready_i = 0;
	reg mbus_rlast_i = 0;
	
	reg mbus_rwbusy_o = 0;
	
	reg iic_scl_o = 1'b1;
	reg iic_sda_o = 1'b1;
	reg iic_sda_dir_o = 0;
		
	assign flag_scl_hs = (clk_IIC_buffer == 2'b01) && (iic_scl_o == 1'b0);			
	assign flag_scl_hc = (clk_IIC_buffer == 2'b10) && (iic_scl_o == 1'b1);			
	assign flag_scl_ls = (clk_IIC_buffer == 2'b01) && (iic_scl_o == 1'b1);			
	assign flag_scl_lc = (clk_IIC_buffer == 2'b10) && (iic_scl_o == 1'b0);			
	
	assign o_mbus_rdata = rd_dbus_rdata;
	assign o_mbus_rvalid = rd_dbus_rvalid;

	assign o_mbus_rwbusy = mbus_rwbusy_o;
	assign o_mbus_rwack_err = wr_mbus_werr;
		
	assign o_iic_scl = iic_scl_o;
	assign o_iic_sda = iic_sda_o;
	assign o_iic_sda_dir = iic_sda_dir_o;

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rwbusy_o <= 1'b0;
		else if(state_current == ST_IDLE)mbus_rwbusy_o <= i_mbus_wrq | i_mbus_rrq;
		else if(state_current == ST_END)mbus_rwbusy_o <= 1'b0;
		else mbus_rwbusy_o <= mbus_rwbusy_o;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)iic_scl_o <= 1'b1;
		else if(clk_IIC_buffer == 2'b01)iic_scl_o <= ~iic_scl_o;
		else iic_scl_o <= iic_scl_o;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			iic_sda_o <= 1'b1;
			iic_sda_dir_o <= 1'b1;
		end else begin
			iic_sda_o <= wr_dbus_iic_sda & rd_dbus_iic_sda;
			iic_sda_dir_o <= wr_dbus_iic_sda_dir & rd_dbus_iic_sda_dir;
		end
	end

	always@(*)begin
		case(state_current)
			ST_IDLE:begin
				if(i_mbus_wrq == 1'b1)state_next <= ST_WR_WAIT;
				else if(i_mbus_rrq == 1'b1 && mbus_rwmode_i == 1'b1)state_next <= ST_RD_ADDR;		
				else if(i_mbus_rrq == 1'b1)state_next <= ST_RD_START;								
				else state_next <= ST_IDLE;
			end
			ST_WR_WAIT:begin
				if(wr_mbus_wbusy_buff == 2'b10)state_next <= ST_END;
				else state_next <= ST_WR_WAIT;
			end
			ST_RD_ADDR:begin
				if(wr_mbus_wbusy_buff == 2'b10)state_next <= ST_RD_START;
				else state_next <= ST_RD_ADDR;
			end
			ST_RD_START:begin
				if(wr_mbus_wbusy_buff == 2'b10)state_next <= ST_RD_DATA;
				else state_next <= ST_RD_START;
			end
			ST_RD_DATA:begin
				if(mbus_rlast_i == 1'b1)state_next <= ST_RD_WAIT;
				else state_next <= ST_RD_DATA;
			end
			ST_RD_WAIT:begin
				if(rd_dbus_rbusy_buff == 2'b10)state_next <= ST_END;				
				else state_next <= ST_RD_WAIT;
			end
			ST_END:state_next <= ST_IDLE;
			default:state_next <= ST_IDLE;
		endcase
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;
		end else begin
			state_current <= state_next;
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)wr_mbus_wslave_addr_mode <= 2'd0;
		else if(state_current == ST_RD_START)wr_mbus_wslave_addr_mode <= {1'b1,i_mbus_rwslave_addr_mode};
		else wr_mbus_wslave_addr_mode <= {1'b0,i_mbus_rwslave_addr_mode};
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)wr_mbus_wmode <= 4'd0;
		else if(state_current == ST_RD_ADDR)wr_mbus_wmode <= 4'b1000;
		else if(state_current == ST_RD_START)wr_mbus_wmode <= 4'b0100;
		else wr_mbus_wmode <= {2'd0,~mbus_rwmode_i,mbus_rwmode_i};
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)wr_mbus_wrq <= 1'b0;
		else if(wr_mbus_wbusy_buff[0] == 1'b1 || wr_mbus_wbusy_buff[1] == 1'b1)wr_mbus_wrq <= 1'b0;
		else if(state_current == ST_WR_WAIT)wr_mbus_wrq <= 1'b1;
		else if(state_current == ST_RD_ADDR)wr_mbus_wrq <= 1'b1;
		else if(state_current == ST_RD_START)wr_mbus_wrq <= 1'b1;
		else wr_mbus_wrq <= 1'b0;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)rd_dbus_rstop <= 1'b0;
		else if(state_current == ST_RD_WAIT)rd_dbus_rstop <= 1'b1;
		else rd_dbus_rstop <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)rd_dbus_rrq <= 1'b0;
		else if(state_current == ST_RD_DATA)rd_dbus_rrq <= 1'b1;
		else rd_dbus_rrq <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)rd_dbus_rlast <= 1'b0;
		else if(state_current == ST_RD_WAIT)rd_dbus_rlast <= 1'b1;
		else rd_dbus_rlast <= 1'b0;
	end
	
	IIC_Write_Ctrl IIC_Write_Ctrl_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),

		.i_mbus_wslave_addr_mode(wr_mbus_wslave_addr_mode),		
		.i_mbus_waddr_mode(i_mbus_rwaddr_mode),					
		.i_mbus_wack_enable(i_mbus_wack_enable),				
		.i_mbus_wack(i_mbus_wack),			        			
		.i_mbus_wmode(wr_mbus_wmode),							

		.i_mbus_wslave_addr(i_mbus_rwslave_addr),				
		.i_mbus_waddr_h(i_mbus_rwaddr_h),						
		.i_mbus_waddr_l(i_mbus_rwaddr_l),						

		.i_mbus_wrq(wr_mbus_wrq),								
		.i_mbus_wdata(i_mbus_wdata),							
		.i_mbus_wvalid(i_mbus_wvalid),							
		.i_mbus_wlast(i_mbus_wlast),							
		.o_mbus_wready(o_mbus_wready),							
		.o_mbus_werr(wr_mbus_werr),								
		.o_mbus_wbusy(wr_mbus_wbusy),							
			
		.o_dbus_wstart(wr_dbus_wstart),							
		.o_dbus_wstop(wr_dbus_wstop_is),						
		.o_dbus_wchange(wr_dbus_wchange),						
		
		.o_dbus_wack_sel(wr_dbus_wack_sel),						
		.o_dbus_wack(wr_dbus_wack),								

		.o_dbus_wrq(wr_dbus_wrq),								
		.o_dbus_wdata(wr_dbus_wdata),							
		.o_dbus_wvalid(wr_dbus_wvalid),							
		.o_dbus_wlast(wr_dbus_wlast),							
		.i_dbus_wready(wr_dbus_wready),							
		.i_dbus_wstop(wr_dbus_wstop),							
		.i_dbus_wbusy(wr_dbus_wbusy)							
	);

	IIC_Write_Data IIC_Write_Data_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),

		.i_mbus_wstart(wr_dbus_wstart),							
		.i_mbus_wstop(wr_dbus_wstop_is),						
		.i_mbus_wchange(wr_dbus_wchange),						
		.i_mbus_whc(flag_scl_hc),								
		.i_mbus_wlc(flag_scl_lc),								

		.i_mbus_wack_sel(wr_dbus_wack_sel),						
		.i_mbus_wack(wr_dbus_wack),								

		.i_mbus_wrq(wr_dbus_wrq),								
		.i_mbus_wdata(wr_dbus_wdata),							
		.i_mbus_wvalid(wr_dbus_wvalid),							
		.i_mbus_wlast(wr_dbus_wlast),							
		.o_mbus_wready(wr_dbus_wready),							
		.o_mbus_wstop(wr_dbus_wstop),							
		.o_mbus_wbusy(wr_dbus_wbusy),							
	
		.i_iic_sda(i_iic_sda),									
		.o_iic_sda(wr_dbus_iic_sda),							
		.o_iic_sda_dir(wr_dbus_iic_sda_dir)						
	);

	IIC_Read_Data IIC_Read_Data_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
			
		.i_mbus_rstop(rd_dbus_rstop),							
		.i_mbus_rhc(flag_scl_hc),								
		.i_mbus_rlc(flag_scl_lc),								

		.i_mbus_rack(i_mbus_rack),								

		.i_mbus_rrq(rd_dbus_rrq),								
		.i_mbus_rlast(rd_dbus_rlast),							
		.i_mbus_rready(i_mbus_rready),							
		.o_mbus_rdata(rd_dbus_rdata),							
		.o_mbus_rvalid(rd_dbus_rvalid),							
		.o_mbus_rbusy(rd_dbus_rbusy),							

		.i_iic_sda(i_iic_sda),									
		.o_iic_sda(rd_dbus_iic_sda),							
		.o_iic_sda_dir(rd_dbus_iic_sda_dir)						
	);
		
	Clock_Interface	#(	
		.FACTOR_BIT(FACTOR_BIT),
		.CLOCK_MODE(CLOCK_MODE),
		.NEGEDGE_ENABLE(NEGEDGE_ENABLE),
		.DIVIDER_MODE(DIVIDER_MODE)
	)Clock_Interface_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),

		.o_clk_out(clk_IIC),
		.o_clk_ls(),							
		.o_clk_lc(),							
		.o_clk_hs(),							
		.o_clk_hc(),							

		.i_clk_dividend(CLOCK_FACTOR),			
		.i_clk_divisor(0),						
		.i_clk_quotient(0),						
		.i_clk_remainder(0)						
	);
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			clk_IIC_buffer <= 2'd0;
		end else begin
			clk_IIC_buffer <= {clk_IIC_buffer[0],clk_IIC};
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			wr_mbus_wbusy_buff <= 2'd0;
			rd_dbus_rbusy_buff <= 2'd0;
		end else begin
			wr_mbus_wbusy_buff <= {wr_mbus_wbusy_buff[0],wr_mbus_wbusy};
			rd_dbus_rbusy_buff <= {rd_dbus_rbusy_buff[0],rd_dbus_rbusy};
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_rwmode_i <= 1'b0;
			mbus_rready_i <= 1'b0;
			mbus_rlast_i <= 1'b0;
		end else begin
			mbus_rwmode_i <= i_mbus_rwmode;
			mbus_rready_i <= i_mbus_rready;
			mbus_rlast_i <= i_mbus_rlast;
		end
	end

endmodule

	
module IIC_Write_Ctrl
(
	input i_clk,
	input i_rstn,
	
	input [1:0]i_mbus_wslave_addr_mode,		
	input i_mbus_waddr_mode,				
	input i_mbus_wack_enable,				
	input i_mbus_wack,			        	
	input [3:0]i_mbus_wmode,				
	
	input [7:0]i_mbus_wslave_addr,			
	input [7:0]i_mbus_waddr_h,				
	input [7:0]i_mbus_waddr_l,				
	
	input i_mbus_wrq,						
	input [7:0]i_mbus_wdata,				
	input i_mbus_wvalid,					
	input i_mbus_wlast,						
	output o_mbus_wready,					
	output o_mbus_werr,						
	output o_mbus_wbusy,					
	
	output o_dbus_wstart,					
	output o_dbus_wstop,					
	output o_dbus_wchange,					
		
	output o_dbus_wack_sel,					
	output o_dbus_wack,						
	
	output o_dbus_wrq,						
	output [7:0]o_dbus_wdata,				
	output o_dbus_wvalid,					
	output o_dbus_wlast,					
	input i_dbus_wready,					
	input i_dbus_wstop,						
	input i_dbus_wbusy						
);
		
	localparam ST_WR_IDLE = 7'b0000001;
	localparam ST_WR_SADDR = 7'b0000010;
	localparam ST_WR_ADDR_H = 7'b0000100;
	localparam ST_WR_ADDR_L = 7'b0001000;
	localparam ST_WR_DATA = 7'b0010000;
	localparam ST_WR_WAIT = 7'b0100000;
	localparam ST_WR_END = 7'b1000000;
	
	reg [6:0]state_current = ST_WR_IDLE;
	reg [6:0]state_next = ST_WR_IDLE;

	reg mbus_waddr_mode_i = 0;
	reg [3:0]mbus_wmode_i = 0;

	reg [7:0]mbus_wslave_addr_i = 0;
	reg [7:0]mbus_waddr_h_i = 0;
	reg [7:0]mbus_waddr_l_i = 0;

	reg [7:0]mbus_wdata_i = 0;
	reg mbus_wvalid_i = 0;
	reg mbus_wlast_i = 0;
	
		
	reg [1:0]dbus_wready_i = 0;
	reg dbus_wstop_i = 0;
	reg [1:0]dbus_wbusy_i = 0;

	reg mbus_wready_o = 0;
	reg mbus_werr_o = 0;
	reg mbus_wbusy_o = 0;

	reg dbus_wstart_o = 0;
	reg dbus_wstop_o = 0;
	reg dbus_wchange_o = 0;
	
	reg dbus_wrq_o = 0;
	reg [7:0]dbus_wdata_o = 0;
	reg dbus_wvalid_o = 0;
	reg dbus_wlast_o = 0;
	
	assign o_mbus_wready = mbus_wready_o;
	assign o_mbus_werr = mbus_werr_o;
	assign o_mbus_wbusy = mbus_wbusy_o;
	
	assign o_dbus_wstart = dbus_wstart_o;
	assign o_dbus_wstop = dbus_wstop_o;
	assign o_dbus_wchange = dbus_wchange_o;
	
	assign o_dbus_wack_sel = i_mbus_wack_enable;
	assign o_dbus_wack = i_mbus_wack;
	
	assign o_dbus_wrq = dbus_wrq_o;
	assign o_dbus_wdata = dbus_wdata_o;
	assign o_dbus_wvalid = dbus_wvalid_o;
	assign o_dbus_wlast = dbus_wlast_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wready_o <= 1'b0;
		else if(state_current == ST_WR_DATA)mbus_wready_o <=  dbus_wready_i[0] | dbus_wready_i[1];
		else mbus_wready_o <= 1'b0;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_werr_o <= 1'b0;
		else if(dbus_wbusy_i == 2'b10 && dbus_wstop_i == 1'b1)mbus_werr_o <= 1'b1;
		else if(state_current == ST_WR_SADDR)mbus_werr_o <= 1'b0;
		else mbus_werr_o <= mbus_werr_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_END)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_SADDR)mbus_wbusy_o <= 1'b1;
		else mbus_wbusy_o <= mbus_wbusy_o;
	end
		
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(i_mbus_wrq == 1'b1)state_next <= ST_WR_SADDR;
				else state_next <= ST_WR_IDLE;
			end
			ST_WR_SADDR:begin
				if(mbus_wmode_i[2] == 1'b1 && dbus_wready_i == 2'b10)state_next <= ST_WR_WAIT;				
				else if(mbus_waddr_mode_i == 1'b1 && dbus_wready_i == 2'b10)state_next <= ST_WR_ADDR_H;		
				else if(dbus_wready_i == 2'b10)state_next <= ST_WR_ADDR_L;									
				else state_next <= ST_WR_SADDR;
			end
			ST_WR_ADDR_H:begin
				if(dbus_wready_i == 2'b10)state_next <= ST_WR_ADDR_L;
				else state_next <= ST_WR_ADDR_H;
			end
			ST_WR_ADDR_L:begin
				if(mbus_wmode_i[3] == 1'b1 && dbus_wready_i == 2'b10)state_next <= ST_WR_WAIT;			
				else if(dbus_wready_i == 2'b10)state_next <= ST_WR_DATA;
				else state_next <= ST_WR_ADDR_L;
			end
			ST_WR_DATA:begin
				if(dbus_wready_i == 2'b01 && mbus_wlast_i == 1'b1)state_next <= ST_WR_WAIT;			
				else state_next <= ST_WR_DATA;
			end
			ST_WR_WAIT:begin
				if(dbus_wbusy_i == 2'b10)state_next <= ST_WR_END;			
				else state_next <= ST_WR_WAIT;
			end
			ST_WR_END:state_next <= ST_WR_IDLE;
			default:state_next <= ST_WR_IDLE;
		endcase
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_WR_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wstart_o <= 1'b0;
		else if(state_current == ST_WR_SADDR)dbus_wstart_o <= 1'b1;
		else if(dbus_wready_i == 2'b01)dbus_wstart_o <= 1'b0;
		else dbus_wstart_o <= dbus_wstart_o;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wstop_o <= 1'b0;
		else if(state_current == ST_WR_WAIT)dbus_wstop_o <= mbus_wmode_i[0] | mbus_wmode_i[1];
		else dbus_wstop_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wchange_o <= 1'b0;
		else if(state_current == ST_WR_WAIT)dbus_wchange_o <= mbus_wmode_i[0] | mbus_wmode_i[1] | mbus_wmode_i[2] | mbus_wmode_i[3];
		else dbus_wchange_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wrq_o <= 1'b0;
		else if(state_current == ST_WR_SADDR)dbus_wrq_o <= 1'b1;
		else dbus_wrq_o <= 1'b0;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wdata_o <= 8'd0;
		else if(state_current == ST_WR_SADDR)dbus_wdata_o <= mbus_wslave_addr_i;
		else if(state_current == ST_WR_ADDR_H)dbus_wdata_o <= mbus_waddr_h_i;
		else if(state_current == ST_WR_ADDR_L)dbus_wdata_o <= mbus_waddr_l_i;
		else if(state_current == ST_WR_DATA)dbus_wdata_o <= mbus_wdata_i;
		else dbus_wdata_o <= dbus_wdata_o;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wvalid_o <= 1'b0;
		else if(dbus_wready_i == 2'b00)dbus_wvalid_o <= 1'b0;
		else if(state_current == ST_WR_IDLE)dbus_wvalid_o <= 1'b0;
		else if(state_current == ST_WR_WAIT)dbus_wvalid_o <= 1'b0;
		else if(state_current == ST_WR_END)dbus_wvalid_o <= 1'b0;
		else if(state_current == ST_WR_DATA)dbus_wvalid_o <= mbus_wvalid_i;
		else dbus_wvalid_o <= 1'b1;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wlast_o <= 1'b0;
		else if(state_current == ST_WR_WAIT)dbus_wlast_o <= 1'b1;
		else dbus_wlast_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_wslave_addr_i <= 8'd0;
		end else if(i_mbus_wslave_addr_mode[0] == 1'b0)begin
			mbus_wslave_addr_i <= {i_mbus_wslave_addr[6:0],i_mbus_wslave_addr_mode[1]};
		end else begin
			mbus_wslave_addr_i <= i_mbus_wslave_addr | {7'd0,i_mbus_wslave_addr_mode[1]};
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_waddr_mode_i <= 1'b0;
			mbus_wmode_i <= 4'd0;
			mbus_waddr_h_i <= 8'd0;
			mbus_waddr_l_i <= 8'd0;
			mbus_wdata_i <= 8'd0;
			mbus_wvalid_i <= 1'b0;
			mbus_wlast_i <= 1'b0;
		end else begin
			mbus_waddr_mode_i <= i_mbus_waddr_mode;
			mbus_wmode_i <= i_mbus_wmode;
			mbus_waddr_h_i <= i_mbus_waddr_h;
			mbus_waddr_l_i <= i_mbus_waddr_l;
			mbus_wdata_i <= i_mbus_wdata;
			mbus_wvalid_i <= i_mbus_wvalid;
			mbus_wlast_i <= i_mbus_wlast;
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dbus_wready_i <= 2'd0;
			dbus_wstop_i <= 1'b0;
			dbus_wbusy_i <= 2'd0;
		end else begin
			dbus_wready_i <= {dbus_wready_i[0],i_dbus_wready};
			dbus_wstop_i <= i_dbus_wstop;
			dbus_wbusy_i <= {dbus_wbusy_i[0],i_dbus_wbusy};
		end
	end
	
endmodule

	
module IIC_Write_Data
(
	input i_clk,
	input i_rstn,
		
	input i_mbus_wstart,					
	input i_mbus_wstop,						
	input i_mbus_wchange,					
	input i_mbus_whc,						
	input i_mbus_wlc,						
	
	input i_mbus_wack_sel,					
	input i_mbus_wack,						
	
	input i_mbus_wrq,						
	input [7:0]i_mbus_wdata,				
	input i_mbus_wvalid,					
	input i_mbus_wlast,						
	output o_mbus_wready,					
	output o_mbus_wstop,					
	output o_mbus_wbusy,					
	
	input i_iic_sda,						
	output o_iic_sda,						
	output o_iic_sda_dir					
);
	localparam ST_WR_IDLE = 2'd0;
	localparam ST_WR_DATA = 2'd1;
	localparam ST_WR_WAIT = 2'd2;
	localparam ST_WR_END = 2'd3;
	
	reg dbus_wrq = 0;
	reg [7:0]dbus_wdata = 0;
	wire dbus_wbusy;
	wire dbus_wnack;
	
	reg [1:0]dbus_wbusy_buff = 0;
	reg dbus_wnack_buff = 0;
	
	reg [1:0]state_current = ST_WR_IDLE;
	reg [1:0]state_next = ST_WR_IDLE;
	
	reg [7:0]mbus_wdata_i = 0;
	reg mbus_wvalid_i = 0;
	reg mbus_wlast_i = 0;
	
	reg mbus_wready_o = 0;
	reg mbus_wstop_o = 0;
	reg mbus_wbusy_o = 0;
	
	assign o_mbus_wready = mbus_wready_o;
	assign o_mbus_wstop = mbus_wstop_o;
	assign o_mbus_wbusy = mbus_wbusy_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wready_o <= 1'b0;
		else if(state_current == ST_WR_DATA && dbus_wbusy_buff == 2'b00)mbus_wready_o <= 1'b1;
		else mbus_wready_o <= 1'b0;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wstop_o <= 1'b0;
		else if(dbus_wbusy_buff == 2'b10 && dbus_wnack_buff == 1'b1)mbus_wstop_o <= 1'b1;
		else if(state_current == ST_WR_IDLE)mbus_wstop_o <= 1'b0;
		else mbus_wstop_o <= mbus_wstop_o;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_END)mbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_DATA)mbus_wbusy_o <= 1'b1;
		else mbus_wbusy_o <= mbus_wbusy_o;
	end
	
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(i_mbus_wrq == 1'b1)state_next <= ST_WR_DATA;
				else state_next <= ST_WR_IDLE;
			end
			ST_WR_DATA:begin
				if(mbus_wlast_i == 1'b1)state_next <= ST_WR_WAIT;
				else state_next <= ST_WR_DATA;
			end
			ST_WR_WAIT:begin
				if(dbus_wbusy_buff == 2'b10)state_next <= ST_WR_END;
				else state_next <= ST_WR_WAIT;
			end
			ST_WR_END:state_next <= ST_WR_IDLE;
		endcase
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_WR_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wrq <= 1'b0;
		else if(dbus_wbusy_buff == 2'b11)dbus_wrq <= 1'b0;
		else if(state_current == ST_WR_DATA && mbus_wvalid_i == 1'b1)dbus_wrq <= 1'b1;
		else dbus_wrq <= dbus_wrq;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wdata <= 8'd0;
		else if(state_current == ST_WR_DATA && mbus_wvalid_i == 1'b1)dbus_wdata <= mbus_wdata_i;
		else dbus_wdata <= dbus_wdata;
	end
	
	IIC_Send_Byte IIC_Send_Byte_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		
		.i_dbus_wstart(i_mbus_wstart),			
		.i_dbus_wstop(i_mbus_wstop),			
		.i_dbus_wchange(i_mbus_wchange),		
		.i_dbus_whc(i_mbus_whc),				
		.i_dbus_wlc(i_mbus_wlc),				
		
		.i_dbus_wack_sel(i_mbus_wack_sel),		
		.i_dbus_wack(i_mbus_wack),				
		
		.i_dbus_wrq(dbus_wrq),					
		.i_dbus_wdata(dbus_wdata),				
		.o_dbus_wbusy(dbus_wbusy),				
		.o_dbus_nack(dbus_wnack),				

		.i_iic_sda(i_iic_sda),					
		.o_iic_sda(o_iic_sda),					
		.o_iic_sda_dir(o_iic_sda_dir)			
	);
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dbus_wbusy_buff <= 2'd0;
			dbus_wnack_buff <= 1'b0;
		end else begin
			dbus_wbusy_buff <= {dbus_wbusy_buff[0],dbus_wbusy};
			dbus_wnack_buff <= dbus_wnack;
		end
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_wdata_i <= 8'd0;
			mbus_wvalid_i <= 1'b0;
			mbus_wlast_i <= 1'b0;
		end else begin
			mbus_wdata_i <= i_mbus_wdata;
			mbus_wvalid_i <= i_mbus_wvalid;
			mbus_wlast_i <= i_mbus_wlast;
		end
	end
	
endmodule

	
module IIC_Read_Data
(
	input i_clk,
	input i_rstn,
	
	input i_mbus_rstop,						
	input i_mbus_rhc,						
	input i_mbus_rlc,						
	
	input i_mbus_rack,						
	
	input i_mbus_rrq,						
	input i_mbus_rlast,						
	input i_mbus_rready,					
	output [7:0]o_mbus_rdata,				
	output o_mbus_rvalid,					
	output o_mbus_rbusy,					
	
	input i_iic_sda,						
	output o_iic_sda,						
	output o_iic_sda_dir					
);
		
	localparam ST_RD_IDLE = 2'd0;
	localparam ST_RD_DATA = 2'd1;
	localparam ST_RD_WAIT = 2'd2;
	localparam ST_RD_END = 2'd3;
		
	reg dbus_rrq = 0;
	wire [7:0]dbus_rdata;
	wire dbus_rbusy;
		
	reg [1:0]dbus_rbusy_buff = 0;
		
	reg [1:0]state_current = ST_RD_IDLE;
	reg [1:0]state_next = ST_RD_IDLE;
		
	reg mbus_rready_i = 0;
	reg mbus_rlast_i = 0;
		
	reg [7:0]mbus_rdata_o = 0;
	reg mbus_rvalid_o = 0;
	reg mbus_rbusy_o = 0;
		
	assign o_mbus_rdata = mbus_rdata_o;
	assign o_mbus_rvalid = mbus_rvalid_o;
	assign o_mbus_rbusy = mbus_rbusy_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rdata_o <= 8'd0;
		else if(dbus_rbusy_buff == 2'b10)mbus_rdata_o <= dbus_rdata;
		else mbus_rdata_o <= mbus_rdata_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rvalid_o <= 1'b0;
		else if(dbus_rbusy_buff == 2'b10)mbus_rvalid_o <= 1'b1;
		else mbus_rvalid_o <= 1'b0;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)mbus_rbusy_o <= 1'b0;
		else if(state_current == ST_RD_END)mbus_rbusy_o <= 1'b0;
		else if(state_current == ST_RD_DATA)mbus_rbusy_o <= 1'b1;
		else mbus_rbusy_o <= mbus_rbusy_o;
	end
		
	always@(*)begin
		case(state_current)
			ST_RD_IDLE:begin
				if(i_mbus_rrq == 1'b1)state_next <= ST_RD_DATA;
				else state_next <= ST_RD_IDLE;
			end
			ST_RD_DATA:begin
				if(mbus_rlast_i == 1'b1)state_next <= ST_RD_WAIT;
				else state_next <= ST_RD_DATA;
			end
			ST_RD_WAIT:begin
				if(dbus_rbusy_buff == 2'b10)state_next <= ST_RD_END;
				else state_next <= ST_RD_WAIT;
			end
			ST_RD_END:state_next <= ST_RD_IDLE;
		endcase
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_RD_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_rrq <= 1'b0;
		else if(dbus_rbusy_buff == 2'b11)dbus_rrq <= 1'b0;
		else if(state_current == ST_RD_DATA && mbus_rready_i == 1'b1)dbus_rrq <= 1'b1;
		else dbus_rrq <= dbus_rrq;
	end

	IIC_Recv_Byte IIC_Recv_Byte_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		
		.i_dbus_rstop(i_mbus_rstop),			
		.i_dbus_rhc(i_mbus_rhc),				
		.i_dbus_rlc(i_mbus_rlc),				
			
		.i_dbus_rack(i_mbus_rack),				
		
		.i_dbus_rrq(dbus_rrq),					
		.o_dbus_rdata(dbus_rdata),				
		.o_dbus_rbusy(dbus_rbusy),				
		
		.i_iic_sda(i_iic_sda),					
		.o_iic_sda(o_iic_sda),					
		.o_iic_sda_dir(o_iic_sda_dir)			
	);
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dbus_rbusy_buff <= 2'd0;
		end else begin
			dbus_rbusy_buff <= {dbus_rbusy_buff[0],dbus_rbusy};
		end
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_rready_i <= 1'b0;
			mbus_rlast_i <= 1'b0;
		end else begin
			mbus_rready_i <= i_mbus_rready;
			mbus_rlast_i <= i_mbus_rlast;
		end
	end
	
endmodule

	
module IIC_Send_Byte(
	input i_clk,
	input i_rstn,
	
	input i_dbus_wstart,					
	input i_dbus_wstop,						
	input i_dbus_wchange,					
	input i_dbus_whc,						
	input i_dbus_wlc,						
	
	input i_dbus_wack_sel,					
	input i_dbus_wack,						
	
	input i_dbus_wrq,						
	input [7:0]i_dbus_wdata,				
	output o_dbus_wbusy,					
	output o_dbus_nack,						
	
	input i_iic_sda,						
	output o_iic_sda,						
	output o_iic_sda_dir					
);
	localparam ST_WR_IDLE = 6'b000001;
	localparam ST_WR_START = 6'b000010;
	localparam ST_WR_DATA = 6'b000100;
	localparam ST_WR_ACK = 6'b001000;
	localparam ST_WR_STOP = 6'b010000;
	localparam ST_WR_END = 6'b100000;
		
	reg [3:0]send_cnt = 0;
	
	reg [5:0]state_current = ST_WR_IDLE;
	reg [5:0]state_next = ST_WR_IDLE;
	
	reg dbus_wstart_i = 0;
	reg dbus_wstop_i = 0;
	reg dbus_wchange_i = 0;
	reg dbus_whc_i = 0;
	reg dbus_wlc_i = 0;
	
	reg dbus_wack_sel_i = 0;
	reg dbus_wack_i = 0;
	
	reg [7:0]dbus_wdata_i = 0;
	
	reg iic_sda_i = 0;
	
	reg dbus_wbusy_o = 1'b0;
	reg dbus_nack_o = 1'b0;
	
	reg iic_sda_o = 1'b1;
	reg iic_sda_dir_o = 0;
	
	assign o_dbus_wbusy = dbus_wbusy_o;
	assign o_dbus_nack = dbus_nack_o;
	
	assign o_iic_sda = iic_sda_o;
	assign o_iic_sda_dir = iic_sda_dir_o;
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_wbusy_o <= 1'b0;
		else if(state_current == ST_WR_START)dbus_wbusy_o <= 1'b1;
		else if(state_current == ST_WR_DATA)dbus_wbusy_o <= 1'b1;
		else if(state_current == ST_WR_END)dbus_wbusy_o <= 1'b0;
		else dbus_wbusy_o <= dbus_wbusy_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_nack_o <= 1'b0;
		else if(state_current == ST_WR_DATA)dbus_nack_o <= 1'b0;
		else if(state_current == ST_WR_ACK && dbus_wlc_i == 1'b1 && dbus_wack_sel_i == 1'b1)dbus_nack_o <= (dbus_wack_i ^ iic_sda_i);
		else dbus_nack_o <= dbus_nack_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)iic_sda_o <= 1'b1;
		else if(state_next == ST_WR_IDLE)iic_sda_o <= 1'b1;
		else if(state_next == ST_WR_START)iic_sda_o <= 1'b0;
		else if(state_next == ST_WR_DATA && dbus_wlc_i == 1'b1)iic_sda_o <= dbus_wdata_i[7 - send_cnt[2:0]];
		else if(state_next == ST_WR_ACK)iic_sda_o <= 1'b1;
		else if(state_next == ST_WR_STOP && dbus_wlc_i == 1'b1)iic_sda_o <= 1'b0;
		else if(state_next == ST_WR_STOP && dbus_whc_i == 1'b1)iic_sda_o <= 1'b1;
		else iic_sda_o <= iic_sda_o;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)iic_sda_dir_o <= 1'b1;
		else if(state_next == ST_WR_DATA && send_cnt == 4'd0)iic_sda_dir_o <= dbus_wstart_i;
		else if(state_next == ST_WR_ACK)iic_sda_dir_o <= 1'b0;
		else iic_sda_dir_o <= 1'b1;
	end
	
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
				if(i_dbus_wrq == 1'b1 && dbus_wstart_i == 1'b0)state_next <= ST_WR_DATA;
				else if(i_dbus_wrq == 1'b1 && dbus_whc_i == 1'b1)state_next <= ST_WR_START;
				else state_next <= ST_WR_IDLE;
			end
			ST_WR_START:begin
				if(dbus_wlc_i == 1'b1)state_next <= ST_WR_DATA;
				else state_next <= ST_WR_START;
			end
			ST_WR_DATA:begin
				if(dbus_wlc_i == 1'b1 && send_cnt == 4'd8)state_next <= ST_WR_ACK;
				else state_next <= ST_WR_DATA;
			end
			ST_WR_ACK:begin
				if(dbus_wlc_i == 1'b0 && dbus_wchange_i == 1'b1)state_next <= ST_WR_ACK;
				else if(dbus_wack_sel_i == 1'b0 && dbus_wstop_i == 1'b0)state_next <= ST_WR_END;
				else if(dbus_wack_sel_i == 1'b1 && dbus_wack_i == iic_sda_i && dbus_wstop_i == 1'b0)state_next <= ST_WR_END;
				else state_next <= ST_WR_STOP;
			end
			ST_WR_STOP:begin
				if(dbus_wlc_i == 1'b1)state_next <= ST_WR_END;
				else state_next <= ST_WR_STOP;
			end
			ST_WR_END:state_next <= ST_WR_IDLE;
			default:state_next <= ST_WR_IDLE;
		endcase
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_WR_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)send_cnt <= 4'd0;
		else if(state_next == ST_WR_DATA && dbus_wlc_i == 1'b1)send_cnt <= send_cnt + 4'd1;
		else if(state_next == ST_WR_DATA)send_cnt <= send_cnt;
		else send_cnt <= 4'd0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dbus_wstart_i <= 1'b0;
			dbus_wstop_i <= 1'b0;
			dbus_wchange_i <= 1'b0;
			dbus_whc_i <= 1'b0;
			dbus_wlc_i <= 1'b0;
			dbus_wack_sel_i <= 1'b0;
			dbus_wack_i <= 1'b0;
			dbus_wdata_i <= 8'd0;
			iic_sda_i <= 1'b0;
		end else begin
			dbus_wstart_i <= i_dbus_wstart;
			dbus_wstop_i <= i_dbus_wstop;
			dbus_wchange_i <= i_dbus_wchange;
			dbus_whc_i <= i_dbus_whc;
			dbus_wlc_i <= i_dbus_wlc;
			dbus_wack_sel_i <= i_dbus_wack_sel;
			dbus_wack_i <= i_dbus_wack;
			dbus_wdata_i <= i_dbus_wdata;
			iic_sda_i <= i_iic_sda;
		end
	end
	
endmodule

	
module IIC_Recv_Byte(
	input i_clk,
	input i_rstn,
	
	input i_dbus_rstop,						
	input i_dbus_rhc,						
	input i_dbus_rlc,						
	
	input i_dbus_rack,						
		
	input i_dbus_rrq,						
	output [7:0]o_dbus_rdata,				
	output o_dbus_rbusy,					
	
	input i_iic_sda,						
	output o_iic_sda,						
	output o_iic_sda_dir					
);
	
	localparam ST_RD_IDLE = 5'b00001;
	localparam ST_RD_DATA = 5'b00010;
	localparam ST_RD_ACK = 5'b00100;
	localparam ST_RD_STOP = 5'b01000;
	localparam ST_RD_END = 5'b10000;
	
	reg [7:0]read_data = 0;
		
	reg [3:0]recv_cnt = 0;
		
	reg [4:0]state_current = ST_RD_IDLE;
	reg [4:0]state_next = ST_RD_IDLE;
		
	reg dbus_rstop_i = 0;
	reg dbus_rhc_i = 0;
	reg dbus_rlc_i = 0;
		
	reg dbus_rack_i = 0;
		
	reg iic_sda_i = 0;
	
	reg [7:0]dbus_rdata_o = 0;
	reg dbus_rbusy_o = 0;
	
	reg iic_sda_o = 1'b1;
	reg iic_sda_dir_o = 0;
		
	assign o_dbus_rdata = dbus_rdata_o;
	assign o_dbus_rbusy = dbus_rbusy_o;
	
	assign o_iic_sda = iic_sda_o;
	assign o_iic_sda_dir = iic_sda_dir_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_rdata_o <= 8'd0;
		else if(state_current == ST_RD_END)dbus_rdata_o <= read_data;
		else dbus_rdata_o <= dbus_rdata_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)dbus_rbusy_o <= 1'b0;
		else if(state_current == ST_RD_END)dbus_rbusy_o <= 1'b0;
		else if(state_current == ST_RD_DATA)dbus_rbusy_o <= 1'b1;
		else dbus_rbusy_o <= dbus_rbusy_o;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)iic_sda_o <= 1'b1;
		else if(state_next == ST_RD_DATA)iic_sda_o <= 1'b1;
		else if(state_next == ST_RD_ACK)iic_sda_o <= dbus_rack_i;
		else if(state_next == ST_RD_STOP && dbus_rlc_i == 1'b1)iic_sda_o <= 1'b0;
		else if(state_next == ST_RD_STOP && dbus_rhc_i == 1'b1)iic_sda_o <= 1'b1;
		else iic_sda_o <= iic_sda_o;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)iic_sda_dir_o <= 1'b1;
		else if(state_next == ST_RD_DATA)iic_sda_dir_o <= 1'b0;
		else iic_sda_dir_o <= 1'b1;
	end
	
	always@(*)begin
		case(state_current)
			ST_RD_IDLE:begin
				if(i_dbus_rrq == 1'b1)state_next <= ST_RD_DATA;
				else state_next <= ST_RD_IDLE;
			end
			ST_RD_DATA:begin
				if(dbus_rlc_i == 1'b1 && recv_cnt == 4'd8)state_next <= ST_RD_ACK;
				else state_next <= ST_RD_DATA;
			end
			ST_RD_ACK:begin
				if(dbus_rlc_i == 1'b0 && dbus_rstop_i == 1'b1)state_next <= ST_RD_ACK;
				else if(dbus_rstop_i == 1'b1)state_next <= ST_RD_STOP;
				else state_next <= ST_RD_END;
			end
			ST_RD_STOP:begin
				if(dbus_rlc_i == 1'b1)state_next <= ST_RD_END;
				else state_next <= ST_RD_STOP;
			end
			ST_RD_END:state_next <= ST_RD_IDLE;
			default:state_next <= ST_RD_IDLE;
		endcase
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_RD_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)recv_cnt <= 4'd0;
		else if(state_next == ST_RD_DATA && dbus_rhc_i == 1'b1)recv_cnt <= recv_cnt + 4'd1;
		else if(state_next == ST_RD_DATA)recv_cnt <= recv_cnt;
		else recv_cnt <= 4'd0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)read_data <= 8'd0;
		else if(state_next == ST_RD_DATA && dbus_rhc_i == 1'b1)read_data <= {read_data[6:0],iic_sda_i};
		else read_data <= read_data;
	end
		
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dbus_rstop_i <= 1'b0;
			dbus_rhc_i <= 1'b0;
			dbus_rlc_i <= 1'b0;
			dbus_rack_i <= 1'b0;
			iic_sda_i <= 1'b0;
		end else begin
			dbus_rstop_i <= i_dbus_rstop;
			dbus_rhc_i <= i_dbus_rhc;
			dbus_rlc_i <= i_dbus_rlc;
			dbus_rack_i <= i_dbus_rack;
			iic_sda_i <= i_iic_sda;
		end
	end
	
endmodule