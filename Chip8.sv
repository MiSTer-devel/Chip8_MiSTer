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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

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
	"F1,CH8,Load Program;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[6:5],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"O[10:8],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O[15:13],Palette,White,Amber,Green,Inverted,LCD,Custom;",
	"H0F2,GBP,Load Custom Palette;",
	"-;",
	"O[2],CPU Speed,Fast,Slow;",
	"-;",
	"R0,Reset;",
	//"J,",
	"V,v",`BUILD_DATE
};



wire [127:0] status;

localparam PAL_CUSTOM = 3'd5;
wire [2:0] palette_sel = status[15:13];
wire        forced_scandoubler;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire [15:0] ioctl_index;
wire        ioctl_download;
wire 			ioctl_wait;
//wire [10:0] ps2_key;
wire  [1:0] buttons;
wire [21:0] gamma_bus;

wire [14:0] ldata, rdata;

wire ps2_clk;
wire [7:0] ps2_dat;

hps_io #(.CONF_STR(CONF_STR),.PS2DIV(4000)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.forced_scandoubler(forced_scandoubler),

	.gamma_bus(gamma_bus),

	.buttons(buttons),
	.status(status),
	.status_menumask({15'd0, palette_sel != PAL_CUSTOM}),

	.ps2_kbd_clk_out(ps2_clk),
	.ps2_kbd_data_out(ps2_dat)

);




// A palette (menu index 2) must not touch CHIP-8 memory or reset the machine.
// Everything else is a program.
wire pal_download = ioctl_download && ioctl_index[5:0] == 6'd2;
wire rom_download = ioctl_download && !pal_download;

reg [4:0] audio_count;
always @(posedge clk_12k)
	audio_count <= audio_count + 1'b1;

wire audio_enable;
wire audio = audio_enable && &audio_count[4:3];
assign AUDIO_R = audio ? 16'h2000: 16'h0000;
assign AUDIO_L = audio ? 16'h2000: 16'h0000;
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_POWER = 0;
assign LED_DISK  = 0;
assign LED_USER  = rom_download;

wire [2:0] scale = status[10:8];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign VGA_SL = sl[1:0];
assign VGA_F1 = 0;

assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CKE, SDRAM_CLK, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign USER_OUT = '1;
assign ADC_BUS  = 'Z;
assign BUTTONS = 0;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;


wire clk_sys; // 50MHz
wire clk_cpu_fast, clk_cpu_slow; // 6.25KHz or 2.5KHz
wire clk_video; // 13.5MHz, clocks the core's display logic
wire clk_video_x4; // 54MHz, CLK_VIDEO: gives the scandoubler its 4x headroom
wire clk_12k; // 6 KHz, despite the name
wire clk_1m; // 1MHz, for dividing into the required smaller amounts
wire locked;
wire cpu_clk;
wire error;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_video),
	.outclk_1(clk_1m),
	.outclk_2(clk_video_x4),
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
assign CLK_VIDEO = clk_video_x4;
assign cpu_clk = status[2] ? clk_cpu_slow : clk_cpu_fast;

// Reset circuit

wire error_posedge;
util_posedge ErrorPosedge(clk_12k, 0, error, error_posedge);

wire downloading_negedge;
util_negedge downloadingNegedge(clk_12k, 0, rom_download, downloading_negedge);

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

wire core_hs, core_vs;        // negative sync
wire core_hblank, core_vblank; // these frame the playfield only
wire core_pixel;

chip8 chip8machine(
	.res(reset),

	.disp_clk(clk_video),
	.cpu_clk(cpu_clk),
	.blit_clk(clk_sys),

	.cpu_halt(rom_download),

	// One fixed 15.7kHz raster. The aspect ratio option belongs to the HDMI
	// scaler; it must not reshape the picture on the analog output.
	.ntsc(1'b1),
	.vga_wide(1'b0),

	.vga_hsync(core_hs),
	.vga_vsync(core_vs),
	.vga_pixel(core_pixel),
	.vga_hblank(core_hblank),
	.vga_vblank(core_vblank),

	.cpu_opcode(current_opcode),

	.audio_enable(audio_enable),

	.ps2_data(ps2_dat[0]),
	.ps2_clk(ps2_clk),

	.uploading(rom_download),
	.upload_en(ioctl_wr & rom_download),
	.upload_clk(clk_sys),
	.upload_addr(ioctl_addr[11:0] + 12'd512),
	.upload_data(ioctl_data),

	.error(error)
);

// Palettes for the 1-bit picture: {dot on, dot off}

// A custom palette is a 16-byte MiSTer Game Boy .gbp file (four RGB888
// colours and four spare bytes). As in the Studio II core, the first colour
// is used for lit dots and the last for the background. Only a complete file
// is committed.
reg [127:0] pal_stage;
reg  [47:0] pal_custom = {24'hFFFFFF, 24'h000000};

always @(posedge clk_sys) begin
	if (pal_download && ioctl_wr && ioctl_addr < 25'd16) begin
		pal_stage <= {pal_stage[119:0], ioctl_data};
		if (ioctl_addr == 25'd15)
			pal_custom <= {pal_stage[119:96], pal_stage[47:24]};
	end
end

reg [47:0] pal;
always @(*) begin
	case (palette_sel)
		3'd0:    pal = {24'hFFFFFF, 24'h000000}; // White
		3'd1:    pal = {24'hFFBF5A, 24'h000000}; // Amber
		3'd2:    pal = {24'h8FFF63, 24'h000000}; // Green
		3'd3:    pal = {24'h000000, 24'hFFFFFF}; // Inverted
		3'd4:    pal = {24'h6D6D55, 24'hDBDB55}; // LCD, the core's old look
		3'd5:    pal = pal_custom;
		default: pal = {24'hFFFFFF, 24'h000000};
	endcase
end

// The display logic runs on clk_video, a quarter of CLK_VIDEO and from the
// same PLL. A flag toggling on clk_video marks each new pixel; that gives one
// ce_pix per pixel on CLK_VIDEO.

reg pix_toggle = 0;
always @(posedge clk_video)
	pix_toggle <= ~pix_toggle;

reg        pix_toggle_d = 0;
reg        ce_pix = 0;
reg        vid_hs, vid_vs, vid_hblank, vid_vblank;
reg [23:0] vid_rgb;

always @(posedge CLK_VIDEO) begin
	pix_toggle_d <= pix_toggle;
	ce_pix <= pix_toggle ^ pix_toggle_d;

	if (pix_toggle ^ pix_toggle_d) begin
		vid_hs <= ~core_hs;
		vid_vs <= ~core_vs;
		vid_hblank <= core_hblank;
		vid_vblank <= core_vblank;
		vid_rgb <= core_pixel ? pal[47:24] : pal[23:0];
	end
end

wire scandoubler = scale || forced_scandoubler;
wire vga_de;

video_mixer #(.LINE_LENGTH(640), .GAMMA(1)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.ce_pix(ce_pix),
	.scandoubler(scandoubler),
	.hq2x(scale == 1),
	.gamma_bus(gamma_bus),
	.R(vid_rgb[23:16]),
	.G(vid_rgb[15:8]),
	.B(vid_rgb[7:0]),
	.HSync(vid_hs),
	.VSync(vid_vs),
	.HBlank(vid_hblank),
	.VBlank(vid_vblank),
	.HDMI_FREEZE(HDMI_FREEZE),
	.freeze_sync(),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(vga_de)
);

// The picture is the 2:1 playfield with square pixels, as on the HP48 LCD.

wire [1:0] ar = status[122:121];

video_freak video_freak
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.VGA_VS(VGA_VS),
	.HDMI_WIDTH(HDMI_WIDTH),
	.HDMI_HEIGHT(HDMI_HEIGHT),
	.VGA_DE(VGA_DE),
	.VIDEO_ARX(VIDEO_ARX),
	.VIDEO_ARY(VIDEO_ARY),
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd2 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd1 : 12'd0),
	.CROP_SIZE(12'd0),
	.CROP_OFF(5'd0),
	.SCALE(status[6:5])
);

endmodule
