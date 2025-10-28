`timescale 1ns / 1ps

//LT8618接口
module LT8618_Interface
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
	
	//LT8618配置模块实例化
	LT8618_Config #(
		.CLOCK_FREQ_MHZ(CLOCK_FREQ_MHZ),
		.WAIT_TIME_MS(1000),				//上电后等待时间
		.DEVICE_ADDRESS(8'h72),				//LT8618设备地址
		.CONFIG_DATA_NUM(16'd80)			//配置参数数量
	)LT8618_Config_Inst(
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

//LT8618配置模块
module LT8618_Config
#(
	parameter CLOCK_FREQ_MHZ 	= 13'd100,
	parameter WAIT_TIME_MS 		= 500,				//上电后等待时间
	parameter DEVICE_ADDRESS 	= 8'h72,			//LT8618设备地址
	parameter CONFIG_DATA_NUM	= 16'd80			//配置参数数量
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
	localparam CONFIG_CALIBRATE_NUM = 16'd51;
	localparam CONFIG_RESET_NUM = 16'd56;
	localparam CONFIG_DELAY_NUM = 16'd44;
	
	//IDCK配置寄存器参数
	localparam CONFIG_IDCK_REG = 24'haa9988;
	
	//------------------状态参数----------------//
	localparam ST_WR_IDLE = 3'd0;
	localparam ST_WR_WAIT = 3'd1;
    localparam ST_WR_START = 3'd2;
	localparam ST_WR_PROC = 3'd3;
	localparam ST_WR_CALIBRATION = 3'd4;
	localparam ST_WR_STOP = 3'd5;
    localparam ST_WR_END = 3'd6;
	
	//------------------计数信号----------------//
	reg [31:0]wait_cnt = 0;		//初始化等待计数
	reg [15:0]send_cnt = 0;		//发送计数
	
	//------------------数据信号----------------//
	//LUT数据
	reg [16:0]LUT_Data = 0;
	
	//校准数据
	reg [23:0]calibrate_data = 0;
	
	//IDCK寄存器
	reg [23:0]idck_register = 0;
	
	//------------------标志信号----------------//
	wire flag_calibrate_success;				//PLL校准成功
	wire flag_dck_error;						//校准时钟出错
	
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
	//配置数据信号
	reg [7:0]mbus_rwaddr_l_o = 0;
	
	//写通道
	reg mbus_wrq_o = 0;
	reg [7:0]mbus_wdata_o = 0;
	
	//读通道
	reg mbus_rrq_o = 0;
	
	//----------------其他信号连线-------------//
	//标志信号
	assign flag_calibrate_success = calibrate_data[23] & calibrate_data[7] & (calibrate_data[15:8] < 8'hff);
	assign flag_dck_error = (calibrate_data[23:16] == 8'h00) & (calibrate_data[15:8] == 8'h80);
	
	//----------------输出信号连线-------------//
	//配置模式信号
	assign o_mbus_rwslave_addr_mode = 1'b1;			//移位之后地址,不需要再移位
	assign o_mbus_rwaddr_mode = 1'b0;				//单地址位
	assign o_mbus_rack = 1'b0;			    		//0为应答ACK
	assign o_mbus_wack_enable = 1'b0;				//写应答检测校验使能关闭
	assign o_mbus_wack = 1'b0;			    		//0为应答ACK
	assign o_mbus_rwmode = 1'b1;					//单字节读写
	
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
				else if(send_cnt == CONFIG_CALIBRATE_NUM && flag_calibrate_success == 1'b1)state_next <= ST_WR_CALIBRATION;
				else if(send_cnt == CONFIG_RESET_NUM)state_next <= ST_WR_CALIBRATION;
				else state_next <= ST_WR_WAIT;
			end

			//PLL校准
			ST_WR_CALIBRATION:begin
				if(flag_calibrate_success == 1'b1)state_next <= ST_WR_WAIT;
				else if(flag_dck_error == 1'b1)state_next <= ST_WR_IDLE;
				else state_next <= ST_WR_STOP;
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
	//校准数据
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)calibrate_data <= 24'd0;
		else if(state_current == ST_WR_CALIBRATION)calibrate_data <= 24'd0;
		else if(mbus_rvalid_i == 1'b1)calibrate_data <= {calibrate_data[15:0],mbus_rdata_i};
		else calibrate_data <= calibrate_data;
	end
	
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
		else if(state_current == ST_WR_CALIBRATION && flag_calibrate_success == 1'b1)send_cnt <= CONFIG_RESET_NUM;
		else if(state_current == ST_WR_CALIBRATION)send_cnt <= CONFIG_DELAY_NUM;
        else send_cnt <= send_cnt;
    end
	
	//IDCK寄存器
	always@(posedge i_clk or negedge i_rstn)begin
        if(i_rstn == 1'b0)idck_register <= CONFIG_IDCK_REG;
		else if(state_current == ST_WR_CALIBRATION && flag_dck_error == 1'b1)idck_register <= {idck_register[7:0],idck_register[23:8]};
        else idck_register <= idck_register;
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
			//Reset PD
			16'd0:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd1:LUT_Data <= {1'b0,8'hee,8'h01};
			16'd2:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd3:LUT_Data <= {1'b0,8'h11,8'h00};	//reset MIPI Rx Logic
			
			// TTL mode
			16'd4:LUT_Data <= {1'b0,8'hff,8'h81};	//register bank
			16'd5:LUT_Data <= {1'b0,8'h02,8'h66};
			16'd6:LUT_Data <= {1'b0,8'h0a,8'h06};
			16'd7:LUT_Data <= {1'b0,8'h15,8'h06};
			16'd8:LUT_Data <= {1'b0,8'h4e,8'ha8};
			
			16'd9:LUT_Data <= {1'b0,8'hff,8'h82};	//register bank
			16'd10:LUT_Data <= {1'b0,8'h1b,8'h77};
			16'd11:LUT_Data <= {1'b0,8'h1c,8'hec};	//25000
			
			// TTL input digital:RGB888
			16'd12:LUT_Data <= {1'b0,8'hff,8'h82};	//register bank
			16'd13:LUT_Data <= {1'b0,8'h45,8'h00};	//RGB channel swap;BGR->0x00;RGB->0x70
			16'd14:LUT_Data <= {1'b0,8'h4f,8'h40};	//0x40->SDR;0x80->DDR
			16'd15:LUT_Data <= {1'b0,8'h50,8'h00};
			16'd16:LUT_Data <= {1'b0,8'h51,8'h00};
			
			//PLL
			16'd17:LUT_Data <= {1'b0,8'hff,8'h81};	//register bank
			16'd18:LUT_Data <= {1'b0,8'h23,8'h40};
			16'd19:LUT_Data <= {1'b0,8'h24,8'h62};	//icp set
			16'd20:LUT_Data <= {1'b0,8'h25,8'h00};
			16'd21:LUT_Data <= {1'b0,8'h2c,8'h9e};
			16'd22:LUT_Data <= {1'b0,8'h2d,idck_register[7:0]};	//0~50MHz:0xaa;50~100MHz:0x99;100MHz~:0x88
			
			16'd23:LUT_Data <= {1'b0,8'h26,8'h55};
			16'd24:LUT_Data <= {1'b0,8'h27,8'h66};	//phase selection for d_clk
			16'd25:LUT_Data <= {1'b0,8'h28,8'h88};	//0x88
			
			16'd26:LUT_Data <= {1'b0,8'h29,8'h04};	//for U3 for U3 SDR/DDR fixed phase
			
			16'd27:LUT_Data <= {1'b0,8'hff,8'h81};
			16'd28:LUT_Data <= {1'b1,8'h2b,8'h00};
			16'd29:LUT_Data <= {1'b0,8'h2b,mbus_rdata_i & 8'hfd};	//sw_en_txpll_cal_en
			16'd30:LUT_Data <= {1'b1,8'h2e,8'h00};
			16'd31:LUT_Data <= {1'b0,8'h2e,mbus_rdata_i & 8'hfe};	//sw_en_txpll_iband_set
			
			//如果分辨率改变或者输入时钟改变,就必须重新配置这个
			16'd32:LUT_Data <= {1'b0,8'hff,8'h82};	//register bank
			16'd33:LUT_Data <= {1'b0,8'hde,8'h00};
			16'd34:LUT_Data <= {1'b0,8'hde,8'hc0};
			
			16'd35:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd36:LUT_Data <= {1'b0,8'h16,8'hf1};
			16'd37:LUT_Data <= {1'b0,8'h18,8'hdc};
			16'd38:LUT_Data <= {1'b0,8'h18,8'hfc};
			16'd39:LUT_Data <= {1'b0,8'h16,8'hf3};
			
			16'd40:LUT_Data <= {1'b0,8'hff,8'h81};	//register bank
			16'd41:LUT_Data <= {1'b0,8'h27,8'h66};	//phase selection for d_clk
			16'd42:LUT_Data <= {1'b0,8'h2a,8'h00};
			16'd43:LUT_Data <= {1'b0,8'h2a,8'h20};	//sync rest
			
			//延时
			16'd44:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd45:LUT_Data <= {1'b0,8'h16,8'he3};	//pll lock logic reset
			16'd46:LUT_Data <= {1'b0,8'h16,8'hf3};
			
			16'd47:LUT_Data <= {1'b0,8'hff,8'h82};
			16'd48:LUT_Data <= {1'b1,8'h15,8'h00};
			16'd49:LUT_Data <= {1'b1,8'hea,8'h00};
			16'd50:LUT_Data <= {1'b1,8'heb,8'h00};
			
			16'd51:LUT_Data <= {1'b0,8'hff,8'h80};	//register bank
			16'd52:LUT_Data <= {1'b0,8'h16,8'hf1};	//pll lock logic reset
			16'd53:LUT_Data <= {1'b0,8'h18,8'hdc};	//txpll_s_rst_n
			16'd54:LUT_Data <= {1'b0,8'h18,8'hfc};
			16'd55:LUT_Data <= {1'b0,8'h16,8'hf3};
			
			16'd56:LUT_Data <= {1'b0,8'hff,8'h81};	//register bank
			16'd57:LUT_Data <= {1'b0,8'h2a,8'h00};
			16'd58:LUT_Data <= {1'b0,8'h2a,8'h20};	//sync rest
			
			//颜色配置
			16'd59:LUT_Data <= {1'b0,8'hff,8'h82};	//register bank
			16'd60:LUT_Data <= {1'b0,8'hb9,8'h00};	//No csc
		
			//0x43寄存器是校验和,0x45或0x47寄存器的值发生改变,相应的0x43也需要改变
			//0x43,0x44,0x45,0x47四个寄存器的合值是0x6F.
			16'd61:LUT_Data <= {1'b0,8'hff,8'h84};	//register bank
			16'd62:LUT_Data <= {1'b0,8'h43,8'h56 - 8'h00 + 8'h10};//0x46-VIC_NUM;VIC_NUM->0x00,代表自动;avi packet checksum ,avi_pb0
			16'd63:LUT_Data <= {1'b0,8'h44,8'h10};	//color space: YUV422 0x30; RGB 0x10
			16'd64:LUT_Data <= {1'b0,8'h45,8'h2a};	//0x19:4:3 ; 0x2A : 16:9
			16'd65:LUT_Data <= {1'b0,8'h47,8'h00 + 8'h00};//VIC_NUM,0x10:1080P;0x04:720P
			
			//HDMI_TX_Phy
			16'd66:LUT_Data <= {1'b0,8'hff,8'h81};	//register bank
			16'd67:LUT_Data <= {1'b0,8'h30,8'hea};
			16'd68:LUT_Data <= {1'b0,8'h31,8'h44};
			16'd69:LUT_Data <= {1'b0,8'h32,8'h4a};
			16'd70:LUT_Data <= {1'b0,8'h33,8'h0b};
			16'd71:LUT_Data <= {1'b0,8'h34,8'h00};
			16'd72:LUT_Data <= {1'b0,8'h35,8'h00};
			16'd73:LUT_Data <= {1'b0,8'h36,8'h00};
			16'd74:LUT_Data <= {1'b0,8'h37,8'h44};
			16'd75:LUT_Data <= {1'b0,8'h3f,8'h0f};
			
			16'd76:LUT_Data <= {1'b0,8'h40,8'ha0};	//0xa0 -- CLK tap0 swing
			16'd77:LUT_Data <= {1'b0,8'h41,8'ha0};	//0xa0 -- D0 tap0 swing
			16'd78:LUT_Data <= {1'b0,8'h42,8'ha0};	//0xa0 -- D1 tap0 swing
			16'd79:LUT_Data <= {1'b0,8'h43,8'ha0};	//0xa0 -- D2 tap0 swing
			
			16'd80:LUT_Data <= {1'b0,8'h44,8'h0a};
			default:LUT_Data <= {1'b0,8'hff,8'hff};
		endcase
	end
endmodule