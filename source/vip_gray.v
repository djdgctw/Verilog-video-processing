// ============================================================================
// Processing Mode Selection (proc_sel)
// ----------------------------------------------------------------------------
// 该信号用于选择视频处理模式，共4位（4'b0000 ~ 4'b1111），当前映射如下：
//
//   proc_sel = 4'b0000 : 直通模式（Pass-through）原始 RGB 不处理
//   proc_sel = 4'b0001 : 灰度化（Grayscale）RGB 转 Y
//   proc_sel = 4'b0010 : 二值化（Binarization）灰度阈值分割
//   proc_sel = 4'b0011 : 直方图拉伸（Histogram Stretch）线性扩展到满动态范围
//   proc_sel = 4'b0100 : Sobel 边缘检测（Sobel 3×3）|Gx|+|Gy| 饱和
//   proc_sel = 4'b0101 : 半分辨率缩放（Scaling Half）左上区域显示 1/2×1/2 图像
//   proc_sel = 4'b0110 : 高斯滤波（Gaussian Blur 3×3）核 [1 2 1;2 4 2;1 2 1]/16
//   proc_sel = 4'b0111 : 腐蚀（Erosion 3×3）取窗口最小值
//   proc_sel = 4'b1000 : 望远镜功能（Zoom & Pan）
//   proc_sel = 4'b1001 : 灰度反相（Invert）输出 255 - Y （替换原直方图均衡化功能）
//   proc_sel = 4'b1010 : 亮度/对比度调整（Brightness / Contrast）参数可配置
//   proc_sel = 4'b1011 : 裁剪（Crop Quarter）只显示左上四分之一区域
//   proc_sel = 4'b1100 : 伽马校正（Gamma Correction）默认 γ≈2.2
//   proc_sel = 4'b1101 : 灰度伪彩（False Color）蓝→青→绿→黄→红 分段渐变
//
// 其余取值保留，扩展时需同步更新 case 分支与模块映射。
// ============================================================================

