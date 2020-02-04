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

module debounce(
	input						clk,
	input		[width:1]	in,
	output	[width:1]	out);

parameter width = 1;

reg[width:1] q1 = 0, q2 = 0;

always @ (posedge clk) begin : Process
	q2 <= q1;
	q1 <= in;
end

assign out = q1 & q2;

endmodule
