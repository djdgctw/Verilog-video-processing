`timescale 1ns / 1ps
// Company:			TWX Techonology Co., Ltd.
// Engineer:		Erie
// 
// Create Date: 	2019/09/24 09:24:15
// Design Name: 	Clock Division
// Module Name: 	Clock_Interface
// Description: 	None
// 
// Dependencies: 	None
//
// Version:			V2.3
// Revision Date:	2021/10/15 21:06:24


module Clock_Interface
#(
	parameter FACTOR_BIT = 5'd31,
	parameter CLOCK_MODE = 1'b0,		
	parameter NEGEDGE_ENABLE = 1'b0,	
	parameter DIVIDER_MODE = 4'b0001	
)
(
	input i_clk,
	input i_rstn,

	output o_clk_out,							
	output o_clk_ls,							
	output o_clk_lc,							
	output o_clk_hs,							
	output o_clk_hc,							

	input [FACTOR_BIT - 1:0]i_clk_dividend,		
	input [FACTOR_BIT - 1:0]i_clk_divisor,		
	input [FACTOR_BIT - 1:0]i_clk_quotient,		
	input [FACTOR_BIT - 1:0]i_clk_remainder		
);

	wire clk_out_even;			
	wire clk_out_odd;			

	reg [FACTOR_BIT - 1:0]clk_cnt = 0;

	reg resetn_even = 0;		
	reg resetn_odd = 0;			

	reg [FACTOR_BIT - 1:0]factor_odd = 0;
	reg [FACTOR_BIT - 1:0]factor_even = 0;
	reg [FACTOR_BIT - 1:0]factor_odd_num = 0;
	reg [FACTOR_BIT - 1:0]factor_even_num = 0;
	reg [FACTOR_BIT * 2 - 1:0]factor_cal_num = 0;
	
	reg [FACTOR_BIT - 1:0]clk_dividend_i = {FACTOR_BIT{1'b0}} + 1;
	
	reg clk_out_o = 0;
	
	always@(*) begin
		if(clk_cnt <= factor_cal_num)clk_out_o <= clk_out_odd;
		else clk_out_o <= clk_out_even;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)resetn_even <= 1'b0;
		else if(clk_cnt == factor_cal_num - 1)resetn_even <= 1'b1;
		else if(clk_cnt == clk_dividend_i - 1)resetn_even <= 1'b0;
		else resetn_even <= resetn_even;
	end

	always@(negedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)resetn_odd <= 1'b0;
		else if(clk_cnt == factor_cal_num - 1)resetn_odd <= 1'b0;
		else if(clk_cnt == clk_dividend_i)resetn_odd <= 1'b1;
		else resetn_odd <= resetn_odd;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_cnt <= {FACTOR_BIT{1'b0}};
		else if(clk_cnt == clk_dividend_i)clk_cnt <= {FACTOR_BIT{1'b0}} + 1;
		else clk_cnt <= clk_cnt + 1;
	end

	generate if(DIVIDER_MODE[0] == 1'b1)begin : gen_clock_divider_integer
		
		Clock_Divider_Integer #(.FACTOR_BIT(FACTOR_BIT),.CLOCK_MODE(CLOCK_MODE),
								.NEGEDGE_ENABLE(NEGEDGE_ENABLE))Clock_Divider_Integer_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_clk_mode(i_clk_dividend),		

			.o_clk_out(o_clk_out),				
			.o_clk_ls(o_clk_ls),				
			.o_clk_lc(o_clk_lc),				
			.o_clk_hs(o_clk_hs),				
			.o_clk_hc(o_clk_hc)					
		);
		
		assign clk_out_odd = 1'b0;
		assign clk_out_even = 1'b0;
	end else if(DIVIDER_MODE[1] == 1'b1)begin : gen_clock_divider_even
		
		Clock_Divider_Even #(.FACTOR_BIT(FACTOR_BIT))Clock_Divider_Even_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_clk_mode(clk_dividend_i),		

			.o_clk_out(o_clk_out),				
			.o_clk_ls(o_clk_ls),				
			.o_clk_lc(o_clk_lc),				
			.o_clk_hs(o_clk_hs),				
			.o_clk_hc(o_clk_hc)					
		);
		
		assign clk_out_odd = 1'b0;
		assign clk_out_even = 1'b0;
	end else if(DIVIDER_MODE[2] == 1'b1)begin : gen_clock_divider_odd
		
		Clock_Divider_Odd #(.FACTOR_BIT(FACTOR_BIT))Clock_Divider_Odd_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_clk_mode(clk_dividend_i),		
			
			
			.o_clk_out(o_clk_out),				
			.o_clk_ls(o_clk_ls),				
			.o_clk_lc(o_clk_lc),				
			.o_clk_hs(o_clk_hs),				
			.o_clk_hc(o_clk_hc)					
		);
		
		assign clk_out_odd = 1'b0;
		assign clk_out_even = 1'b0;
	end else if(DIVIDER_MODE[3] == 1'b1)begin : gen_clock_divider_fractional
		Clock_Divider_Even #(.FACTOR_BIT(FACTOR_BIT))Clock_Divider_Even_Inst(
			.i_clk(i_clk),
			.i_rstn(resetn_even),
			.i_clk_mode(factor_even),			

			.o_clk_out(clk_out_even),			
			.o_clk_ls(),						
			.o_clk_lc(),						
			.o_clk_hs(),						
			.o_clk_hc()							
		);
		
		Clock_Divider_Odd #(.FACTOR_BIT(FACTOR_BIT))Clock_Divider_Odd_Inst(
			.i_clk(i_clk),
			.i_rstn(resetn_odd),
			.i_clk_mode(factor_odd),			
			
			
			.o_clk_out(clk_out_odd),			
			.o_clk_ls(),						
			.o_clk_lc(),						
			.o_clk_hs(),						
			.o_clk_hc()							
		);
		
		assign o_clk_out = clk_out_o;
		assign o_clk_ls = 1'b0;
		assign o_clk_lc = 1'b0;
		assign o_clk_hs = 1'b0;
		assign o_clk_hc = 1'b0;
		
	end else begin
		assign clk_out_odd = 1'b0;
		assign clk_out_even = 1'b0;
		
		assign o_clk_out = 1'b0;
		assign o_clk_ls = 1'b0;
		assign o_clk_lc = 1'b0;
		assign o_clk_hs = 1'b0;
		assign o_clk_hc = 1'b0;
	end endgenerate

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			factor_odd <= {FACTOR_BIT{1'b0}};
			factor_even <= {FACTOR_BIT{1'b0}};
			factor_odd_num <= {FACTOR_BIT{1'b0}};
			factor_even_num <= {FACTOR_BIT{1'b0}};
			factor_cal_num <= {FACTOR_BIT{2'b00}} + 1;
		end else if(i_clk_quotient[0] == 1'b1)begin
			factor_odd <= i_clk_quotient;
			factor_odd_num <= i_clk_divisor - i_clk_remainder;
			factor_even <= i_clk_quotient + 1;
			factor_even_num <= i_clk_remainder;
			factor_cal_num <= i_clk_quotient * (i_clk_divisor - i_clk_remainder);
		end else begin
			factor_odd <= i_clk_quotient + 1;
			factor_odd_num <= i_clk_remainder;
			factor_even <= i_clk_quotient;
			factor_even_num <= i_clk_divisor - i_clk_remainder;
			factor_cal_num <= i_clk_remainder * (i_clk_quotient + 1);
		end
	end
	
    always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)begin
            clk_dividend_i <= {FACTOR_BIT{1'b0}} + 1;
        end else if(clk_cnt == 0 && i_clk_dividend != 0)begin
            clk_dividend_i <= i_clk_dividend;
        end else begin
            clk_dividend_i <= clk_dividend_i;
        end
    end
	
endmodule

module Clock_Divider_Integer
#(
	parameter FACTOR_BIT = 5'd31,
	parameter CLOCK_MODE = 1'b0,		
	parameter NEGEDGE_ENABLE = 1'b0		
)
(
    input i_clk,
    input i_rstn,
    input [FACTOR_BIT - 1:0]i_clk_mode,			
	
	output o_clk_out,							
	output o_clk_ls,							
	output o_clk_lc,							
	output o_clk_hs,							
	output o_clk_hc								
);
 
	reg clk_square = 0;				
	reg clk_pulse = 0;				
	
	reg [FACTOR_BIT - 1:0]clk_cnt = 0;
	
	reg [1:0]flg_half_buff = 0;			
	reg flg_start = 0;					
	
	reg [FACTOR_BIT - 1:0]freq_register = 0;
	
	reg clk_out_o = 0;
	reg clk_ls_o = 0;
	reg clk_lc_o = 0;
	reg clk_hs_o = 0;
	reg clk_hc_o = 0;
	
    assign o_clk_out = clk_out_o | flg_half_buff[1];
	assign o_clk_ls = clk_ls_o;
	assign o_clk_lc = clk_lc_o;
	assign o_clk_hs = clk_hs_o;
	assign o_clk_hc = clk_hc_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_out_o <= 1'b0;
		else if(CLOCK_MODE == 1'b0)clk_out_o <= clk_pulse;
		else clk_out_o <= clk_square;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_ls_o <= 1'b0;
		else if(flg_start == 1'b0)clk_ls_o <= 1'b0;
		else if(CLOCK_MODE == 1'b0 && clk_cnt == 0)clk_ls_o <= 1'b1;
		else if(CLOCK_MODE == 1'b1 && clk_cnt == 0 && clk_square == 1'b0)clk_ls_o <= 1'b1;
		else clk_ls_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_lc_o <= 1'b0;
		else if(flg_start == 1'b0)clk_lc_o <= 1'b0;
		else if(CLOCK_MODE == 1'b0 && clk_cnt == freq_register[FACTOR_BIT - 1:2])clk_lc_o <= 1'b1;
		else if(CLOCK_MODE == 1'b1 && clk_cnt == freq_register[FACTOR_BIT - 1:2] && clk_square == 1'b0)clk_lc_o <= 1'b1;
		else clk_lc_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hs_o <= 1'b0;
		else if(CLOCK_MODE == 1'b0 && clk_cnt == freq_register[FACTOR_BIT - 1:1])clk_hs_o <= 1'b1;
		else if(CLOCK_MODE == 1'b1 && clk_cnt == 0 && clk_square == 1'b1)clk_hs_o <= 1'b1;
		else clk_hs_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hc_o <= 1'b0;
		else if(flg_start == 1'b0)clk_hc_o <= 1'b0;
		else if(CLOCK_MODE == 1'b0 && clk_cnt == freq_register[FACTOR_BIT - 1:1] + freq_register[FACTOR_BIT - 1:2])clk_hc_o <= 1'b1;
		else if(CLOCK_MODE == 1'b1 && clk_cnt == freq_register[FACTOR_BIT - 1:2] && clk_square == 1'b1)clk_hc_o <= 1'b1;
		else clk_hc_o <= 1'b0;
	end
    
    always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)begin
            freq_register <= {FACTOR_BIT{1'b0}} + 1;
        end else if(clk_cnt == 0)begin
            freq_register <= i_clk_mode;
        end else begin
            freq_register <= freq_register;
        end
    end
	
    always@(negedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)flg_half_buff <= 2'd0;
		else if(NEGEDGE_ENABLE == 1'b0)flg_half_buff <= 2'd0;
        else if(clk_cnt == freq_register[FACTOR_BIT - 1:1] && freq_register[0] == 1'b1)flg_half_buff <= {flg_half_buff[0],1'b1};
        else flg_half_buff <= {flg_half_buff[0],1'b0};
    end
	
	always@(negedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)flg_start <= 1'b0;
		else if(flg_start == 1'b1)flg_start <= 1'b1;
		else if(clk_cnt == {FACTOR_BIT{1'b0}})flg_start <= 1'b0;
		else flg_start <= 1'b1;
    end
    
    always @(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)clk_cnt <= {FACTOR_BIT{1'b0}};
		else if(CLOCK_MODE == 1'b0 && clk_cnt == freq_register - 1)clk_cnt <= {FACTOR_BIT{1'b0}};
		else if(CLOCK_MODE == 1'b0)clk_cnt <= clk_cnt + 1;
        else if(freq_register[0] == 1'b1 && clk_cnt == freq_register - 1)clk_cnt <= {FACTOR_BIT{1'b0}};
        else if(freq_register[0] == 1'b1 && clk_cnt == freq_register[FACTOR_BIT - 1:1])clk_cnt <= clk_cnt + 1;
        else if(freq_register[0] == 1'b0 && clk_cnt == freq_register[FACTOR_BIT - 1:1] - 1)clk_cnt <= {FACTOR_BIT{1'b0}};
		else if(clk_cnt >= freq_register)clk_cnt <= {FACTOR_BIT{1'b0}};
		else clk_cnt <= clk_cnt + 1;
    end
	
    always @(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)clk_square <= 1'b0;
        else if(freq_register[0] == 1'b1 && clk_cnt == freq_register - 1)clk_square <= ~clk_square;
        else if(freq_register[0] == 1'b1 && clk_cnt == freq_register[FACTOR_BIT - 1:1])clk_square <= ~clk_square;
        else if(freq_register[0] == 1'b0 && clk_cnt == freq_register[FACTOR_BIT - 1:1] - 1)clk_square <= ~clk_square;
        else clk_square <= clk_square;
    end
    
	always @(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_pulse <= 1'b0;
		else if(clk_cnt == 0)clk_pulse <= 1'b0;
		else if(clk_cnt == freq_register[FACTOR_BIT - 1:1])clk_pulse <= 1'b1;
		else clk_pulse <= 1'b0;
	end
	
endmodule

module Clock_Divider_Even
#(
	parameter FACTOR_BIT = 5'd31
)
(					
	input i_clk,
	input i_rstn,
	input [FACTOR_BIT - 1:0]i_clk_mode,			
	
	output o_clk_out,							
	output o_clk_ls,							
	output o_clk_lc,							
	output o_clk_hs,							
	output o_clk_hc								
);
	
	reg [FACTOR_BIT - 1:0]clk_cnt = 0;
	
	reg clk_out_o = 0;
	reg clk_ls_o = 0;
	reg clk_lc_o = 0;
	reg clk_hs_o = 0;
	reg clk_hc_o = 0;
	
	assign o_clk_out = clk_out_o;
	assign o_clk_ls = clk_ls_o;
	assign o_clk_lc = clk_lc_o;
	assign o_clk_hs = clk_hs_o;
	assign o_clk_hc = clk_hc_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_ls_o <= 1'b0;
		else if(clk_cnt == 1)clk_ls_o <= 1'b1;
		else clk_ls_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_lc_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:2] + 1)clk_lc_o <= 1'b1;
		else clk_lc_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hs_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1] + 1)clk_hs_o <= 1'b1;
		else clk_hs_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hc_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1] + i_clk_mode[FACTOR_BIT - 1:2] + 1)clk_hc_o <= 1'b1;
		else clk_hc_o <= 1'b0;
	end
	
	always@(posedge i_clk or negedge i_rstn) begin
		if(i_rstn == 1'b0)clk_out_o <= 1'b0;
		else if(clk_cnt == 0)clk_out_o <= ~clk_out_o;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1])clk_out_o <= ~clk_out_o;
		else clk_out_o <= clk_out_o;
	end
	
	always@(posedge i_clk or negedge i_rstn) begin
		if(i_rstn == 1'b0)clk_cnt <= {FACTOR_BIT{1'b0}};
		else if(clk_cnt == i_clk_mode - 1)clk_cnt <= {FACTOR_BIT{1'b0}};
		else clk_cnt <= clk_cnt + 1;
	end
	
endmodule


module Clock_Divider_Odd
#(
	parameter FACTOR_BIT = 5'd31
)
(					
	input i_clk,
	input i_rstn,
	input [FACTOR_BIT - 1:0]i_clk_mode,			
	
	output o_clk_out,							
	output o_clk_ls,							
	output o_clk_lc,							
	output o_clk_hs,							
	output o_clk_hc								
);
	
	reg [FACTOR_BIT - 1:0]clk_cnt = 0;

	reg flg_half = 0;				
	
	reg clk_out_o = 0;
	reg clk_ls_o = 0;
	reg clk_lc_o = 0;
	reg clk_hs_o = 0;
	reg clk_hc_o = 0;
	
	assign o_clk_out = clk_out_o | flg_half;
	assign o_clk_ls = clk_ls_o;
	assign o_clk_lc = clk_lc_o;
	assign o_clk_hs = clk_hs_o;
	assign o_clk_hc = clk_hc_o;
	
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_ls_o <= 1'b0;
		else if(clk_cnt == 1)clk_ls_o <= 1'b1;
		else clk_ls_o <= 1'b0;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_lc_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:2] + 1)clk_lc_o <= 1'b1;
		else clk_lc_o <= 1'b0;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hs_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1] + 1)clk_hs_o <= 1'b1;
		else clk_hs_o <= 1'b0;
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)clk_hc_o <= 1'b0;
		else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1] + i_clk_mode[FACTOR_BIT - 1:2] + 1)clk_hc_o <= 1'b1;
		else clk_hc_o <= 1'b0;
	end

    always @(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)clk_out_o <= 1'b0;
        else if(clk_cnt == i_clk_mode - 1)clk_out_o <= ~clk_out_o;
        else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1])clk_out_o <= ~clk_out_o;
        else clk_out_o <= clk_out_o;
    end

	always@(negedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)flg_half <= 1'b0;
        else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1])flg_half <= 1'b1;
        else flg_half <= 1'b0;
    end

	always @(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)clk_cnt <= {FACTOR_BIT{1'b0}};
        else if(clk_cnt == i_clk_mode - 1)clk_cnt <= {FACTOR_BIT{1'b0}};
        else if(clk_cnt == i_clk_mode[FACTOR_BIT - 1:1])clk_cnt <= clk_cnt + 1;
		else clk_cnt <= clk_cnt + 1;
    end
	
endmodule
