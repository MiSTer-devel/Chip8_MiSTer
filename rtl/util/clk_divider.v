/* FPGA Util library
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

// A simple clock divider with asynchronous reset
module clk_divider(
	input			res,

	input			clk_in,
	output reg	clk_out = 0
);

parameter divider = 8;
localparam halfdiv = divider / 2;
localparam width = int_width(halfdiv);

reg [width - 1:0] cnt = 0;

always @ (posedge clk_in, posedge res) begin
	if (res) begin
		cnt <= 0;
		clk_out <= 0;
	end else begin
		if (cnt == halfdiv - 1) begin
			cnt <= 0;
			clk_out <= !clk_out;
		end else begin
			cnt <= cnt + 1'd1;
		end;
	end;
end


function integer int_width;
	input [31:0] value;

	for (int_width = 0; value > 0; int_width = int_width + 1) begin
		value = value >> 1;
	end

endfunction

endmodule
