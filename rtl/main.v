/* FPGA Chip-8
	Copyright (C) 2013  Carsten Elton S�rensen

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

`include "blitter.vh"

module nexys3_top(
	input 			clk,
	input		[4:0]	btn,
	input		[7:0] sw,

	inout				PS2KeyboardData,
	inout				PS2KeyboardClk,
	
	output	[2:0]	vgaRed,
	output	[2:0]	vgaGreen,
	output	[2:1]	vgaBlue,
	output			Hsync,
	output			Vsync,
	output	[7:0]	seg,
	output	[3:0]	an
);

assign PS2KeyboardData = 1'bZ;
assign PS2KeyboardClk = 1'bZ;

wire	vgaClk;

wire	audio_enable;

wire	error;

// VGA clock

DCM_CLKGEN #(
	.CLKFXDV_DIVIDE(2),       // CLKFXDV divide value (2, 4, 8, 16, 32)
	.CLKFX_DIVIDE(163),       // Divide value - D - (1-256)
	.CLKFX_MD_MAX(0.0),       // Specify maximum M/D ratio for timing anlysis
	.CLKFX_MULTIPLY(41),      // Multiply value - M - (2-256)
	.CLKIN_PERIOD(10.0),      // Input clock period specified in nS
	.SPREAD_SPECTRUM("NONE"), // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
									  // "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2" 
	.STARTUP_WAIT("FALSE")    // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
)
VGAClock (
	.CLKFX(vgaClk),         // 1-bit output: Generated clock output
	.CLKIN(clk),           // 1-bit input: Input clock
	.RST(1'b0)              // 1-bit input: Reset input pin
);

// CPU clock 

wire cpu_clk;

clk_divider  #(.divider(5000)) Clock_20kHz(
	1'b0,
	clk,
	cpu_clk);

wire	clk_1khz;

clk_divider  #(.divider(100000)) Clock_1kHz(
	1'b0,
	clk,
	clk_1khz);


// Hex segment

wire	[15:0]	hexdigits;

hex_segment_driver HexDriver(
	clk_1khz,
	hexdigits[15:12], 1'b1,
	hexdigits[11:8], 1'b1,
	hexdigits[7:4], 1'b1,
	hexdigits[3:0], 1'b1,
	seg, an);

// Buttons

wire	[4:0]		btn_down, btn_down_edge;

five_way_buttons Buttons(
	.clk(clk_1khz),
	.but(btn),
	.down(btn_down),
	.down_edge(btn_down_edge));

// CPU single stepping

reg run = 1'd0;
reg run_prev = 1'd0;
wire halt = !(run && !run_prev);

always @ (posedge cpu_clk) begin
	run_prev <= run;
end

always @ (posedge clk_1khz) begin
	run <= btn_down_edge[0];
end

chip8 chip8machine(
	1'b0,	//res

	vgaClk,
	cpu_clk,
	clk,
	
	halt && sw[7],
	
	1'b0, //wide
	
	Hsync, Vsync,
	vgaRed, vgaGreen, vgaBlue,
	
	hexdigits,

	audio_enable,
	
	PS2KeyboardData, PS2KeyboardClk,
	
	1'b0,
	1'b0,
	1'b0,
	12'b0, 8'b0,
	
	error
);

endmodule
