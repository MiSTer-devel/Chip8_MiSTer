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

module display(
	input	clk,
	input	res,
	
	input	hires,
	input	ntsc,
	input	wide,

	input			 enable_pixel,
	input	[10:0] h_pixel,
	input [10:0] v_pixel,
	
	output [2:0] red,
	output [2:0] green,
	output [1:0] blue,
	
	input	vsync,	// positive vsync
	input hsync,
	
	output reg [8:0]	fbuf_addr,
	input		  [15:0]	fbuf_data,
	
	output	outside_playfield
);

wire[7:0] display_pixel_width = hires ? 8'd128 : 8'd64;

wire[3:0] h_pixel_mult = hires ? 4'd5 : 4'd10;
wire[3:0] v_pixel_mult_VGA = wide ? (hires ? 4'd6 : 4'd12) : h_pixel_mult;
wire[3:0] v_pixel_mult_NTSC = wide ? (hires ? 4'd3 : 4'd6) : (hires ? 4'd2 : 4'd4);
wire[3:0] v_pixel_mult = ntsc ? v_pixel_mult_NTSC : v_pixel_mult_VGA;

reg[7:0] fbuf_h_pixel = 0;
reg[3:0] fbuf_v_pixel = 0;

reg[8:0] fbuf_line_addr = 0;

wire [8:0] fbuf_line_addr_next = fbuf_line_addr + (display_pixel_width >> 4);

wire inside_playfield_VGA = wide ? (v_pixel >= 48 && v_pixel < 432) : (v_pixel >= 80 && v_pixel < 400);
wire inside_playfield_NTSC = wide ? (v_pixel >= 24 && v_pixel < 216) : (v_pixel >= 56 && v_pixel < 184);
wire inside_playfield = ntsc ? inside_playfield_NTSC : inside_playfield_VGA;
assign outside_playfield = !inside_playfield;

wire hsync_posedge;
util_posedge hsync_posedge_inst(clk, res, hsync, hsync_posedge);

always @ (posedge clk) begin : AddressGenerator
	if (res) begin
		fbuf_addr <= 0;
		fbuf_line_addr <= 0;
		fbuf_h_pixel <= 0;
		fbuf_v_pixel <= 0;
	end else if (vsync) begin
		fbuf_addr <= 0;
		fbuf_line_addr <= 0;
		fbuf_v_pixel <= v_pixel_mult - 1'b1;
		fbuf_h_pixel <= {h_pixel_mult, 4'd0} - 1'b1;
	end else if (inside_playfield) begin
		if (hsync_posedge) begin
			if (fbuf_v_pixel == 0) begin
				fbuf_v_pixel <= v_pixel_mult - 1'b1;
				fbuf_line_addr <= fbuf_line_addr_next;
				fbuf_addr <= fbuf_line_addr_next;
			end else begin
				fbuf_v_pixel <= fbuf_v_pixel - 1'b1;
				fbuf_addr <= fbuf_line_addr;
			end;
			fbuf_h_pixel <= {h_pixel_mult, 4'd0} - 1'b1;
		end else if (enable_pixel) begin
			if (fbuf_h_pixel == 0) begin
				fbuf_h_pixel <= {h_pixel_mult,4'd0} - 1'b1;
			end else begin
				if (fbuf_h_pixel == 8)
					fbuf_addr <= fbuf_addr + 1'd1;
					
				fbuf_h_pixel <= fbuf_h_pixel - 1'b1;
			end;
		end;
	end;
end

wire hsync_negedge;
util_negedge hsync_negedge_inst(clk, res, hsync, hsync_negedge);

wire pixel;

bit_shifter Shifter(
	.clk    (clk),
	.enable (enable_pixel),
	.load   (hsync_negedge),
	.mult   (h_pixel_mult - 1'b1),
	
	.d (fbuf_data),
	.q (pixel)
);

wire [1:0] color =
	(enable_pixel) && (v_pixel == 0 || v_pixel == (ntsc ? 239 : 479)) ? 2'd1 :
	(inside_playfield && enable_pixel) ? {1'b1, pixel} :
	2'd0;

assign {red, green, blue} =
	color == 0 ? 8'h00 :
	color == 1 ? 8'hFF :
	color == 2 ? {3'd6, 3'd6, 2'd1} :
	{3'd3, 3'd3, 2'd1};


endmodule
