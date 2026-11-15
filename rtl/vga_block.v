/* FPGA Chip-8
	Copyright (C) 2013-2014  Carsten Elton Sorensen

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

module vga_block(
	input				clk,
	input				res,
	
	input				ntsc,
	input				hires,	// hires or lores mode
	input				wide,		// widescreen

	// Output
	output reg		hsync,
	output reg		vsync,
	output			beam_outside,	// high when not displaying the framebuffer
	output 			display_enable,
	
	output [2:0] 	red,
	output [2:0] 	green,
	output [1:0]	blue,
	
	// Framebuffer
	output [8:0]	fbuf_addr,
	input  [15:0]	fbuf_data,

	// 1-bit video for an external palette. The blanking frames the
	// playfield only, not the whole raster.
	output			hblank,
	output			pixel_on
);


// VGA configuration (640x480)

wire [10:0] hDisp_VGA      = 640;
wire [10:0] hSyncStart_VGA = 656;
wire [10:0] hSyncEnd_VGA   = 752;
wire [10:0] hEnd_VGA       = 800 - 1;

wire [10:0] vDisp_VGA      = 480;
wire [10:0] vSyncStart_VGA = 491;
wire [10:0] vSyncEnd_VGA   = 493;
wire [10:0] vEnd_VGA       = 524 - 1;
	
// NTSC configuration 240p: the COSMAC VIP raster. At 14.08512 MHz one
// CDP1861 dot (1.76064 MHz) is 8 clocks, a 112-dot line is 896 clocks and the
// frame is 262 lines, so a lores CHIP-8 pixel is exactly a VIP dot and the
// playfield (64 dots x 128 lines) has the VIP's shape on a CRT.

wire [10:0] hDisp_NTSC      = 768;
wire [10:0] hSyncStart_NTSC = 784;
wire [10:0] hSyncEnd_NTSC   = 848;
wire [10:0] hEnd_NTSC       = 896 - 1;

wire [10:0] vDisp_NTSC      = 480 / 2;
wire [10:0] vSyncStart_NTSC = 486 / 2;
wire [10:0] vSyncEnd_NTSC   = 496 / 2;
wire [10:0] vEnd_NTSC       = 262 - 1;


// positive sync signals from sync generator
wire hsync_syncgen;
wire vsync_syncgen;

always @(posedge clk) begin
	vsync <= !vsync_syncgen;
	hsync <= ntsc ^ hsync_syncgen;
end

// The actual pixel
wire[10:0] pixel_x, pixel_y;

// Sync generator
	
vga_sync SyncGenerator(
	.clk (clk),
	.res (res),
	
	.h_disp       (ntsc ? hDisp_NTSC      : hDisp_VGA),
	.h_sync_start (ntsc ? hSyncStart_NTSC : hSyncStart_VGA),
	.h_sync_end   (ntsc ? hSyncEnd_NTSC   : hSyncEnd_VGA),
	.h_end        (ntsc ? hEnd_NTSC       : hEnd_VGA),
	
	.v_disp       (ntsc ? vDisp_NTSC      : vDisp_VGA),
	.v_sync_start (ntsc ? vSyncStart_NTSC : vSyncStart_VGA),
	.v_sync_end   (ntsc ? vSyncEnd_NTSC   : vSyncEnd_VGA),
	.v_end        (ntsc ? vEnd_NTSC       : vEnd_VGA),
	
	.h_sync (hsync_syncgen),
	.v_sync (vsync_syncgen),
	
	.h_pos (pixel_x),
	.v_pos (pixel_y),
	
	.pixel_enable (display_enable)
);

// Display generator

wire[10:0] pf_width = ntsc ? 11'd512 : 11'd640;
wire[10:0] disp_pixel_x = ntsc ? pixel_x - (768 - 512) / 2 : pixel_x;
wire disp_display_enable = display_enable & (disp_pixel_x < pf_width);

assign hblank = !(pixel_x < (ntsc ? hDisp_NTSC : hDisp_VGA) && disp_pixel_x < pf_width);

display Display(
	.clk (clk),
	.res (res),
	
	.hires (hires),
	.ntsc  (ntsc),
	.wide  (wide),
	
	.enable_pixel (disp_display_enable),
	.h_pixel      (disp_pixel_x),
	.v_pixel      (pixel_y),
	
	.red   (red),
	.green (green),
	.blue  (blue),
	
	.vsync (vsync_syncgen),
	.hsync (hsync_syncgen),
	
	.fbuf_addr (fbuf_addr),
	.fbuf_data (fbuf_data),
	
	.outside_playfield (beam_outside),
	.lit (pixel_on)
);

endmodule
