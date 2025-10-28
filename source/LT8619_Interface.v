`timescale 1ns / 1ps

module LT8619_Interface
#(
	parameter CLOCK_FREQ_MHZ 	= 13'd100,                                                                                                                       
	parameter IIC_Clock_KHz 	= 13'd100
)
(
	input i_clk,
	input i_rstn,
	
	//--------------IIC管脚信号-------------//
	input i_iic_sda,						//IIC输入SDA数据信号
	output o_iic_scl,						//IIC输出SCL时钟信号
	output o_iic_sda,						//IIC输出SDA数据信号
	output o_iic_sda_dir					//IIC输出SDA信号方向
);

	//------------模块实例化信号------------//
	//配置模式信号
	wire iic_mbus_rwslave_addr_mode;
	wire iic_mbus_rwaddr_mode;
	wire iic_mbus_rack;
	wire iic_mbus_wack_enable;
	wire iic_mbus_wack;
	wire iic_mbus_rwmode;
	
	//配置数据信号
	wire [7:0]iic_mbus_rwslave_addr;
	wire [7:0]iic_mbus_rwaddr_h;
	wire [7:0]iic_mbus_rwaddr_l;
	
	//写通道
	wire iic_mbus_wrq;
	wire [7:0]iic_mbus_wdata;
	wire iic_mbus_wvalid;
	wire iic_mbus_wlast;
	wire iic_mbus_wready;
	
	//读通道
	wire iic_mbus_rrq;
	wire iic_mbus_rready;
	wire iic_mbus_rlast;
	wire [7:0]iic_mbus_rdata;
	wire iic_mbus_rvalid;
	
	//忙通道
	wire iic_mbus_rwbusy;
	wire iic_mbus_rwack_err;
	
	//LT8619配置模块实例化
	LT8619_Config #(
		.CLOCK_FREQ_MHZ(CLOCK_FREQ_MHZ),
		.WAIT_TIME_MS(1000),				//上电后等待时间
		.DEVICE_ADDRESS(8'h64),				//LT8619设备地址
		.CONFIG_DATA_NUM(16'd288)			//配置参数数量
	)LT8619_Config_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		
		//-------------外部控制信号-------------//
		//配置模式信号
		.o_mbus_rwslave_addr_mode(iic_mbus_rwslave_addr_mode),	//配置IIC从机地址模式,1'b0代表原始地址,需要左移7位,低位补零;1'b1代表移位之后地址,不需要再移位
		.o_mbus_rwaddr_mode(iic_mbus_rwaddr_mode),				//配置IIC读写地址模式,1'b1代表双地址位;1'b0代表单地址位,此时低位地址有效
		.o_mbus_rack(iic_mbus_rack),			            	//配置IIC读应答信号,1为非应答NACK;0为应答ACK
		.o_mbus_wack_enable(iic_mbus_wack_enable),				//配置IIC写应答检测校验使能
		.o_mbus_wack(iic_mbus_wack),			        		//配置IIC写应答信号校验值,1为非应答NACK;0为应答ACK
		.o_mbus_rwmode(iic_mbus_rwmode),						//配置IIC读写数据模式,1'b1代表单字节读写;1'b0代表连续读写
		
		//配置数据信号
		.o_mbus_rwslave_addr(iic_mbus_rwslave_addr),			//配置IIC读写从机地址
		.o_mbus_rwaddr_h(iic_mbus_rwaddr_h),					//配置IIC读写寄存器地址,高8位
		.o_mbus_rwaddr_l(iic_mbus_rwaddr_l),					//配置IIC读写寄存器地址,低8位
		
		//写通道
		.o_mbus_wrq(iic_mbus_wrq),								//写请求,高电平有效
		.o_mbus_wdata(iic_mbus_wdata),							//写数据
		.o_mbus_wvalid(iic_mbus_wvalid),						//写数据有效信号
		.o_mbus_wlast(iic_mbus_wlast),							//写最后一个
		.i_mbus_wready(iic_mbus_wready),						//写准备好信号*
		
		//读通道
		.o_mbus_rrq(iic_mbus_rrq),								//读请求,高电平有效
		.o_mbus_rready(iic_mbus_rready),						//读准备好
		.o_mbus_rlast(iic_mbus_rlast),							//读最后一个
		.i_mbus_rdata(iic_mbus_rdata),							//读数据
		.i_mbus_rvalid(iic_mbus_rvalid),						//读数据有效信号
		
		//忙通道
		.i_mbus_rwbusy(iic_mbus_rwbusy),						//读写忙信号,高电平代表忙碌,低电平代表空闲
		.i_mbus_rwack_err(iic_mbus_rwack_err)					//应答错误*
	);

	//IIC接口实例化
	IIC_Interface #(.CLOCK_FREQ_MHZ(CLOCK_FREQ_MHZ),.IIC_Clock_KHz(IIC_Clock_KHz))IIC_Interface_Inst(
        .i_clk(i_clk),
        .i_rstn(i_rstn),
        
        //-------------外部控制信号-------------//
        //配置模式信号
        .i_mbus_rwslave_addr_mode(iic_mbus_rwslave_addr_mode),	//配置IIC从机地址模式,1'b0代表原始地址,需要左移7位,低位补零;1'b1代表移位之后地址,不需要再移位
        .i_mbus_rwaddr_mode(iic_mbus_rwaddr_mode),				//配置IIC读写地址模式,1'b1代表双地址位;1'b0代表单地址位,此时低位地址有效
        .i_mbus_rack(iic_mbus_rack),							//配置IIC读应答信号,1为非应答NACK;0为应答ACK
        .i_mbus_wack_enable(iic_mbus_wack_enable),				//配置IIC写应答检测校验使能
        .i_mbus_wack(iic_mbus_wack),							//配置IIC写应答信号校验值,1为非应答NACK;0为应答ACK
        .i_mbus_rwmode(iic_mbus_rwmode),						//配置IIC读写数据模式,1'b1代表单字节读写;1'b0代表连续读写
        
        //配置数据信号
        .i_mbus_rwslave_addr(iic_mbus_rwslave_addr),			//配置IIC读写从机地址
        .i_mbus_rwaddr_h(iic_mbus_rwaddr_h),					//配置IIC读写寄存器地址,高8位
        .i_mbus_rwaddr_l(iic_mbus_rwaddr_l),					//配置IIC读写寄存器地址,低8位
        
        //写通道
        .i_mbus_wrq(iic_mbus_wrq),								//写请求,高电平有效
        .i_mbus_wdata(iic_mbus_wdata),							//写数据
        .i_mbus_wvalid(iic_mbus_wvalid),						//写数据有效信号
        .i_mbus_wlast(iic_mbus_wlast),							//写最后一个
        .o_mbus_wready(iic_mbus_wready),						//写准备好信号
        
        //读通道
        .i_mbus_rrq(iic_mbus_rrq),								//读请求,高电平有效
        .i_mbus_rready(iic_mbus_rready),						//读准备好
        .i_mbus_rlast(iic_mbus_rlast),							//读最后一个
        .o_mbus_rdata(iic_mbus_rdata),							//读数据
        .o_mbus_rvalid(iic_mbus_rvalid),						//读数据有效信号
        
        //忙通道
        .o_mbus_rwbusy(iic_mbus_rwbusy),						//读写忙信号,高电平代表忙碌,低电平代表空闲
        .o_mbus_rwack_err(iic_mbus_rwack_err),					//应答错误
		
        //--------------IIC管脚信号-------------//
        .i_iic_sda(i_iic_sda),                        			//IIC输入SDA数据信号
        .o_iic_scl(o_iic_scl),                        			//IIC输出SCL时钟信号
        .o_iic_sda(o_iic_sda),                        			//IIC输出SDA数据信号
        .o_iic_sda_dir(o_iic_sda_dir)                 			//IIC输出SDA信号方向
    );
	
endmodule

//LT8619配置模块
module LT8619_Config
#(
	parameter CLOCK_FREQ_MHZ 	= 13'd100,
	parameter WAIT_TIME_MS 		= 500,				//上电后等待时间
	parameter DEVICE_ADDRESS 	= 8'h64,			//LT8619设备地址
	parameter CONFIG_DATA_NUM	= 16'd288			//配置参数数量
)
(
	input i_clk,
    input i_rstn,
	
	//-------------外部控制信号-------------//
	//配置模式信号
	output o_mbus_rwslave_addr_mode,		//配置IIC从机地址模式,1'b0代表原始地址,需要左移7位,低位补零;1'b1代表移位之后地址,不需要再移位
	output o_mbus_rwaddr_mode,				//配置IIC读写地址模式,1'b1代表双地址位;1'b0代表单地址位,此时低位地址有效
	output o_mbus_rack,			            //配置IIC读应答信号,1为非应答NACK;0为应答ACK
	output o_mbus_wack_enable,				//配置IIC写应答检测校验使能
	output o_mbus_wack,			        	//配置IIC写应答信号校验值,1为非应答NACK;0为应答ACK
	output o_mbus_rwmode,					//配置IIC读写数据模式,1'b1代表单字节读写;1'b0代表连续读写
	
	//配置数据信号
	output [7:0]o_mbus_rwslave_addr,		//配置IIC读写从机地址
	output [7:0]o_mbus_rwaddr_h,			//配置IIC读写寄存器地址,高8位
	output [7:0]o_mbus_rwaddr_l,			//配置IIC读写寄存器地址,低8位
	
	//写通道
	output o_mbus_wrq,						//写请求,高电平有效
	output [7:0]o_mbus_wdata,				//写数据
	output o_mbus_wvalid,					//写数据有效信号
	output o_mbus_wlast,					//写最后一个
	input i_mbus_wready,					//写准备好信号*
	
	//读通道
	output o_mbus_rrq,						//读请求,高电平有效
	output o_mbus_rready,					//读准备好
	output o_mbus_rlast,					//读最后一个
	input [7:0]i_mbus_rdata,				//读数据
	input i_mbus_rvalid,					//读数据有效信号
	
	//忙通道
	input i_mbus_rwbusy,					//读写忙信号,高电平代表忙碌,低电平代表空闲
	input i_mbus_rwack_err					//应答错误*
);
	//------------------其他参数----------------//
	//等待参数
	localparam WAIT_NUM  = CLOCK_FREQ_MHZ * WAIT_TIME_MS * 1000;
	
	//特殊节点
	localparam CONFIG_DELAY_NUM = 16'd263;
	localparam CONFIG_EDID_NUM = 16'd6;
	
	//------------------状态参数----------------//
	localparam ST_WR_IDLE = 3'd0;
	localparam ST_WR_WAIT = 3'd1;
    localparam ST_WR_START = 3'd2;
	localparam ST_WR_PROC = 3'd3;
	localparam ST_WR_STOP = 3'd4;
    localparam ST_WR_END = 3'd5;
	
	//------------------计数信号----------------//
	reg [31:0]wait_cnt = 0;		//初始化等待计数
	reg [15:0]send_cnt = 0;		//发送计数
	
	//------------------数据信号----------------//
	//LUT数据
	reg [16:0]LUT_Data = 0;

	//-------------------状态机-----------------//
	reg [2:0]state_current = 0;
    reg [2:0]state_next = 0;
	
	//----------------输入缓存信号--------------//
	//写通道
	reg [1:0]mbus_wready_i = 0;
	
	//读通道
	reg [7:0]mbus_rdata_i = 0;
	reg mbus_rvalid_i = 0;
	
	//忙通道
	reg [1:0]mbus_rwbusy_i = 0;
	reg mbus_rwack_err_i = 0;
	
	//------------------输出信号---------------//
	//配置模式信号
	reg mbus_rwmode_o = 1'b0;
	
	//配置数据信号
	reg [7:0]mbus_rwaddr_l_o = 0;
	
	//写通道
	reg mbus_wrq_o = 0;
	reg [7:0]mbus_wdata_o = 0;
	
	//读通道
	reg mbus_rrq_o = 0;

	//----------------输出信号连线-------------//
	//配置模式信号
	assign o_mbus_rwslave_addr_mode = 1'b1;			//移位之后地址,不需要再移位
	assign o_mbus_rwaddr_mode = 1'b0;				//单地址位
	assign o_mbus_rack = 1'b0;			    		//0为应答ACK
	assign o_mbus_wack_enable = 1'b0;				//写应答检测校验使能关闭
	assign o_mbus_wack = 1'b0;			    		//0为应答ACK
	assign o_mbus_rwmode = mbus_rwmode_o;			//单字节读写
	
	//数据信号
	assign o_mbus_rwslave_addr = DEVICE_ADDRESS;	//IIC读写从机地址为默认器件地址
	assign o_mbus_rwaddr_h = 8'h00;					//寄存器地址,高8位
	assign o_mbus_rwaddr_l = mbus_rwaddr_l_o;		//寄存器地址,低8位
	
	//写通道
	assign o_mbus_wrq = mbus_wrq_o;					//写请求,高电平有效
	assign o_mbus_wdata = mbus_wdata_o;				//写数据
	assign o_mbus_wvalid = 1'b1;					//写数据有效信号
	assign o_mbus_wlast = 1'b1;						//写最后一个,每次只写1个
	
	//读通道
	assign o_mbus_rrq = mbus_rrq_o;					//读请求,高电平有效
	assign o_mbus_rready = 1'b1;					//读准备好
	assign o_mbus_rlast = 1'b1;						//每次只读1个
	
	//------------------信号输出---------------//
	//配置模式信号
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)mbus_rwmode_o <= 1'd0;
		else if(send_cnt < CONFIG_EDID_NUM)mbus_rwmode_o <= 1'd1;
		else if(send_cnt < CONFIG_DELAY_NUM)mbus_rwmode_o <= 1'd0;
		else mbus_rwmode_o <= 1'd1;
	end
	
	//数据信号--寄存器地址
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)mbus_rwaddr_l_o <= 8'd0;
        else if(state_current == ST_WR_WAIT)mbus_rwaddr_l_o <= LUT_Data[15:8];
		else mbus_rwaddr_l_o <= mbus_rwaddr_l_o;
    end
	
	//写通道--写请求信号
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)mbus_wrq_o <= 1'd0;
        else if(state_current == ST_WR_WAIT)mbus_wrq_o <= ~LUT_Data[16];
		else mbus_wrq_o <= 1'd0;
    end
	
	//写通道--写数据信号
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)mbus_wdata_o <= 8'd0;
        else if(state_current == ST_WR_WAIT)mbus_wdata_o <= LUT_Data[7:0];
		else mbus_wdata_o <= mbus_wdata_o;
    end
	
	//读通道--读请求信号
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)mbus_rrq_o <= 1'd0;
		else if(state_current == ST_WR_WAIT)mbus_rrq_o <= LUT_Data[16];
		else mbus_rrq_o <= 1'd0;
    end
	
	//-------------------状态机----------------//
	//主状态机
	always@(*)begin
		case(state_current)
			ST_WR_IDLE:begin
                if(wait_cnt >= WAIT_NUM)state_next <= ST_WR_WAIT;
                else state_next <= ST_WR_IDLE;
            end
            ST_WR_WAIT:state_next <= ST_WR_START;
			ST_WR_START:begin
				if(mbus_rwbusy_i == 2'b10)state_next <= ST_WR_PROC;
				else state_next <= ST_WR_START;
            end
			//处理判断
			ST_WR_PROC:begin
				if(send_cnt > CONFIG_DATA_NUM)state_next <= ST_WR_END;
				else if(send_cnt == CONFIG_DELAY_NUM)state_next <= ST_WR_STOP;
				else state_next <= ST_WR_WAIT;
			end
			
			//停止等待
			ST_WR_STOP:begin
				 if(wait_cnt >= WAIT_NUM)state_next <= ST_WR_WAIT;
                else state_next <= ST_WR_STOP;
			end
            ST_WR_END:state_next <= ST_WR_END;
            default:state_next <= ST_WR_IDLE;
		endcase
	end
	
	//状态转换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_WR_IDLE;
		end else begin
			state_current <= state_next;
		end
	end
	
	//----------------状态任务处理-------------//
	//等待计数
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)wait_cnt <= 32'd0;
		else if(state_current == ST_WR_IDLE)wait_cnt <= wait_cnt + 32'd1;
		else if(state_current == ST_WR_STOP)wait_cnt <= wait_cnt + 32'd1;
        else wait_cnt <= 32'd0;
    end
	
	//发送计数
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)send_cnt <= 16'd0;
		else if(state_current == ST_WR_IDLE)send_cnt <= 16'd0;
        else if(state_current == ST_WR_START && mbus_rwbusy_i == 2'b10)send_cnt <= send_cnt + 16'd1;
        else send_cnt <= send_cnt;
    end
	
	//----------------输入信号缓存-------------//
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mbus_wready_i <= 2'd0;
			mbus_rdata_i <= 8'd0;
			mbus_rvalid_i <= 1'd0;
			mbus_rwbusy_i <= 2'd0;
			mbus_rwack_err_i <= 1'd0;
		end else begin
			mbus_wready_i <= {mbus_wready_i[0],i_mbus_wready};
			mbus_rdata_i <= i_mbus_rdata;
			mbus_rvalid_i <= i_mbus_rvalid;
			mbus_rwbusy_i <= {mbus_rwbusy_i[0],i_mbus_rwbusy};
			mbus_rwack_err_i <= i_mbus_rwack_err;
		end
	end
	
	//------------------LUT查找表--------------//
	always@(*)begin
		case(send_cnt)
			//Set HPD 0
			16'd0:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd1:LUT_Data <= {1'b1,8'h06,8'h00};
			16'd2:LUT_Data <= {1'b0,8'h06,mbus_rdata_i & 8'hf7};
			
			//EDID
			16'd3:LUT_Data <= {1'b0,8'hfe,8'h80};	//register bank
			16'd4:LUT_Data <= {1'b0,8'h8e,8'h07};
			16'd5:LUT_Data <= {1'b0,8'h8f,8'h00};
			
			//连续写入EDID
			16'd6:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd7:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd8:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd9:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd10:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd11:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd12:LUT_Data <= {1'b0,8'h90,8'hff};
			16'd13:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd14:LUT_Data <= {1'b0,8'h90,8'h0e};
			16'd15:LUT_Data <= {1'b0,8'h90,8'hd4};
			16'd16:LUT_Data <= {1'b0,8'h90,8'h32};
			16'd17:LUT_Data <= {1'b0,8'h90,8'h31};
			16'd18:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd19:LUT_Data <= {1'b0,8'h90,8'h88};
			16'd20:LUT_Data <= {1'b0,8'h90,8'h88};
			16'd21:LUT_Data <= {1'b0,8'h90,8'h88};
			16'd22:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd23:LUT_Data <= {1'b0,8'h90,8'h1c};
			16'd24:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd25:LUT_Data <= {1'b0,8'h90,8'h03};
			16'd26:LUT_Data <= {1'b0,8'h90,8'h80};
			16'd27:LUT_Data <= {1'b0,8'h90,8'h0c};
			16'd28:LUT_Data <= {1'b0,8'h90,8'h07};
			16'd29:LUT_Data <= {1'b0,8'h90,8'h78};
			16'd30:LUT_Data <= {1'b0,8'h90,8'h0a};
			16'd31:LUT_Data <= {1'b0,8'h90,8'h0d};
			16'd32:LUT_Data <= {1'b0,8'h90,8'hc9};
			16'd33:LUT_Data <= {1'b0,8'h90,8'ha0};
			16'd34:LUT_Data <= {1'b0,8'h90,8'h57};
			16'd35:LUT_Data <= {1'b0,8'h90,8'h47};
			16'd36:LUT_Data <= {1'b0,8'h90,8'h98};
			16'd37:LUT_Data <= {1'b0,8'h90,8'h27};
			16'd38:LUT_Data <= {1'b0,8'h90,8'h12};
			16'd39:LUT_Data <= {1'b0,8'h90,8'h48};
			16'd40:LUT_Data <= {1'b0,8'h90,8'h4c};
			16'd41:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd42:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd43:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd44:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd45:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd46:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd47:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd48:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd49:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd50:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd51:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd52:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd53:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd54:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd55:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd56:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd57:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd58:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd59:LUT_Data <= {1'b0,8'h90,8'h01};
			
			//分辨率相关
			16'd60:LUT_Data <= {1'b0,8'h90,8'h02};	//14850,PIXEL_CLOCK % 256,1080P@60Hz->0x02;74.25M->0x01;
			16'd61:LUT_Data <= {1'b0,8'h90,8'h3a};	//14850,PIXEL_CLOCK / 256,1080P@60Hz->0x3a;74.25M->0x1d;
			16'd62:LUT_Data <= {1'b0,8'h90,8'h80};	//1920,H_SIZE % 256,1080P@60Hz->0x80;1280->0x00;
			16'd63:LUT_Data <= {1'b0,8'h90,8'h18};	//88 + 44 + 148,(HFP + HSYNC + HBP) % 256,1080P@60Hz->0x18;1280*720@60Hz->0x72;
			16'd64:LUT_Data <= {1'b0,8'h90,8'h71};	//((H_SIZE / 256) << 4) + (HFP + HSYNC + HBP)/256,1080P@60Hz->0x71,1280*720@60Hz->0x51;
			16'd65:LUT_Data <= {1'b0,8'h90,8'h38};	//1080,V_SIZE % 256,1080P@60Hz->0x38;720->0xd0;
			16'd66:LUT_Data <= {1'b0,8'h90,8'h2d};	//4 + 5 + 36,(VFP + VSYNC + VBP) % 256,1080P@60Hz->0x2d;1280*720@60Hz->0x1e;
			16'd67:LUT_Data <= {1'b0,8'h90,8'h40};	//((V_SIZE / 256) << 4) + (VFP + VSYNC + VBP)/256,1080P@60Hz->0x40,1280*720@60Hz->0x20;
			16'd68:LUT_Data <= {1'b0,8'h90,8'h58};	//88,HFP % 256,1080P@60Hz->0x58;1280*720@60Hz->0x6e;
			16'd69:LUT_Data <= {1'b0,8'h90,8'h2c};	//44,HSYNC % 256,1080P@60Hz->0x2c;1280*720@60Hz->0x28;
			16'd70:LUT_Data <= {1'b0,8'h90,8'h45};	//((VFP % 256) << 4) + (VSYNC % 256),1080P@60Hz->0x45;1280*720@60Hz->0x55;
			16'd71:LUT_Data <= {1'b0,8'h90,8'h00};	//((HFP / 256) << 6) + ((HSYNC / 256) << 4) + ((VFP / 256) << 2) + (VSYNC / 256),1080P@60Hz->0x00;1280*720@60Hz->0x00;
			16'd72:LUT_Data <= {1'b0,8'h90,8'h80};
			16'd73:LUT_Data <= {1'b0,8'h90,8'h38};
			16'd74:LUT_Data <= {1'b0,8'h90,8'h74};
			16'd75:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd76:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd77:LUT_Data <= {1'b0,8'h90,8'h1e};	//progress V+ H+
			
			16'd78:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd79:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd80:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd81:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd82:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd83:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd84:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd85:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd86:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd87:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd88:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd89:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd90:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd91:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd92:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd93:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd94:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd95:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd96:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd97:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd98:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd99:LUT_Data <= {1'b0,8'h90,8'hfc};
			16'd100:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd101:LUT_Data <= {1'b0,8'h90,8'h0a};
			16'd102:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd103:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd104:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd105:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd106:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd107:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd108:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd109:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd110:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd111:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd112:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd113:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd114:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd115:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd116:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd117:LUT_Data <= {1'b0,8'h90,8'hfc};
			16'd118:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd119:LUT_Data <= {1'b0,8'h90,8'h4c};
			16'd120:LUT_Data <= {1'b0,8'h90,8'h6f};
			16'd121:LUT_Data <= {1'b0,8'h90,8'h6e};
			16'd122:LUT_Data <= {1'b0,8'h90,8'h74};
			16'd123:LUT_Data <= {1'b0,8'h90,8'h69};
			16'd124:LUT_Data <= {1'b0,8'h90,8'h75};
			16'd125:LUT_Data <= {1'b0,8'h90,8'h6d};
			16'd126:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd127:LUT_Data <= {1'b0,8'h90,8'h73};
			16'd128:LUT_Data <= {1'b0,8'h90,8'h65};
			16'd129:LUT_Data <= {1'b0,8'h90,8'h6d};
			16'd130:LUT_Data <= {1'b0,8'h90,8'h69};
			16'd131:LUT_Data <= {1'b0,8'h90,8'h20};
			16'd132:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd133:LUT_Data <= {1'b0,8'h90,8'hf5};
			16'd134:LUT_Data <= {1'b0,8'h90,8'h02};
			16'd135:LUT_Data <= {1'b0,8'h90,8'h03};
			16'd136:LUT_Data <= {1'b0,8'h90,8'h12};
			16'd137:LUT_Data <= {1'b0,8'h90,8'hf1};
			16'd138:LUT_Data <= {1'b0,8'h90,8'h23};
			16'd139:LUT_Data <= {1'b0,8'h90,8'h09};
			16'd140:LUT_Data <= {1'b0,8'h90,8'h04};
			16'd141:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd142:LUT_Data <= {1'b0,8'h90,8'h83};
			16'd143:LUT_Data <= {1'b0,8'h90,8'h01};
			16'd144:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd145:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd146:LUT_Data <= {1'b0,8'h90,8'h65};
			16'd147:LUT_Data <= {1'b0,8'h90,8'h03};
			16'd148:LUT_Data <= {1'b0,8'h90,8'h0c};
			16'd149:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd150:LUT_Data <= {1'b0,8'h90,8'h10};
			16'd151:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd152:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd153:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd154:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd155:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd156:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd157:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd158:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd159:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd160:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd161:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd162:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd163:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd164:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd165:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd166:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd167:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd168:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd169:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd170:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd171:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd172:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd173:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd174:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd175:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd176:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd177:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd178:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd179:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd180:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd181:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd182:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd183:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd184:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd185:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd186:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd187:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd188:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd189:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd190:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd191:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd192:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd193:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd194:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd195:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd196:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd197:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd198:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd199:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd200:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd201:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd202:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd203:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd204:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd205:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd206:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd207:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd208:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd209:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd210:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd211:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd212:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd213:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd214:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd215:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd216:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd217:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd218:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd219:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd220:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd221:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd222:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd223:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd224:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd225:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd226:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd227:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd228:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd229:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd230:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd231:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd232:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd233:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd234:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd235:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd236:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd237:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd238:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd239:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd240:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd241:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd242:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd243:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd244:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd245:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd246:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd247:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd248:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd249:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd250:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd251:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd252:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd253:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd254:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd255:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd256:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd257:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd258:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd259:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd260:LUT_Data <= {1'b0,8'h90,8'h00};
			16'd261:LUT_Data <= {1'b0,8'h90,8'hbf};
			
			//EDID结束
			16'd262:LUT_Data <= {1'b0,8'h8e,8'h02};
			
			//延时
			//Set HPD 1
			16'd263:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd264:LUT_Data <= {1'b1,8'h06,8'h00};
			16'd265:LUT_Data <= {1'b0,8'h06,mbus_rdata_i | 8'h08};
			
			//初始化接收
			16'd266:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd267:LUT_Data <= {1'b1,8'h2c,8'h00};
			16'd268:LUT_Data <= {1'b0,8'h2c,mbus_rdata_i | 8'h30};	//RGD_CLK_STABLE_OPT[1:0]
			
			16'd269:LUT_Data <= {1'b0,8'hff,8'h60};	//register bank
			16'd270:LUT_Data <= {1'b0,8'h04,8'hf2};
			16'd271:LUT_Data <= {1'b0,8'h83,8'h3f};
			16'd272:LUT_Data <= {1'b0,8'h80,8'h08};
			16'd273:LUT_Data <= {1'b0,8'ha4,8'h10};	//SDR->0x10;DDR->0x14
			
			//OUTPUT MODE:RGB888
			16'd274:LUT_Data <= {1'b0,8'hff,8'h60};
			16'd275:LUT_Data <= {1'b0,8'h07,8'hff};
			16'd276:LUT_Data <= {1'b0,8'ha8,8'h0f};
			16'd277:LUT_Data <= {1'b0,8'h60,8'h00};
			16'd278:LUT_Data <= {1'b0,8'h96,8'h71};
			16'd279:LUT_Data <= {1'b0,8'ha0,8'h50};
			16'd280:LUT_Data <= {1'b0,8'ha3,8'h74};	//0x60A3=0x30:PIN68 switch to output PCLK; 0x60A3=0x44:Phase change enable;
			16'd281:LUT_Data <= {1'b0,8'ha2,8'h29};	//Phase code value: 0x20,0x28,0x21,0x29,0x22,0x2a,0x23,0x2b,0x24,0x2c
			
			//RGB mapping control
			16'd282:LUT_Data <= {1'b0,8'h6d,8'h00};
			
			//RGB high/low bit swap control
			16'd283:LUT_Data <= {1'b0,8'h6e,8'h00};
			
			16'd284:LUT_Data <= {1'b0,8'hff,8'h60};
			16'd285:LUT_Data <= {1'b0,8'h0e,8'hfd};
			16'd286:LUT_Data <= {1'b0,8'h0e,8'hff};
			16'd287:LUT_Data <= {1'b0,8'h0d,8'hfc};
			16'd288:LUT_Data <= {1'b0,8'h0d,8'hff};
			
			default:LUT_Data <= {1'b0,8'hff,8'hff};
		endcase
	end
endmodule