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

module util_dff(
	input clk,
	input res,
	input d,
	output reg q
);

always @(posedge clk or posedge res)
	if(res)
		q <= 1'b0;
	else
		q <= d;

endmodule


// Synchronizes an asynchronous signal d to clk. The pulse width of d must be larger than clk
module util_sync_domain(
	input clk,
	input d,
	output reg q
);

reg delayed;

always @(posedge clk) begin
	q <= delayed;
	delayed <= d;
end
	
endmodule	


module util_delay(
	input clk,
	input res,
	input in,
	input res_in,
	output reg out
);

always @(posedge clk or posedge res)
	if(res) begin
		out <= res_in;
	end else begin
		out <= in;
	end

endmodule



module util_posedge(
	input clk,
	input res,
	input in,
	output out
);

wire in_delay;
util_delay delay(clk, res, in, in, in_delay);

assign out = in && !in_delay;

endmodule



module util_negedge(
	input clk,
	input res,
	input in,
	output out
);

wire in_delay;
util_delay delay(clk, res, in, in, in_delay);

assign out = !in && in_delay;

endmodule
