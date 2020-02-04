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

//
// VGA signal generator
//
// |disp                              |front|sync |back |
// |----------------------------------+-----+-----+-----|
//                                    |     |     |     |
//                                    |     |     |     +- end (total - 1)
//                                    |     |     +------- sync end
//                                    |     +------------- sync start
//                                    +------------------- disp
//

module vga_sync(
	input clk,
	input res,

	// VGA configuration
	input [10:0] h_disp,
	input [10:0] h_sync_start,
	input [10:0] h_sync_end,
	input [10:0] h_end,
		
	input [10:0] v_disp,
	input [10:0] v_sync_start,
	input [10:0] v_sync_end,
	input [10:0] v_end,

	// Output
	output reg h_sync,
	output reg v_sync,
		
	// Beam/pixel positions
	output reg [10:0] h_pos,
	output reg [10:0] v_pos,
	output reg	  pixel_enable
);

reg [10:0] h_pos_next;
reg [10:0] v_pos_next;

always @*
	if (res) begin
		h_pos_next = 0;
		v_pos_next = 0;
	end else begin
		h_pos_next = h_pos + 1'd1;
		v_pos_next = v_pos;
		if (h_pos == h_end) begin
			h_pos_next = 0;
			v_pos_next = v_pos + 1'd1;
			if (v_pos == v_end)
				v_pos_next = 0;
		end
	end

reg h_sync_next;
reg v_sync_next;

always @*
	if (res) begin
		h_sync_next = 0;
		v_sync_next = 0;
	end else begin
		if (h_pos_next == h_sync_start)
			h_sync_next = 1'b1;
		else if (h_pos_next == h_sync_end)
			h_sync_next = 1'b0;
		else
			h_sync_next = h_sync;

		if (v_pos_next == v_sync_start)
			v_sync_next = 1'b1;
		else if (v_pos_next == v_sync_end)
			v_sync_next = 1'b0;
		else
			v_sync_next = v_sync;
	end

wire pixel_enable_next = h_pos_next < h_disp && v_pos_next < v_disp;
	
always @(posedge clk) begin
	h_sync <= h_sync_next;
	v_sync <= v_sync_next;
	h_pos <= h_pos_next;
	v_pos <= v_pos_next;

	pixel_enable <= pixel_enable_next;
end

endmodule
