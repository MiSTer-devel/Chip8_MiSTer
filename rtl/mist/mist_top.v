/* FPGA Chip-8
	Copyright (C) 2013  Carsten Elton SÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¿Ãƒâ€šÃ‚Â½rensen

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

`include "../blitter.vh"


module cpu_clock(
	input	 clk_27M,
	input	 slow,
	output cpu_clk
);

wire cpu_clk_fast;
wire cpu_clk_slow;

mist_pll_cpu mist_pll_cpu_inst(
	.inclk0 (clk_27M),
	.c0     (cpu_clk_fast),
	.c1     (cpu_clk_slow)
);

assign cpu_clk = slow ? cpu_clk_slow : cpu_clk_fast;

endmodule
	

module mist_top(
	// 27 MHz clocks
	input	[1:0]		CLOCK_27,
	
	// Yellow led
	output			LED,
  
	// VGA
	output			VGA_HS,
	output			VGA_VS,
	output [5:0]	VGA_R,
	output [5:0]	VGA_G,
	output [5:0]	VGA_B,
	
  // SPI
  inout          SPI_DO,
  input          SPI_DI,
  input          SPI_SCK,
  input          SPI_SS2,		// data_io
  input          SPI_SS3,		// OSD
  input          SPI_SS4,		// unused in this core
  input          CONF_DATA0,	// SPI_SS for user_io

	// AUDIO
	output			AUDIO_L,
	output			AUDIO_R
  
);


wire [7:0] status;
wire status_monitor_wide = status[1];
wire status_cpu_slow = status[2];


// CPU clocks

wire cpu_clk;
cpu_clock cpu_clock_inst(CLOCK_27[1], status_cpu_slow, cpu_clk);


// Other clocks

wire clk_50M;
wire clk_25M;
wire clk_13_5M;
wire clk_12k;

wire disable_scandoubler;
wire clk_disp;

mist_display_clk_mux	mist_display_clk_mux_inst(
	.clkselect (disable_scandoubler),
	.inclk0x   (clk_25M),
	.inclk1x   (clk_13_5M),
	.outclk    (clk_disp)
);

mist_pll	mist_pll_inst (
	.inclk0 (CLOCK_27[0]),

	.c0 (clk_50M),
	.c1 (clk_25M),
	.c2 (clk_12k),
	.c3 (clk_13_5M)
);

reg [4:0] audio_count;
always @(posedge clk_12k)
	audio_count <= audio_count + 1'b1;

wire audio_enable;
wire audio = audio_enable && &audio_count[4:3];
assign AUDIO_R = audio;
assign AUDIO_L = audio;

// Program uploader

wire uploading;
wire upload_clk;
wire upload_en;
wire [11:0] upload_a;
wire [7:0] upload_d;

data_io DataIO(
	SPI_SCK,
	SPI_SS2,
	SPI_DI,
	
	uploading,
	upload_clk,
	upload_en,
	upload_a,
	upload_d
);


// User IO handler

wire ps2_data;
wire ps2_clk;

localparam CONF_STR = {
	"SuperChip;CH8;",
	"O1,Monitor type,4:3,16:9;",
	"O2,CPU Speed,Fast,Slow;"
};

wire [1:0] buttons;

user_io #(.STRLEN(14 + 25 + 23)) UserIO(
	.conf_str		(CONF_STR			),

	.SPI_CLK     	(SPI_SCK          ),
	.SPI_SS_IO     (CONF_DATA0       ),
	.SPI_MISO      (SPI_DO           ),   // tristate handling inside user_io
	.SPI_MOSI      (SPI_DI           ),

	.core_type(8'ha4),
	
//   .SWITCHES      (switches         ),
	.BUTTONS       (buttons          ),

	.disable_scandoubler(disable_scandoubler),
//   .JOY0          (joyA             ),
//   .JOY1          (joyB             ),

   .status        (status           ),

   .clk           (clk_12k          ),   // should be 10-16kHz for ps2 clock
   .ps2_data      (ps2_data         ),
   .ps2_clk       (ps2_clk          )
);


// Reset circuit

wire error;
wire error_posedge;
util_posedge ErrorPosedge(clk_12k, 0, error, error_posedge);

wire uploading_negedge;
util_negedge UploadingNegedge(clk_12k, 0, uploading, uploading_negedge);

wire button1_posedge;
util_posedge ButtonPosedge(clk_12k, 0, buttons[1], button1_posedge);

reg [4:0] res_count = 0;
reg res = 0;

always @(posedge clk_12k) begin
	if (res) begin
		if (res_count[4]) begin
			res <= 1'b0;
			res_count <= 0;
		end else begin
			res_count <= res_count + 1'b1;
		end;
	end else if (uploading_negedge || button1_posedge || error_posedge) begin
		res <= 1'b1;
	end;
end


// Show some activity while uploading

assign LED = !uploading;
//assign LED = buttons[1];
//assign LED = !res;


// OSD

wire [5:0] chip8_R;
wire [5:0] chip8_G;
wire [5:0] chip8_B;
wire chip8_hs;
wire chip8_vs;

wire [5:0] osd_in_R;
wire [5:0] osd_in_G;
wire [5:0] osd_in_B;
wire osd_in_hs;
wire osd_in_vs;

osd_register_in osd_in_inst(
	clk_disp,
	
	chip8_R, chip8_G, chip8_B,
	chip8_hs, chip8_vs,

	osd_in_R, osd_in_G, osd_in_B,
	osd_in_hs, osd_in_vs
);


wire osd_hs;
wire osd_vs;

assign VGA_HS = disable_scandoubler ? osd_hs & osd_vs : osd_hs;
assign VGA_VS = disable_scandoubler ? 1'b1 : osd_vs;

osd OSD(
	clk_disp,
	
	disable_scandoubler,
	
	SPI_SCK,
	SPI_SS3,
	SPI_DI,
	
	osd_in_R, osd_in_G, osd_in_B,
	osd_in_hs, osd_in_vs,

	VGA_R, VGA_G, VGA_B,
	osd_hs, osd_vs
);

// Chip-8 machine

wire [15:0] current_opcode;

chip8 chip8machine(
	res,
	
	clk_disp,
	cpu_clk,
	clk_50M,
	
	uploading,
	disable_scandoubler,
	status_monitor_wide,
	
	chip8_hs, chip8_vs,
	chip8_R[5:3], chip8_G[5:3], chip8_B[5:4],
	
	current_opcode,

	audio_enable,
	
	ps2_data, ps2_clk,
	
	uploading,
	upload_en,
	upload_clk,
	upload_a,
	upload_d,
	
	error
);


endmodule

