/* FPGA Util library
	Copyright (C) 2013  Carsten Elton Sorensen

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

// "BCD" encoder. Generates the hundreds, tens and ones digits
module bcd(
	input		[7:0] in,
	output	[1:0] out1,
	output	[3:0] out2,
	output	[3:0] out3
);

wire [7:0] hundreds;
assign {out1,hundreds} =
	in >= 200 ? {2'd2, 8'd200} :
	in >= 100 ? {2'd1, 8'd100} :
	{2'd0, 8'd0};

wire [6:0] h_rem = in - hundreds;

wire [6:0] tens;
assign {out2,tens} =
	h_rem >= 90 ? {4'd9, 7'd90} :
	h_rem >= 80 ? {4'd8, 7'd80} :
	h_rem >= 70 ? {4'd7, 7'd70} :
	h_rem >= 60 ? {4'd6, 7'd60} :
	h_rem >= 50 ? {4'd5, 7'd50} :
	h_rem >= 40 ? {4'd4, 7'd40} :
	h_rem >= 30 ? {4'd3, 7'd30} :
	h_rem >= 20 ? {4'd2, 7'd20} :
	h_rem >= 10 ? {4'd1, 7'd10} :
	{4'd0, 7'd0};

wire [3:0] t_rem = h_rem - tens;
assign out3 =
	t_rem >= 9 ? 4'd9 :
	t_rem >= 8 ? 4'd8 :
	t_rem >= 7 ? 4'd7 :
	t_rem >= 6 ? 4'd6 :
	t_rem >= 5 ? 4'd5 :
	t_rem >= 4 ? 4'd4 :
	t_rem >= 3 ? 4'd3 :
	t_rem >= 2 ? 4'd2 :
	t_rem >= 1 ? 4'd1 :
	4'd0;

endmodule
