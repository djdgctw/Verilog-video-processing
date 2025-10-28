# Lab8_DDR_HDMI_Loop（DDR 帧缓存 + HDMI 回环）

本目录包含一个基于 DDR3 帧缓存的 HDMI 输入→图像处理→HDMI 输出的完整工程。系统通过 LT8619（HDMI RX）接收视频，经图像处理 IP（核心模块 `vip_gray`）处理后写入 DDR3，再从 DDR3 读出并通过 LT8618（HDMI TX）输出。顶层为 `Lab8_DDR_HDMI_Loop.v`。

**核心亮点：`vip_gray` 多模式视频处理**
- 支持 RGB888 → 灰度的实时转换，并并行准备多种处理结果，由 `proc_sel` 动态选择输出。
- 支持缩放/平移（Zoom & Pan）交互控制：`zoom_in/zoom_out/move_{up,down,left,right}`。
- 针对实时视频流的逐像素流水线设计，接口与时序对齐信号（vsync/href/de）保持一致。

---

**整体架构**
- HDMI 输入：`LT8619_Interface.v` 负责 I2C 配置 LT8619 并提供像素时钟与 RGB888 视频流。
- 视频分析：`Video_Analyze_Interface.v` 识别分辨率、给出坐标与有效区，透传视频。
- 图像处理：`vip_gray.v` 按 `proc_sel` 选择处理模式输出。
- 帧缓存：
  - 写入：`Frame_WR_Interface.v` 将处理后帧写入 DDR（RGB888 压缩为 16b 并突发写）。
  - 读取：`Frame_RD_Interface.v` 从 DDR 读回并还原为 RGB888，与参考时序对齐输出。
  - 控制：`DDR3_Interface.v` 内含读/写仲裁与 AXI4 时序适配，连接外部 DDR3 器件。
- HDMI 输出：`LT8618_Interface.v` 负责 I2C 配置 LT8618 并驱动输出。

---

**顶层接口与关键信号（`Lab8_DDR_HDMI_Loop.v`）**
- 视频输入（来自 LT8619）：`i_hdmi1_{data[23:0], vde, hsync, vsync, clk}`
- 处理模式选择：`i_video_proc_sel[3:0]`（透传/灰度/二值化/边缘/缩放/模糊/腐蚀/反色/亮度对比度/Gamma/伪彩等）
- 交互控制：`zoom_in, zoom_out, move_up, move_down, move_left, move_right`
- 视频输出（至 LT8618）：`o_hdmi3_{data[23:0], vde, hsync, vsync, clk}`
- DDR3 引脚：`o_ddr3_*` 与 `o_ddr3_dq/dqs` 等数据/时钟/控制信号
- I2C：`o_hdmi1_scl/io_hdmi1_sda`（LT8619），`o_hdmi3_scl/io_hdmi3_sda`（LT8618）

---

**核心模块：`vip_gray`**（source/vip_gray.v）
- 作用：将输入 RGB888 转 Y 分量（`rgb2ycbcr_888`），并行送入多种处理模块；通过 `proc_sel` 选择一种结果作为输出，并保证与输入时序对齐。
- 端口：
  - 时序输入：`pre_frame_{vsync, href, de}`，像素 `pre_rgb[23:0]`，时钟 `clk`，复位 `rst_n`
  - 模式选择：`proc_sel[3:0]`
  - 交互控制：`zoom_in/zoom_out/move_*`（主要用于缩放/平移相关模式）
  - 时序输出：`post_frame_{vsync, href, de}`，像素 `post_rgb[23:0]`
- 内部流程：
  1) `rgb2ycbcr_888` 计算 Y（亮度），同时对 vsync/href/de 做一路对齐。
  2) 将 Y 输入到并行的处理单元（灰度、二值化、直方图处理、Sobel、缩放、模糊、腐蚀、反色、亮度/对比度、裁剪、Gamma、伪彩等）。
  3) 根据 `proc_sel` 复用选择对应的 `*_rgb` 和对齐后的时序作为输出。
- 支持的处理模式（`proc_sel` 定义）：
  - `4'b0000` 直通（Pass-through）
  - `4'b0001` 灰度（Grayscale，RGB→Y）
  - `4'b0010` 二值化（Binarization，固定阈值 128）
  - `4'b0011` 直方图拉伸/均衡（Histogram Stretch/Equalize，按实现为拉伸）
  - `4'b0100` Sobel 边缘（3x3，|Gx|+|Gy|）
  - `4'b0101` 半倍率缩放（Scale 1/2）
  - `4'b0110` 3x3 高斯模糊（核 [1 2 1; 2 4 2; 1 2 1]/16）
  - `4'b0111` 腐蚀（Erosion 3x3）
  - `4'b1000` 缩放/平移（Zoom & Pan，响应 `zoom_*` 与 `move_*`）
  - `4'b1001` 反色（Invert，255-Y）
  - `4'b1010` 亮度/对比度调整（Brightness/Contrast）
  - `4'b1011` 裁剪四分之一（Crop Quarter）
  - `4'b1100` Gamma 校正（默认约 2.2）
  - `4'b1101` 伪彩色（False Color）

