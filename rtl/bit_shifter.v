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

// Bit shifter that can repeat individual bits

module bit_shifter(
	input					clk,		// pixelclock
	input	[width-1:0]	d,			// input data word
	input 				load,		// force load of word, reset counter
	input 				enable,	// enable output
	input [3:0]			mult,		// multiplier/repeater less one
	output reg			q			// output
);
	
parameter width = 16;

reg[width-1:0] fifo = 16'h8000;
reg[3:0] counter = 0;

always @ (posedge clk)
	if (load) begin
		{q, fifo} <= {d, 1'b1};
		counter <= 0;
	end else if(enable) begin
		if (counter == mult) begin
			if (fifo == 16'h8000)
				{q, fifo} <= {d, 1'b1};
			else
				{q, fifo} <= {fifo, 1'b0};
			counter <= 0;
		end else begin
			counter <= counter + 1'd1;
		end
	end

endmodule
