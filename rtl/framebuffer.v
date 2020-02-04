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

module framebuffer(
	input             vga_clk,
	input  [8:0]      vga_addr,
	output reg [15:0] vga_out,

	input             clk,
	input             fbuf_en,
	input             fbuf_write,
	input      [8:0]  fbuf_addr,
	input      [15:0] fbuf_in,
	output reg [15:0] fbuf_out
);

reg [15:0] ram [0:511];

always @(posedge clk) begin
	if (fbuf_en) begin
		if (fbuf_write)
			ram[fbuf_addr] <= fbuf_in;
		else
			fbuf_out <= ram[fbuf_addr];
	end
end

always @(posedge vga_clk)
	vga_out <= ram[vga_addr];

endmodule