// 示例用法（在顶层模块中定义）：
// wire [3:0] proc_sel;  // 4-bit mode selector
`timescale 1ns / 1ps

//视频处理顶层IP
module vip_gray #(
    parameter integer VIDEO_WIDTH  = 1280, // 当前使用 1280x720 分辨率
    parameter integer VIDEO_HEIGHT = 720   // 行高参数，用于后续需要的高度限制
)(
    input        clk,
    input        rst_n,
    input        pre_frame_vsync,
    input        pre_frame_href,
    input        pre_frame_de,
    input  [23:0]pre_rgb,
    input  [3:0] proc_sel,
    input        zoom_in,
    input        zoom_out,
    input        move_up,
    input        move_down,
    input        move_left,
    input        move_right,
    output       post_frame_vsync,
    output       post_frame_href,
    output       post_frame_de,
    output [23:0]post_rgb
);
    wire [7:0] img_y;
    wire post_vsync_int;
    wire post_href_int;
    wire post_de_int;

    reg [23:0] pre_rgb_d;

    localparam [3:0] PROC_BYPASS    = 4'd0;
    localparam [3:0] PROC_GRAY      = 4'd1;
    localparam [3:0] PROC_GRAY_BIN  = 4'd2;
    localparam [3:0] PROC_HIST      = 4'd3; // 直方图拉伸（已有）
    localparam [3:0] PROC_SOBEL     = 4'd4;
    localparam [3:0] PROC_SCALE_HALF= 4'd5; // 缩放为原来一半分辨率（输出区域左上角）
    localparam [3:0] PROC_GAUSS     = 4'd6;
    localparam [3:0] PROC_ERODE     = 4'd7; // 腐蚀
    localparam [3:0] PROC_TELESCOPE = 4'd8; // 望远镜
    // 原 PROC_HIST_EQ(4'd9) 删除，替换为简单灰度反相功能，便于中期演示
    localparam [3:0] PROC_INVERT    = 4'd9; // 灰度反相 255-Y
    localparam [3:0] PROC_BC_ADJ    = 4'd10; // 亮度/对比度调整
    localparam [3:0] PROC_CROP_QTR  = 4'd11; // 裁剪（显示四分之一区域）
    localparam [3:0] PROC_GAMMA     = 4'd12; // 伽马校正 (Gamma ~2.2 默认)
    localparam [3:0] PROC_FALSE     = 4'd13; // 灰度伪彩映射

    wire        bypass_vsync;
    wire        bypass_href;
    wire        bypass_de;
    wire [23:0] bypass_rgb;

    wire        gray_vsync;
    wire        gray_href;
    wire        gray_de;
    wire [23:0] gray_rgb;

    wire        binary_vsync;
    wire        binary_href;
    wire        binary_de;
    wire [23:0] binary_rgb;

    wire        hist_vsync;
    wire        hist_href;
    wire        hist_de;
    wire [23:0] hist_rgb;

    wire        sobel_vsync;
    wire        sobel_href;
    wire        sobel_de;
    wire [23:0] sobel_rgb;

    wire        scale_vsync;
    wire        scale_href;
    wire        scale_de;
    wire [23:0] scale_rgb;

    wire        gauss_vsync;
    wire        gauss_href;
    wire        gauss_de;
    wire [23:0] gauss_rgb;

    wire        erode_vsync;
    wire        erode_href;
    wire        erode_de;
    wire [23:0] erode_rgb;

    wire        telescope_vsync;
    wire        telescope_href;
    wire        telescope_de;
    wire [23:0] telescope_rgb;

    wire        invert_vsync;
    wire        invert_href;
    wire        invert_de;
    wire [23:0] invert_rgb;

    wire        bc_vsync;
    wire        bc_href;
    wire        bc_de;
    wire [23:0] bc_rgb;

    wire        crop_vsync;
    wire        crop_href;
    wire        crop_de;
    wire [23:0] crop_rgb;
    wire        gamma_vsync;
    wire        gamma_href;
    wire        gamma_de;
    wire [23:0] gamma_rgb;
    wire        false_vsync;
    wire        false_href;
    wire        false_de;
    wire [23:0] false_rgb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_rgb_d <= 24'd0;
        end else begin
            pre_rgb_d <= pre_rgb;
        end
    end

    reg        post_vsync_sel;
    reg        post_href_sel;
    reg        post_de_sel;
    reg [23:0] post_rgb_sel;

    //视频RGB888转灰度
    rgb2ycbcr_888 u_rgb2ycbcr(
        .clk             (clk),
        .rst_n           (rst_n),
        .pre_frame_vsync (pre_frame_vsync),
        .pre_frame_href  (pre_frame_href),
        .pre_frame_de    (pre_frame_de),
        .img_red         (pre_rgb[23:16]),
        .img_green       (pre_rgb[15:8]),
        .img_blue        (pre_rgb[7:0]),
        .post_frame_vsync(post_vsync_int),
        .post_frame_href (post_href_int),
        .post_frame_de   (post_de_int),
        .img_y           (img_y),
        .img_cb          (),
        .img_cr          ()
    );

    video_proc_passthrough u_proc_bypass(
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (pre_frame_vsync),
        .in_frame_href    (pre_frame_href),
        .in_frame_de      (pre_frame_de),
        .in_rgb           (pre_rgb),
        .out_frame_vsync  (bypass_vsync),
        .out_frame_href   (bypass_href),
        .out_frame_de     (bypass_de),
        .out_rgb          (bypass_rgb)
    );

    video_proc_gray u_proc_gray(
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (gray_vsync),
        .out_frame_href   (gray_href),
        .out_frame_de     (gray_de),
        .out_rgb          (gray_rgb)
    );

    video_proc_gray_binary #(
        .THRESHOLD        (8'd128)
    ) u_proc_binary (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (binary_vsync),
        .out_frame_href   (binary_href),
        .out_frame_de     (binary_de),
        .out_rgb          (binary_rgb)
    );

    video_proc_histogram u_proc_hist(
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (hist_vsync),
        .out_frame_href   (hist_href),
        .out_frame_de     (hist_de),
        .out_rgb          (hist_rgb)
    );

    video_proc_sobel #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_sobel (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (sobel_vsync),
        .out_frame_href   (sobel_href),
        .out_frame_de     (sobel_de),
        .out_rgb          (sobel_rgb)
    );

    video_proc_scale #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT),
        .USE_HREF         (1'b0)
    ) u_proc_scale (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_rgb           (pre_rgb_d),
        .out_frame_vsync  (scale_vsync),
        .out_frame_href   (scale_href),
        .out_frame_de     (scale_de),
        .out_rgb          (scale_rgb)
    );

    video_proc_gaussian #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_gauss (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (gauss_vsync),
        .out_frame_href   (gauss_href),
        .out_frame_de     (gauss_de),
        .out_rgb          (gauss_rgb)
    );

    video_proc_erosion #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_erode (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (erode_vsync),
        .out_frame_href   (erode_href),
        .out_frame_de     (erode_de),
        .out_rgb          (erode_rgb)
    );

    video_proc_telescope  #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_telescope(
    .clk(clk),
    .rst_n (rst_n)            ,
    .in_frame_vsync (post_vsync_int)   ,
    .in_frame_href (post_href_int)    ,
    .in_frame_de (post_de_int)     ,
    .in_rgb (pre_rgb_d)           ,
    .zoom_in (zoom_in)          ,
    .zoom_out (zoom_out)        ,
    .move_up (move_up  )       ,
    .move_down (!move_down )       ,
    .move_left (!move_left  )     ,
    .move_right (move_right  )    ,
    .out_frame_vsync (telescope_vsync) ,
    .out_frame_href (telescope_href  ) ,
    .out_frame_de (telescope_de)     ,
    .out_rgb (telescope_rgb)          
);
    // 简单灰度反相模块（替换原直方图均衡显示模块）
    video_proc_invert u_proc_invert (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (invert_vsync),
        .out_frame_href   (invert_href),
        .out_frame_de     (invert_de),
        .out_rgb          (invert_rgb)
    );

    video_proc_brightness_contrast #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT),
        .BRIGHTNESS       (9'sd0),    // 默认不加亮度
        .CONTRAST_NUM     (10'd256),  // 对比度系数分子 (1.0)
        .CONTRAST_DEN     (10'd256)   // 分母
    ) u_proc_bc (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (bc_vsync),
        .out_frame_href   (bc_href),
        .out_frame_de     (bc_de),
        .out_rgb          (bc_rgb)
    );

    video_proc_crop_quarter #(
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_crop_qtr (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_rgb           (pre_rgb_d),
        .out_frame_vsync  (crop_vsync),
        .out_frame_href   (crop_href),
        .out_frame_de     (crop_de),
        .out_rgb          (crop_rgb)
    );

    // 伽马校正模块 (Gamma=2.2) 使用 64 点 LUT + 线性插值
    video_proc_gamma #(
        .GAMMA_SCALE      (220),          // 代表 2.20 (缩放 *100)
        .LUT_POINTS       (64),
        .VIDEO_WIDTH      (VIDEO_WIDTH),
        .VIDEO_HEIGHT     (VIDEO_HEIGHT)
    ) u_proc_gamma (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (gamma_vsync),
        .out_frame_href   (gamma_href),
        .out_frame_de     (gamma_de),
        .out_rgb          (gamma_rgb)
    );

    // 灰度伪彩映射模块
    video_proc_false_color u_proc_false (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_frame_vsync   (post_vsync_int),
        .in_frame_href    (post_href_int),
        .in_frame_de      (post_de_int),
        .in_gray          (img_y),
        .out_frame_vsync  (false_vsync),
        .out_frame_href   (false_href),
        .out_frame_de     (false_de),
        .out_rgb          (false_rgb)
    );

    always @(*) begin
        post_vsync_sel = bypass_vsync;
        post_href_sel  = bypass_href;
        post_de_sel    = bypass_de;
        post_rgb_sel   = bypass_rgb;

        case (proc_sel)
            PROC_GRAY: begin
                post_vsync_sel = gray_vsync;
                post_href_sel  = gray_href;
                post_de_sel    = gray_de;
                post_rgb_sel   = gray_rgb;
            end
            PROC_GRAY_BIN: begin
                post_vsync_sel = binary_vsync;
                post_href_sel  = binary_href;
                post_de_sel    = binary_de;
                post_rgb_sel   = binary_rgb;
            end
            PROC_HIST: begin
                post_vsync_sel = hist_vsync;
                post_href_sel  = hist_href;
                post_de_sel    = hist_de;
                post_rgb_sel   = hist_rgb;
            end
            PROC_SOBEL: begin
                post_vsync_sel = sobel_vsync;
                post_href_sel  = sobel_href;
                post_de_sel    = sobel_de;
                post_rgb_sel   = sobel_rgb;
            end
            PROC_SCALE_HALF: begin
                post_vsync_sel = scale_vsync;
                post_href_sel  = scale_href;
                post_de_sel    = scale_de;
                post_rgb_sel   = scale_rgb;
            end
            PROC_GAUSS: begin
                post_vsync_sel = gauss_vsync;
                post_href_sel  = gauss_href;
                post_de_sel    = gauss_de;
                post_rgb_sel   = gauss_rgb;
            end
            PROC_ERODE: begin
                post_vsync_sel = erode_vsync;
                post_href_sel  = erode_href;
                post_de_sel    = erode_de;
                post_rgb_sel   = erode_rgb;
            end
            PROC_TELESCOPE: begin
                post_vsync_sel = telescope_vsync;
                post_href_sel  = telescope_href;
                post_de_sel    = telescope_de;
                post_rgb_sel   = telescope_rgb;
            end
            PROC_INVERT: begin
                post_vsync_sel = invert_vsync;
                post_href_sel  = invert_href;
                post_de_sel    = invert_de;
                post_rgb_sel   = invert_rgb;
            end
            PROC_BC_ADJ: begin
                post_vsync_sel = bc_vsync;
                post_href_sel  = bc_href;
                post_de_sel    = bc_de;
                post_rgb_sel   = bc_rgb;
            end
            PROC_CROP_QTR: begin
                post_vsync_sel = crop_vsync;
                post_href_sel  = crop_href;
                post_de_sel    = crop_de;
                post_rgb_sel   = crop_rgb;
            end
            PROC_GAMMA: begin
                post_vsync_sel = gamma_vsync;
                post_href_sel  = gamma_href;
                post_de_sel    = gamma_de;
                post_rgb_sel   = gamma_rgb;
            end
            PROC_FALSE: begin
                post_vsync_sel = false_vsync;
                post_href_sel  = false_href;
                post_de_sel    = false_de;
                post_rgb_sel   = false_rgb;
            end
            default: begin
                /* default uses bypass assignments above */
            end
        endcase
    end

    assign post_frame_vsync = post_vsync_sel;
    assign post_frame_href  = post_href_sel;
    assign post_frame_de    = post_de_sel;
    assign post_rgb         = post_rgb_sel;
endmodule

//RGB888转YCbCr，仅使用Y分量进行灰度输出
module rgb2ycbcr_888(
    input        clk,
    input        rst_n,
    input        pre_frame_vsync,
    input        pre_frame_href,
    input        pre_frame_de,
    input  [7:0] img_red,
    input  [7:0] img_green,
    input  [7:0] img_blue,
    output reg   post_frame_vsync,
    output reg   post_frame_href,
    output reg   post_frame_de,
    output reg [7:0] img_y,
    output reg [7:0] img_cb,
    output reg [7:0] img_cr
);
    reg        pre_frame_vsync_d;
    reg        pre_frame_href_d;
    reg        pre_frame_de_d;
    reg [7:0]  img_red_d;
    reg [7:0]  img_green_d;
    reg [7:0]  img_blue_d;

    wire [15:0] y_calc;

    assign y_calc = (img_red_d * 8'd77) + (img_green_d * 8'd150) + (img_blue_d * 8'd29);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_frame_vsync_d <= 1'b0;
            pre_frame_href_d  <= 1'b0;
            pre_frame_de_d    <= 1'b0;
            img_red_d         <= 8'd0;
            img_green_d       <= 8'd0;
            img_blue_d        <= 8'd0;
            post_frame_vsync  <= 1'b0;
            post_frame_href   <= 1'b0;
            post_frame_de     <= 1'b0;
            img_y             <= 8'd0;
            img_cb            <= 8'd128;
            img_cr            <= 8'd128;
        end else begin
            pre_frame_vsync_d <= pre_frame_vsync;
            pre_frame_href_d  <= pre_frame_href;
            pre_frame_de_d    <= pre_frame_de;
            img_red_d         <= img_red;
            img_green_d       <= img_green;
            img_blue_d        <= img_blue;

            post_frame_vsync  <= pre_frame_vsync_d;
            post_frame_href   <= pre_frame_href_d;
            post_frame_de     <= pre_frame_de_d;
            img_y             <= (y_calc + 16'd128) >> 8;
            img_cb            <= 8'd128;
            img_cr            <= 8'd128;
        end
    end
endmodule

//RGB直通处理
module video_proc_passthrough(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [23:0]in_rgb,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
        end else begin
            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            out_rgb         <= in_rgb;
        end
    end
endmodule

//灰度图输出
module video_proc_gray(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
        end else begin
            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            out_rgb         <= {in_gray, in_gray, in_gray};
        end
    end
endmodule

//灰度二值化输出
module video_proc_gray_binary #(
    parameter [7:0] THRESHOLD = 8'd128
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    wire [7:0] gray_bin = (in_gray >= THRESHOLD) ? 8'hFF : 8'h00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
        end else begin
            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            out_rgb         <= {gray_bin, gray_bin, gray_bin};
        end
    end
endmodule

//灰度直方图拉伸输出
module video_proc_histogram(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    reg        in_frame_vsync_d;
    reg [7:0]  frame_min;
    reg [7:0]  frame_max;
    reg [7:0]  latched_min;
    reg [7:0]  latched_max;

    wire frame_end = in_frame_vsync_d && !in_frame_vsync;
    wire [8:0] diff_gray = (in_gray > latched_min) ? {1'b0,(in_gray - latched_min)} : 9'd0;
    wire [8:0] range      = (latched_max > latched_min) ? {1'b0,(latched_max - latched_min)} : 9'd1;
    wire [16:0] scaled    = diff_gray * 9'd255;
    wire [7:0]  gray_eq   = scaled / range;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
            in_frame_vsync_d <= 1'b0;
            frame_min       <= 8'hFF;
            frame_max       <= 8'h00;
            latched_min     <= 8'd0;
            latched_max     <= 8'hFF;
        end else begin
            in_frame_vsync_d <= in_frame_vsync;

            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            out_rgb         <= {gray_eq, gray_eq, gray_eq};

            if (frame_end) begin
                if (frame_min <= frame_max) begin
                    latched_min <= frame_min;
                    latched_max <= frame_max;
                end
                frame_min <= 8'hFF;
                frame_max <= 8'h00;
            end else if (in_frame_de) begin
                if (in_gray < frame_min) frame_min <= in_gray;
                if (in_gray > frame_max) frame_max <= in_gray;
            end
        end
    end
endmodule

//Sobel边缘检测（3×3 卷积核）
module video_proc_sobel #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720,
    parameter USE_HREF = 0 // 0: 使用 DE+列计数判定行结束；1: 使用 href 下降沿判定行结束
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    // Verilog-2001 兼容：避免使用 $clog2，1280 宽度需要 11 bits。
    // 若更改 VIDEO_WIDTH，需手动更新 COL_WIDTH 或改为常量函数。
    localparam integer COL_WIDTH = 11;

    reg [COL_WIDTH-1:0] col_cnt = {COL_WIDTH{1'b0}};
    reg [15:0]          row_cnt = 16'd0;
    // 取消对 href 的硬依赖，使用 de 作为行活动标志，避免上游无 href 导致窗口永远无效
    reg                 in_href_d = 1'b0; // 保留用于透传，但窗口逻辑改用 in_frame_de
    reg                 in_de_d    = 1'b0; // 前一周期 de，用于检测行结束
    reg                 in_vsync_d = 1'b0;

    reg frame_vsync_d0 = 1'b0;
    reg frame_vsync_d1 = 1'b0;
    reg frame_href_d0  = 1'b0;
    reg frame_href_d1  = 1'b0;
    reg frame_de_d0    = 1'b0;
    reg frame_de_d1    = 1'b0;

    reg window_h_ready = 1'b0;
    reg window_h_ready_d = 1'b0;
    reg window_v_ready = 1'b0;
    reg window_v_ready_d = 1'b0;

    reg [7:0] line_buffer0 [0:VIDEO_WIDTH-1];
    reg [7:0] line_buffer1 [0:VIDEO_WIDTH-1];

    reg [7:0] win00 = 8'd0, win01 = 8'd0, win02 = 8'd0;
    reg [7:0] win10 = 8'd0, win11 = 8'd0, win12 = 8'd0;
    reg [7:0] win20 = 8'd0, win21 = 8'd0, win22 = 8'd0;

    wire [7:0] prev_row1_pixel = line_buffer0[col_cnt];
    wire [7:0] prev_row2_pixel = line_buffer1[col_cnt];

    // 行结束：
    // USE_HREF=1 时用 href 下降沿；否则使用列计数到 VIDEO_WIDTH-1 后在下一周期复位
    wire line_end_href = in_href_d && !in_frame_href; // 仅当 USE_HREF=1 有效
    wire line_end_cnt  = (in_frame_de && (col_cnt == VIDEO_WIDTH-1));
    wire line_end      = USE_HREF ? line_end_href : line_end_cnt;
    wire frame_start = !in_vsync_d && in_frame_vsync;

    // Sobel kernel (Gx / Gy)
    // | -1  0  1 |       | -1 -2 -1 |
    // | -2  0  2 |   &   |  0  0  0 |
    // | -1  0  1 |       |  1  2  1 |

        wire signed [12:0] gx =
                    ($signed({1'b0, win02}) - $signed({1'b0, win00}))
                + (($signed({1'b0, win12}) - $signed({1'b0, win10})) << 1)
                + ($signed({1'b0, win22}) - $signed({1'b0, win20}));

        wire signed [12:0] gy =
                    ($signed({1'b0, win20}) - $signed({1'b0, win00}))
                + (($signed({1'b0, win21}) - $signed({1'b0, win01})) << 1)
                + ($signed({1'b0, win22}) - $signed({1'b0, win02}));

    wire [12:0] abs_gx = gx[12] ? (~gx + 13'd1) : gx;
    wire [12:0] abs_gy = gy[12] ? (~gy + 13'd1) : gy;
    wire [13:0] mag_sum = abs_gx + abs_gy;
    wire [7:0] edge_val = (mag_sum > 13'd255) ? 8'hFF : mag_sum[7:0];
    // pixel_ready 表示当前周期 3x3 窗口已经填充好（不含边缘前两列与前两行）
    wire pixel_ready = window_h_ready_d && window_v_ready_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
            col_cnt         <= {COL_WIDTH{1'b0}};
            row_cnt         <= 16'd0;
            in_href_d       <= 1'b0;
            in_vsync_d      <= 1'b0;
            frame_vsync_d0  <= 1'b0;
            frame_vsync_d1  <= 1'b0;
            frame_href_d0   <= 1'b0;
            frame_href_d1   <= 1'b0;
            frame_de_d0     <= 1'b0;
            frame_de_d1     <= 1'b0;
            window_h_ready  <= 1'b0;
            window_h_ready_d <= 1'b0;
            window_v_ready  <= 1'b0;
            window_v_ready_d <= 1'b0;
            win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
            win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
            win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
        end else begin
            in_href_d  <= in_frame_href;
            in_de_d    <= in_frame_de;
            in_vsync_d <= in_frame_vsync;

            frame_vsync_d0 <= in_frame_vsync;
            frame_vsync_d1 <= frame_vsync_d0;
            frame_href_d0  <= in_frame_href;
            frame_href_d1  <= frame_href_d0;
            frame_de_d0    <= in_frame_de;
            frame_de_d1    <= frame_de_d0;

            window_h_ready_d <= window_h_ready;
            window_v_ready_d <= window_v_ready;

            // 输出的同步信号保持与输入延迟对齐，数据使能不再按 pixel_valid 过滤，便于上层保持行/帧时序完整
            out_frame_vsync <= frame_vsync_d1;
            out_frame_href  <= frame_href_d1;
            out_frame_de    <= frame_de_d1;

            // 列计数：使用 DE 有效周期加一；行结束（列到末尾）后复位
            if (!in_frame_de) begin
                // 空白或行间隔保持零
                col_cnt        <= {COL_WIDTH{1'b0}};
                window_h_ready <= 1'b0;
            end else begin
                if (col_cnt == VIDEO_WIDTH-1) begin
                    col_cnt        <= {COL_WIDTH{1'b0}};
                    window_h_ready <= 1'b0; // 新行重新累积
                end else begin
                    col_cnt <= col_cnt + {{(COL_WIDTH-1){1'b0}},1'b1};
                    if (col_cnt >= 2) window_h_ready <= 1'b1;
                end
            end

            if (frame_start) begin
                row_cnt        <= 16'd0;
                window_v_ready <= 1'b0;
            end else if (line_end) begin
                if (row_cnt < VIDEO_HEIGHT-1) begin
                    row_cnt <= row_cnt + 16'd1;
                end else begin
                    row_cnt <= row_cnt; // 饱和保持
                end
                if (row_cnt >= 16'd1) window_v_ready <= 1'b1;
            end

            if (!in_frame_de) begin
                // 保持窗口清零直到出现首个有效像素
                win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
                win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
                win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
            end else begin
                win00 <= win01;
                win01 <= win02;
                win02 <= prev_row2_pixel;

                win10 <= win11;
                win11 <= win12;
                win12 <= prev_row1_pixel;

                win20 <= win21;
                win21 <= win22;
                win22 <= in_gray;

                line_buffer1[col_cnt] <= prev_row1_pixel;
                line_buffer0[col_cnt] <= in_gray;
            end

            // 仅在窗口准备好时输出边缘值，否则输出0；保持 DE = 1 让显示侧能看到黑色边框而非丢失行列
            if (frame_de_d1) begin
                if (pixel_ready) begin
                    out_rgb <= {edge_val, edge_val, edge_val};
                end else begin
                    out_rgb <= 24'd0; // 边缘填0
                end
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end
endmodule

//视频缩放（简单二倍下采样+复制，VIDEO_WIDTH建议为偶数）
module video_proc_scale #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720,
    parameter USE_HREF = 0
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [23:0]in_rgb,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    localparam integer HALF_WIDTH = (VIDEO_WIDTH + 1) >> 1;
    // HALF_WIDTH=640 时需要 10 bits。
    localparam integer PAIR_CNT_WIDTH = 10;

    reg row_toggle = 1'b0;              // 奇偶行标志：0 计算与缓存，1 复用缓存
    reg col_toggle = 1'b0;              // 偶/奇列配对标志
    reg [PAIR_CNT_WIDTH-1:0] pair_idx = {PAIR_CNT_WIDTH{1'b0}}; // 已输出的缩放后像素对索引
    reg [23:0] first_pixel = 24'd0;     // 当前像素对第一像素
    reg        in_href_d = 1'b0;        // 延迟 href，仅当 USE_HREF=1 使用
    reg        in_de_d   = 1'b0;        // 延迟 de，用于行结束检测（无 href）
    reg [15:0] row_cnt   = 16'd0;       // 行计数限制高度

    reg [23:0] row_cache [0:HALF_WIDTH-1];

    wire [7:0] avg_r = (first_pixel[23:16] + in_rgb[23:16]) >> 1;
    wire [7:0] avg_g = (first_pixel[15:8]  + in_rgb[15:8])  >> 1;
    wire [7:0] avg_b = (first_pixel[7:0]   + in_rgb[7:0])   >> 1;
    wire [23:0] avg_rgb = {avg_r, avg_g, avg_b};

    wire line_end_href = in_href_d && !in_frame_href; // href 下降沿
    wire line_end_cnt  = (in_frame_de && (pair_idx == HALF_WIDTH-1) && col_toggle==1'b0); // 无 href 时最后一个配对完成
    wire line_end      = USE_HREF ? line_end_href : line_end_cnt;
    wire frame_start   = in_frame_vsync && !out_frame_vsync; // 简单帧开始判定

    // 半分辨率显示策略：只在左上 (VIDEO_WIDTH/2 x VIDEO_HEIGHT/2) 区域输出缩放后的像素，其余区域输出黑色，保持总体时序。
    // 使用 row_toggle/pair_idx 构造半分辨率，行计数 row_cnt 控制垂直区域。

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
            row_toggle      <= 1'b0;
            col_toggle      <= 1'b0;
            pair_idx        <= {PAIR_CNT_WIDTH{1'b0}};
            first_pixel     <= 24'd0;
            in_href_d       <= 1'b0;
            in_de_d         <= 1'b0;
            row_cnt         <= 16'd0;
        end else begin
            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            in_href_d       <= in_frame_href;
            in_de_d         <= in_frame_de;

            // 帧开始复位行状态
            if (frame_start) begin
                row_cnt    <= 16'd0;
                row_toggle <= 1'b0;
            end

            // 行结束（href 或计数）
            if (line_end) begin
                if (!USE_HREF) begin
                    pair_idx   <= {PAIR_CNT_WIDTH{1'b0}};
                    col_toggle <= 1'b0;
                end
                if (row_cnt < VIDEO_HEIGHT-1) row_cnt <= row_cnt + 16'd1; else row_cnt <= row_cnt;
                row_toggle <= ~row_toggle;
            end

            // 像素对处理
            if (in_frame_de) begin
                if (row_cnt < (VIDEO_HEIGHT>>1)) begin
                    if (!row_toggle) begin // 计算行
                        if (!col_toggle) begin
                            first_pixel <= in_rgb;
                            // 只在左半宽度输出，超过半宽输出黑
                            out_rgb     <= (pair_idx < (HALF_WIDTH)) ? in_rgb : 24'd0;
                            col_toggle  <= 1'b1;
                        end else begin
                            if (pair_idx < HALF_WIDTH) begin
                                out_rgb <= avg_rgb;     // 第二像素输出平均
                                row_cache[pair_idx] <= avg_rgb;
                            end else begin
                                out_rgb <= 24'd0;
                            end
                            pair_idx  <= pair_idx + {{(PAIR_CNT_WIDTH-1){1'b0}},1'b1};
                            col_toggle <= 1'b0;
                        end
                    end else begin // 复用行
                        if (pair_idx < HALF_WIDTH) begin
                            out_rgb <= row_cache[pair_idx];
                        end else begin
                            out_rgb <= 24'd0;
                        end
                        if (!col_toggle) begin
                            col_toggle <= 1'b1;
                        end else begin
                            pair_idx   <= pair_idx + {{(PAIR_CNT_WIDTH-1){1'b0}},1'b1};
                            col_toggle <= 1'b0;
                        end
                    end
                end else begin
                    out_rgb <= 24'd0; // 下半部分黑
                end
            end else begin
                out_rgb <= 24'd0; // 空白区域填 0
            end
        end
    end
endmodule

// 直方图均衡化 + 左下角图表 (简单条形) ：图表占宽度 256，高度 128，在帧左下角覆盖
// 灰度反相（简单演示功能，替换原直方图均衡模块）
module video_proc_invert(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    wire [7:0] inv_gray = 8'd255 - in_gray;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
        end else begin
            out_frame_vsync <= in_frame_vsync;
            out_frame_href  <= in_frame_href;
            out_frame_de    <= in_frame_de;
            out_rgb         <= {inv_gray, inv_gray, inv_gray};
        end
    end
endmodule

// 亮度 / 对比度 调整: 输出 = clip( ( (in_gray-128)*CONTRAST_NUM/CONTRAST_DEN ) + 128 + BRIGHTNESS )
module video_proc_brightness_contrast #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720,
    parameter signed [8:0] BRIGHTNESS = 9'sd0,           // -128..+127 增量
    parameter integer CONTRAST_NUM = 256,                // 对比度系数分子 (默认1.0)
    parameter integer CONTRAST_DEN = 256                 // 分母
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    wire signed [9:0] centered = {1'b0,in_gray} - 10'sd128;
    wire signed [18:0] mult    = centered * CONTRAST_NUM; // 10 * 9 bits approx
    wire signed [18:0] scaled  = mult / CONTRAST_DEN;
    wire signed [18:0] shifted = scaled + 19'sd128 + {{10{BRIGHTNESS[8]}},BRIGHTNESS};
    wire [7:0] adj_gray = (shifted < 0) ? 8'd0 : (shifted > 19'sd255 ? 8'd255 : shifted[7:0]);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin out_frame_vsync<=0; out_frame_href<=0; out_frame_de<=0; out_rgb<=0; end
        else begin
            out_frame_vsync<=in_frame_vsync; out_frame_href<=in_frame_href; out_frame_de<=in_frame_de;
            out_rgb <= {adj_gray,adj_gray,adj_gray};
        end
    end
endmodule

// 裁剪：只显示左上 1/4 区域，其余输出黑
module video_proc_crop_quarter #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [23:0] in_rgb,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    reg [15:0] x_cnt=0, y_cnt=0; reg href_d=0, vsync_d=0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin x_cnt<=0; y_cnt<=0; href_d<=0; vsync_d<=0; out_frame_vsync<=0; out_frame_href<=0; out_frame_de<=0; out_rgb<=0; end
        else begin
            vsync_d <= in_frame_vsync;
            href_d  <= in_frame_href;
            out_frame_vsync<=in_frame_vsync; out_frame_href<=in_frame_href; out_frame_de<=in_frame_de;
            if (in_frame_vsync && !vsync_d) begin y_cnt<=0; end
            if (!in_frame_href) x_cnt<=0; else if (in_frame_de) x_cnt <= x_cnt + 1'b1;
            if (href_d && !in_frame_href) y_cnt <= y_cnt + 1'b1;
            if (in_frame_de) begin
                if ( (x_cnt < (VIDEO_WIDTH>>1)) && (y_cnt < (VIDEO_HEIGHT>>1)) ) out_rgb <= in_rgb; else out_rgb <= 24'd0;
            end else out_rgb <= 0;
        end
    end
endmodule

//高斯滤波（3×3 卷积核）
module video_proc_gaussian #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720,
    parameter USE_HREF = 0
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    localparam integer COL_WIDTH = 11; // 1280 宽度需要 11 bits

    reg [COL_WIDTH-1:0] col_cnt = {COL_WIDTH{1'b0}};
    reg [15:0]          row_cnt = 16'd0;
    reg                 line_end_pending = 1'b0; // 新增：末列到达后等待 DE 拉低再复位
    reg                 in_href_d = 1'b0;
    reg                 in_de_d    = 1'b0; // 前一周期 de
    reg                 in_vsync_d = 1'b0;

    reg frame_vsync_d0 = 1'b0;
    reg frame_vsync_d1 = 1'b0;
    reg frame_href_d0  = 1'b0;
    reg frame_href_d1  = 1'b0;
    reg frame_de_d0    = 1'b0;
    reg frame_de_d1    = 1'b0;

    reg window_h_ready = 1'b0;
    reg window_h_ready_d = 1'b0;
    reg window_v_ready = 1'b0;
    reg window_v_ready_d = 1'b0;

    reg [7:0] line_buffer0 [0:VIDEO_WIDTH-1];
    reg [7:0] line_buffer1 [0:VIDEO_WIDTH-1];

    reg [7:0] win00 = 8'd0, win01 = 8'd0, win02 = 8'd0;
    reg [7:0] win10 = 8'd0, win11 = 8'd0, win12 = 8'd0;
    reg [7:0] win20 = 8'd0, win21 = 8'd0, win22 = 8'd0;

    wire [7:0] prev_row1_pixel = line_buffer0[col_cnt];
    wire [7:0] prev_row2_pixel = line_buffer1[col_cnt];

    wire line_end_href = in_href_d && !in_frame_href;
    wire last_col_hit  = (in_frame_de && (col_cnt == VIDEO_WIDTH-1));
    wire line_end      = USE_HREF ? line_end_href : last_col_hit; // 行结束判定仍在末列像素周期
    wire frame_start   = !in_vsync_d && in_frame_vsync;

    // Gaussian kernel
    // | 1  2  1 |
    // | 2  4  2 |  >> 4
    // | 1  2  1 |

    wire [11:0] blur_sum =
          win00 + (win01 << 1) + win02
        + (win10 << 1) + (win11 << 2) + (win12 << 1)
        + win20 + (win21 << 1) + win22;

    wire [7:0] blur_val = blur_sum >> 4;
    // 与 Sobel 修复一致，pixel_ready 仅指窗口有效；输出 DE 继续沿用输入的延迟版本
    wire pixel_ready = window_h_ready_d && window_v_ready_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
            col_cnt         <= {COL_WIDTH{1'b0}};
            row_cnt         <= 16'd0;
            in_href_d       <= 1'b0;
            in_vsync_d      <= 1'b0;
            frame_vsync_d0  <= 1'b0;
            frame_vsync_d1  <= 1'b0;
            frame_href_d0   <= 1'b0;
            frame_href_d1   <= 1'b0;
            frame_de_d0     <= 1'b0;
            frame_de_d1     <= 1'b0;
            window_h_ready  <= 1'b0;
            window_h_ready_d <= 1'b0;
            window_v_ready  <= 1'b0;
            window_v_ready_d <= 1'b0;
            win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
            win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
            win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
        end else begin
            in_href_d  <= in_frame_href;
            in_de_d    <= in_frame_de;
            in_vsync_d <= in_frame_vsync;

            frame_vsync_d0 <= in_frame_vsync;
            frame_vsync_d1 <= frame_vsync_d0;
            frame_href_d0  <= in_frame_href;
            frame_href_d1  <= frame_href_d0;
            frame_de_d0    <= in_frame_de;
            frame_de_d1    <= frame_de_d0;

            window_h_ready_d <= window_h_ready;
            window_v_ready_d <= window_v_ready;

            out_frame_vsync <= frame_vsync_d1;
            out_frame_href  <= frame_href_d1;
            out_frame_de    <= frame_de_d1;

            // 新列计数策略：末列命中当周期仍保持 col_cnt=VIDEO_WIDTH-1，置 line_end_pending；
            // 在随后的空白周期 (in_frame_de==0) 才复位 col_cnt 与 window_h_ready。
            if (!in_frame_de) begin
                if (line_end_pending) begin
                    col_cnt        <= {COL_WIDTH{1'b0}};
                    window_h_ready <= 1'b0;
                    line_end_pending <= 1'b0;
                end else begin
                    col_cnt        <= {COL_WIDTH{1'b0}};
                    window_h_ready <= 1'b0;
                end
            end else begin
                if (!line_end_pending) begin
                    if (col_cnt == VIDEO_WIDTH-1) begin
                        // 到达末列：保持计数值，标记等待
                        line_end_pending <= 1'b1;
                        // 不立即清 window_h_ready，允许末列像素正常使用窗口
                        if (col_cnt >= 2) window_h_ready <= 1'b1;
                    end else begin
                        col_cnt <= col_cnt + {{(COL_WIDTH-1){1'b0}},1'b1};
                        if (col_cnt >= 2) window_h_ready <= 1'b1;
                    end
                end
            end

            if (frame_start) begin
                row_cnt        <= 16'd0;
                window_v_ready <= 1'b0;
            end else if (line_end && last_col_hit) begin
                // 行结束仅在末列像素周期计数 +1（避免空白区重复加）
                if (row_cnt < VIDEO_HEIGHT-1) row_cnt <= row_cnt + 16'd1; else row_cnt <= row_cnt;
                if (row_cnt >= 16'd1) window_v_ready <= 1'b1;
            end

            if (!in_frame_de) begin
                win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
                win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
                win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
            end else begin
                win00 <= win01;
                win01 <= win02;
                win02 <= prev_row2_pixel;

                win10 <= win11;
                win11 <= win12;
                win12 <= prev_row1_pixel;

                win20 <= win21;
                win21 <= win22;
                win22 <= in_gray;

                line_buffer1[col_cnt] <= prev_row1_pixel;
                line_buffer0[col_cnt] <= in_gray;
            end

            if (frame_de_d1) begin
                if (pixel_ready) begin
                    out_rgb <= {blur_val, blur_val, blur_val};
                end else begin
                    out_rgb <= 24'd0; // 边缘填0
                end
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end
endmodule

//腐蚀（3×3 结构元素）
module video_proc_erosion #(
    parameter integer VIDEO_WIDTH  = 1280,
    parameter integer VIDEO_HEIGHT = 720,
    parameter USE_HREF = 0
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    localparam integer COL_WIDTH = 11; // 1280 宽度需要 11 bits

    reg [COL_WIDTH-1:0] col_cnt = {COL_WIDTH{1'b0}};
    reg [15:0]          row_cnt = 16'd0;
    reg                 line_end_pending = 1'b0;
    reg                 in_href_d = 1'b0;
    reg                 in_de_d    = 1'b0; // 前一周期 de
    reg                 in_vsync_d = 1'b0;

    reg frame_vsync_d0 = 1'b0;
    reg frame_vsync_d1 = 1'b0;
    reg frame_href_d0  = 1'b0;
    reg frame_href_d1  = 1'b0;
    reg frame_de_d0    = 1'b0;
    reg frame_de_d1    = 1'b0;

    reg window_h_ready = 1'b0;
    reg window_h_ready_d = 1'b0;
    reg window_v_ready = 1'b0;
    reg window_v_ready_d = 1'b0;

    reg [7:0] line_buffer0 [0:VIDEO_WIDTH-1];
    reg [7:0] line_buffer1 [0:VIDEO_WIDTH-1];

    reg [7:0] win00 = 8'd0, win01 = 8'd0, win02 = 8'd0;
    reg [7:0] win10 = 8'd0, win11 = 8'd0, win12 = 8'd0;
    reg [7:0] win20 = 8'd0, win21 = 8'd0, win22 = 8'd0;

    wire [7:0] prev_row1_pixel = line_buffer0[col_cnt];
    wire [7:0] prev_row2_pixel = line_buffer1[col_cnt];

    wire line_end_href = in_href_d && !in_frame_href;
    wire last_col_hit  = (in_frame_de && (col_cnt == VIDEO_WIDTH-1));
    wire line_end      = USE_HREF ? line_end_href : last_col_hit;
    wire frame_start = !in_vsync_d && in_frame_vsync;

    reg [7:0] min_val;
    // 与 Sobel/Gaussian 保持一致，窗口准备好后才输出处理值；DE 保持输入延迟，边缘输出0
    wire pixel_ready = window_h_ready_d && window_v_ready_d;

    always @(*) begin
        min_val = win00;
        if (win01 < min_val) min_val = win01;
        if (win02 < min_val) min_val = win02;
        if (win10 < min_val) min_val = win10;
        if (win11 < min_val) min_val = win11;
        if (win12 < min_val) min_val = win12;
        if (win20 < min_val) min_val = win20;
        if (win21 < min_val) min_val = win21;
        if (win22 < min_val) min_val = win22;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync <= 1'b0;
            out_frame_href  <= 1'b0;
            out_frame_de    <= 1'b0;
            out_rgb         <= 24'd0;
            col_cnt         <= {COL_WIDTH{1'b0}};
            row_cnt         <= 16'd0;
            in_href_d       <= 1'b0;
            in_vsync_d      <= 1'b0;
            frame_vsync_d0  <= 1'b0;
            frame_vsync_d1  <= 1'b0;
            frame_href_d0   <= 1'b0;
            frame_href_d1   <= 1'b0;
            frame_de_d0     <= 1'b0;
            frame_de_d1     <= 1'b0;
            window_h_ready  <= 1'b0;
            window_h_ready_d <= 1'b0;
            window_v_ready  <= 1'b0;
            window_v_ready_d <= 1'b0;
            win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
            win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
            win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
        end else begin
            in_href_d  <= in_frame_href;
            in_de_d    <= in_frame_de;
            in_vsync_d <= in_frame_vsync;

            frame_vsync_d0 <= in_frame_vsync;
            frame_vsync_d1 <= frame_vsync_d0;
            frame_href_d0  <= in_frame_href;
            frame_href_d1  <= frame_href_d0;
            frame_de_d0    <= in_frame_de;
            frame_de_d1    <= frame_de_d0;

            window_h_ready_d <= window_h_ready;
            window_v_ready_d <= window_v_ready;

            out_frame_vsync <= frame_vsync_d1;
            out_frame_href  <= frame_href_d1;
            out_frame_de    <= frame_de_d1;

            if (!in_frame_de) begin
                if (line_end_pending) begin
                    col_cnt <= {COL_WIDTH{1'b0}};
                    window_h_ready <= 1'b0;
                    line_end_pending <= 1'b0;
                end else begin
                    col_cnt <= {COL_WIDTH{1'b0}};
                    window_h_ready <= 1'b0;
                end
            end else begin
                if (!line_end_pending) begin
                    if (col_cnt == VIDEO_WIDTH-1) begin
                        line_end_pending <= 1'b1; // 保持末列使用
                        if (col_cnt >= 2) window_h_ready <= 1'b1;
                    end else begin
                        col_cnt <= col_cnt + {{(COL_WIDTH-1){1'b0}},1'b1};
                        if (col_cnt >= 2) window_h_ready <= 1'b1;
                    end
                end
            end

            if (frame_start) begin
                row_cnt        <= 16'd0;
                window_v_ready <= 1'b0;
            end else if (line_end && last_col_hit) begin
                if (row_cnt < VIDEO_HEIGHT-1) row_cnt <= row_cnt + 16'd1; else row_cnt <= row_cnt;
                if (row_cnt >= 16'd1) window_v_ready <= 1'b1;
            end

            if (!in_frame_de) begin
                win00 <= 8'd0; win01 <= 8'd0; win02 <= 8'd0;
                win10 <= 8'd0; win11 <= 8'd0; win12 <= 8'd0;
                win20 <= 8'd0; win21 <= 8'd0; win22 <= 8'd0;
            end else begin
                win00 <= win01;
                win01 <= win02;
                win02 <= prev_row2_pixel;

                win10 <= win11;
                win11 <= win12;
                win12 <= prev_row1_pixel;

                win20 <= win21;
                win21 <= win22;
                win22 <= in_gray;

                line_buffer1[col_cnt] <= prev_row1_pixel;
                line_buffer0[col_cnt] <= in_gray;
            end

            if (frame_de_d1) begin
                if (pixel_ready) begin
                    out_rgb <= {min_val, min_val, min_val};
                end else begin
                    out_rgb <= 24'd0; // 边缘填0
                end
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end
endmodule

// 伽马校正模块：使用粗 LUT (LUT_POINTS) + 线性插值，默认 gamma=2.20
module video_proc_gamma #(
    parameter integer GAMMA_SCALE = 220,      // 2.20 => 输入灰度^(1/γ)，这里用简单幂近似 LUT
    parameter integer LUT_POINTS  = 64,
    parameter integer VIDEO_WIDTH = 1280,
    parameter integer VIDEO_HEIGHT= 720
)(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    // 简单 LUT：索引 0..LUT_POINTS，对应线性输入 0..255 分段。LUT 预存 (i/ (LUT_POINTS-1))^(1/gamma)*255
    // 为简化，这里离线计算的近似值硬编码（gamma=2.2）。可后续换成初始化文件或生成逻辑。
    // 使用 64 点时，每段长度 step = 255/(LUT_POINTS-1) ≈ 4。
    reg [7:0] gamma_lut [0:LUT_POINTS-1];
    integer gi;
    initial begin
        // 通过 Python 或脚本可生成，下列为近似值(示例)：
        // i from 0..63: floor( (i/63)^(1/2.2) *255 )
        gamma_lut[0]=0; gamma_lut[1]=32; gamma_lut[2]=45; gamma_lut[3]=55; gamma_lut[4]=63; gamma_lut[5]=70; gamma_lut[6]=76; gamma_lut[7]=81;
        gamma_lut[8]=86; gamma_lut[9]=90; gamma_lut[10]=94; gamma_lut[11]=98; gamma_lut[12]=101; gamma_lut[13]=105; gamma_lut[14]=108; gamma_lut[15]=111;
        gamma_lut[16]=114; gamma_lut[17]=117; gamma_lut[18]=120; gamma_lut[19]=122; gamma_lut[20]=125; gamma_lut[21]=128; gamma_lut[22]=130; gamma_lut[23]=133;
        gamma_lut[24]=135; gamma_lut[25]=138; gamma_lut[26]=140; gamma_lut[27]=143; gamma_lut[28]=145; gamma_lut[29]=147; gamma_lut[30]=150; gamma_lut[31]=152;
        gamma_lut[32]=154; gamma_lut[33]=157; gamma_lut[34]=159; gamma_lut[35]=161; gamma_lut[36]=163; gamma_lut[37]=165; gamma_lut[38]=168; gamma_lut[39]=170;
        gamma_lut[40]=172; gamma_lut[41]=174; gamma_lut[42]=176; gamma_lut[43]=178; gamma_lut[44]=180; gamma_lut[45]=182; gamma_lut[46]=184; gamma_lut[47]=186;
        gamma_lut[48]=188; gamma_lut[49]=190; gamma_lut[50]=192; gamma_lut[51]=194; gamma_lut[52]=196; gamma_lut[53]=198; gamma_lut[54]=200; gamma_lut[55]=201;
        gamma_lut[56]=203; gamma_lut[57]=205; gamma_lut[58]=207; gamma_lut[59]=209; gamma_lut[60]=211; gamma_lut[61]=213; gamma_lut[62]=215; gamma_lut[63]=255;
    end
    // 插值：计算所在段与小数部分
    wire [6:0] idx = {1'b0, in_gray[7:2]}; // 0..63 (取高 6bit 对应 64 点)
    wire [1:0] frac = in_gray[1:0];        // 低2位作为 0..3 分数
    wire [7:0] lut_a = gamma_lut[idx];
    wire [7:0] lut_b = gamma_lut[(idx==LUT_POINTS-1)? idx : idx+1];
    wire [8:0] diff  = {1'b0,lut_b} - {1'b0,lut_a};
    wire [9:0] interp = {1'b0,lut_a} + ((diff * frac) >> 2); // 线性插值分母4
    wire [7:0] gamma_val = (interp[9]) ? 8'd255 : interp[7:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync<=0; out_frame_href<=0; out_frame_de<=0; out_rgb<=0;
        end else begin
            out_frame_vsync<=in_frame_vsync; out_frame_href<=in_frame_href; out_frame_de<=in_frame_de;
            if (in_frame_de) out_rgb <= {gamma_val,gamma_val,gamma_val}; else out_rgb <= 24'd0;
        end
    end
endmodule

// 灰度伪彩：分段梯度 (Blue->Cyan->Green->Yellow->Red)
module video_proc_false_color(
    input        clk,
    input        rst_n,
    input        in_frame_vsync,
    input        in_frame_href,
    input        in_frame_de,
    input  [7:0] in_gray,
    output reg   out_frame_vsync,
    output reg   out_frame_href,
    output reg   out_frame_de,
    output reg [23:0] out_rgb
);
    // 分五段：0-51,52-102,103-153,154-204,205-255
    // 颜色过渡：
    // 0: Blue (0,0,255) -> Cyan (0,255,255)
    // 1: Cyan -> Green (0,255,0)
    // 2: Green -> Yellow (255,255,0)
    // 3: Yellow -> Red (255,0,0)
    // 4: 最顶 Red 保持
    wire [8:0] g_ext = {1'b0,in_gray};
    reg [7:0] r,g,b;
    always @(*) begin
        if (in_gray <= 8'd51) begin // Blue->Cyan
            r = 8'd0;
            g = (in_gray * 5'd5); // 0..255 (51*5≈255)
            b = 8'd255;
        end else if (in_gray <= 8'd102) begin // Cyan->Green
            r = 8'd0;
            g = 8'd255;
            b = 8'd255 - ((in_gray-8'd52) * 5'd5); // 下降到0
        end else if (in_gray <= 8'd153) begin // Green->Yellow (增加Red)
            r = (in_gray-8'd103) * 5'd5; // 0..255
            g = 8'd255;
            b = 8'd0;
        end else if (in_gray <= 8'd204) begin // Yellow->Red (减少Green)
            r = 8'd255;
            g = 8'd255 - ((in_gray-8'd154) * 5'd5);
            b = 8'd0;
        end else begin // Red 保持
            r = 8'd255; g = 8'd0; b = 8'd0;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_frame_vsync<=0; out_frame_href<=0; out_frame_de<=0; out_rgb<=0;
        end else begin
            out_frame_vsync<=in_frame_vsync; out_frame_href<=in_frame_href; out_frame_de<=in_frame_de;
            out_rgb <= in_frame_de ? {r,g,b} : 24'd0;
        end
    end
endmodule
