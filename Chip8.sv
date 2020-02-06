/********************************************************/
/* Chip8.sv                                             */
/* Original core by Carsten Elton Sørensen              */
/* Ported from MiST to MiSTer by Paul Sajna (sajattack) */
/********************************************************/


module emu
(
	//Master input clock
	input         CLK_50M,
	
	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,
	
	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,
	
	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,
	
	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,
	
	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,
	
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output  [1:0] VGA_SL,
	
	output        LED_USER,  // 1 - ON, 0 - OFF.
	
	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,
	
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	
	//ADC
	inout   [3:0] ADC_BUS,
	
	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,
	
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
	
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
	
	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);


`include "build_id.v" 
localparam CONF_STR = {
	"Chip8;;",
	"-;",
	"F,CH8;",
	"-;",
	"O4,Aspect ratio,4:3,16:9;",
	"O8A,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O2,CPU Speed,Fast,Slow;",
	"-;",
	"R0,Reset;",
	//"J,",
	"V,v",`BUILD_DATE
};
 


wire [31:0] status;
wire        forced_scandoubler;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;
wire        ioctl_download;
wire 			ioctl_wait;
//wire [10:0] ps2_key;
wire  [1:0] buttons;
wire [21:0] gamma_bus;

wire [14:0] ldata, rdata;

wire ps2_clk;
wire [7:0] ps2_dat;

hps_io #(.STRLEN($size(CONF_STR)>>3),.PS2DIV(4000)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.forced_scandoubler(forced_scandoubler),
	
	.buttons(buttons),
	.status(status),
	
	.ps2_kbd_clk_out(ps2_clk),
	.ps2_kbd_data_out(ps2_dat),

);




reg [4:0] audio_count;
always @(posedge clk_12k)
	audio_count <= audio_count + 1'b1;

wire audio_enable;
wire audio = audio_enable && &audio_count[4:3];
assign AUDIO_R = {1'b0,{15{audio}}};
assign AUDIO_L = {1'b0,{15{audio}}};
assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

assign LED_POWER = 0;
assign LED_DISK  = 0;
assign LED_USER  = ioctl_download;

assign VIDEO_ARX    = status[4] ? 8'd16 : 8'd4;
assign VIDEO_ARY    = status[4] ? 8'd9  : 8'd3;

assign CE_PIXEL = 1'b1;

wire [2:0] scale = status[10:8];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign VGA_SL = sl[1:0];
assign VGA_F1 = 0;

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CKE, SDRAM_CLK, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign USER_OUT = '1;
assign ADC_BUS  = 'Z;
assign BUTTONS = 0;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;


wire clk_sys; // 50MHz
wire clk_cpu_fast, clk_cpu_slow; // 12.5KHz or 5KHz
wire clk_video; // 13.5MHz
wire clk_12k; // 12 KHz
wire clk_1m; // 1MHz, for dividing into the required smaller amounts
wire locked;
wire cpu_clk;
wire error;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_video),
	.outclk_1(clk_1m),
	.locked(locked)
);

reg [6:0] clkdiv_12_5_count;
always @(posedge clk_1m) begin
	clkdiv_12_5_count <= clkdiv_12_5_count + 7'd1;
	if (clkdiv_12_5_count == 79) begin
		clk_cpu_fast <= ~clk_cpu_fast;
		clkdiv_12_5_count <= 0;
	end
end

reg [6:0] clkdiv_12_count;
always @(posedge clk_1m) begin
	clkdiv_12_count <= clkdiv_12_count + 7'd1;
	if (clkdiv_12_count == 82) begin // should be 82 + 1/3 but yolo
		clk_12k <= ~clk_12k;
		clkdiv_12_count <= 0;
	end
end

reg [7:0] clkdiv_5_count;
always @(posedge clk_1m) begin
	clkdiv_5_count <= clkdiv_5_count + 8'd1;
	if (clkdiv_5_count == 199) begin
		clk_cpu_slow <= ~clk_cpu_slow;
		clkdiv_5_count <= 0;
	end
end
	
assign clk_sys = CLK_50M;
assign CLK_VIDEO = clk_video;
assign cpu_clk = status[2] ? clk_cpu_slow : clk_cpu_fast;

// Reset circuit

wire error_posedge;
util_posedge ErrorPosedge(clk_12k, 0, error, error_posedge);

wire downloading_negedge;
util_negedge downloadingNegedge(clk_12k, 0, ioctl_download, downloading_negedge);

wire button1_posedge;
util_posedge ButtonPosedge(clk_12k, 0, buttons[1] | status[0] | RESET, button1_posedge);

reg [4:0] reset_count = 0;
reg reset = 0;

always @(posedge clk_12k) begin
	if (reset) begin
		if (reset_count[4]) begin
			reset <= 1'b0;
			reset_count <= 0;
		end else begin
			reset_count <= reset_count + 1'b1;
		end;
	end else if (downloading_negedge || button1_posedge || error_posedge) begin
		reset <= 1'b1;
	end;
end



// Chip-8 machine

wire [15:0] current_opcode;

chip8 chip8machine(
	reset,
	
	clk_video,
	cpu_clk,
	clk_sys,
	
	ioctl_download,
	1,
	status[4],
	
	VGA_HS, VGA_VS,
	VGA_R[5:3], VGA_G[5:3], VGA_B[5:4],
	VGA_DE,
	
	current_opcode,

	audio_enable,
	
	ps2_dat,
	ps2_clk,
	
	ioctl_download,
	ioctl_wr,
	clk_sys,
	ioctl_addr[11:0] + 12'd512,
	ioctl_data,
	
	error
);




endmodule
