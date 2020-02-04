/* FPGA Util library
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

// Simple PS/2 input decoder
module ps2in(
	// -- PS/2 input
	input					ps2_clk,
	input					ps2_data,
	
	// -- asynchronous reset
	input					res,

	// -- data is valid when ready goes high
	output reg			ready = 0,
	output reg			error = 0,
	output reg [7:0]	data
);

`define BIT_START		0
`define BIT_DATA_LSB	1
`define BIT_DATA_MSB	8
`define BIT_PARITY	9
`define BIT_STOP		10

reg [10:0]  buffer = 0;
wire [10:0] buffer_next = {ps2_data, buffer[10:1]};
reg [3:0]   state = 0;

always @ (negedge ps2_clk or posedge res)
	if(res) begin
		state <= 0;
		ready <= 0;
		error <= 0;
	end else begin
		if (state == 10) begin
			// We have everything include stop and parity. See if everything checks out
			if (!buffer_next[`BIT_START] && buffer_next[`BIT_STOP] && ^buffer_next[`BIT_PARITY:`BIT_DATA_LSB]) begin
				ready <= 1;
			end else begin
				error <= 1;
			end
			state <= 0;
		end else begin
			if (state == 8) begin
				// We have received all the data bits, assign them to the output register
				data <= buffer_next[10:3];
			end
			ready <= 0;
			error <= 0;
			state <= state + 1'd1;
		end
		buffer <= buffer_next;
	end

endmodule
