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

// The Chip-8 CPU's dual port memory
module cpu_memory(
	input					a_clk,
	
	input					a_en,
	input					a_write,
	output reg [7:0]	a_data_out,
	input		  [7:0]	a_data_in,
	input		  [11:0]	a_addr,
	
	input					b_clk,
	output reg [7:0]	b_data,
	input		 [11:0]	b_addr
);

reg [7:0] ram [0:4095];

initial begin
	$readmemh("../rom/font_large.vh", ram, 0, 255);
	$readmemh("../rom/font_small.vh", ram, 256, 383);
	$readmemh("../rom/reset.vh", ram, 384);
	$readmemh("../rom/title.vh", ram, 512);
	
//	$readmemh("../games/addition.vh", ram, 512);
//	$readmemh("../games/alien.vh", ram, 512);
//	$readmemh("../games/ant.vh", ram, 512);
//	$readmemh("../games/blinky.vh", ram, 512);
//	$readmemh("../games/car.vh", ram, 512);
//	$readmemh("../games/field.vh", ram, 512);
//	$readmemh("../games/hpiper.vh", ram, 512);
//	$readmemh("../games/joust.vh", ram, 512);
//	$readmemh("../games/laser.vh", ram, 512);
//	$readmemh("../games/loopz.vh", ram, 512);
//	$readmemh("../games/pong.vh", ram, 512);
//	$readmemh("../games/fontdump.vh", ram, 512);
//	$readmemh("../games/rpltest.vh", ram, 512);
end

always @(posedge a_clk)
	if (a_en) begin
		// Write protect the lower 512 bytes (charset)
		if (a_write) begin
			if (|a_addr[11:9])
				ram[a_addr] <= a_data_in;
		end else begin
			a_data_out <= ram[a_addr];
		end
	end

always @(posedge b_clk)
	b_data <= ram[b_addr];

endmodule