提示：`vip_gray.v` 中声明了所需的子模块接口（如 `video_proc_gray`、`video_proc_sobel` 等）。综合时需确保这些处理子模块与 `rgb2ycbcr_888` 一并加入工程。

---

**帧缓存链路**
- 写 DDR：`Frame_WR_Interface.v`
  - 将 `vip_gray` 输出的 RGB888 压缩为 16bit（5:6:5），使用 128bit 宽度、BL=8 的突发写入。
  - 通过 `FIFO_16x4096x128` 做跨时钟域缓冲，状态机在场同步下轮转地址。
- 读 DDR：`Frame_RD_Interface.v`
  - AXI 端口 128bit 读出，`FIFO_128x512x16` 跨时钟域后在视频侧还原为 RGB888。
  - 与输入参考时序（来自处理后视频）对齐输出，为 HDMI 发送端提供稳定视频时序。
- 仲裁/PHY：`DDR3_Interface.v` 提供 AXI4 接口仲裁与 DDR3 物理引脚管理（含 100MHz 时钟、初始化锁定指示）。

---

**文件一览（关键模块）**
- `Lab8_DDR_HDMI_Loop.v` 顶层，连接 HDMI RX/TX、视频处理、DDR3。
- `Image_Process_Interface.v` 串接 视频分析 → 处理（`vip_gray`）→ DDR 帧缓存（写/读）。
- `vip_gray.v` 图像处理核心，`proc_sel` 模式选择与交互控制。
- `Video_Analyze_Interface.v` 分辨率/坐标解析与时序透传。
- `Frame_WR_Interface.v` 帧写入 DDR，跨域 FIFO、突发写状态机。
- `Frame_RD_Interface.v` 帧读取 DDR，还原 RGB 并与时序对齐。
- `DDR3_Interface.v` DDR 仲裁/AXI4/时钟与外设汇聚。
- `LT8619_Interface.v`、`LT8618_Interface.v` HDMI RX/TX 的 I2C 配置与接口。
- 其他：`Clock_Interface.v`、`IIC_Interface.v`、`DDR_*_Ctrl.v` 等底层支撑模块。

---

**使用说明（综合与调试）**
- 顶层模块：综合 `Lab8_DDR_HDMI_Loop.v`，按板卡连接 DDR3 与 LT8619/LT8618 器件引脚。
- 模式选择：驱动 `i_video_proc_sel[3:0]` 切换处理模式（上表定义）。
- 交互控制：在 `proc_sel=4'b1000`（Zoom & Pan）下，使能 `zoom_in/zoom_out/move_*` 可进行缩放/平移。
- 分辨率：当前默认参数为 1280x720（可在 `vip_gray` 的 `VIDEO_WIDTH/HEIGHT` 参数修改）。
- 依赖与 IP：
  - FIFO：`FIFO_16x4096x128`、`FIFO_128x512x16`（跨时钟域）
  - 时钟缓冲/PLL：`GTP_CLKBUFG` 等（按器件/工具替换）
  - DDR 控制：`DDR_Arbitration_WR_Ctrl.v`、`DDR_Arbitration_RD_Ctrl.v` 等
  - 图像处理子模块：`rgb2ycbcr_888.v` 与 `video_proc_*` 系列
  请确保以上文件或对应 IP 已加入工程并与目标 FPGA/DDR3 兼容。

---

**已知注意点**
- `vip_gray.v` 引用的若干 `video_proc_*` 子模块未包含在本目录，请从你的公共库或上级目录补齐。
- DDR3 与 HDMI 芯片初始化时序依赖 I2C 配置，需保证 `i_rstn`、时钟与上电顺序正确。
- 不同分辨率下，缩放/裁剪等模式的参数范围需与实际视频宽高匹配。

---

**快速定位**
- 顶层入口：`Lab8_DDR_HDMI_Loop.v`
- 核心处理：`vip_gray.v`
- 帧缓存写：`Frame_WR_Interface.v`
- 帧缓存读：`Frame_RD_Interface.v`

如需我补充 `video_proc_*` 的简单参考实现或添加仿真测试平台，请告诉我期望的模式与验证分辨率。

