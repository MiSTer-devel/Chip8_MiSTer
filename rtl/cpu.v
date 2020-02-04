/* FPGA Chip-8
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

`include "blitter.vh"

// Register file

module CpuRegisters(
	input				clk,
	
	input		[3:0]	x,
	input		[3:0]	y,
	input		[3:0]	d,
	
	output	[7:0]	vx,
	output	[7:0]	vy,
	output	[7:0]	vd,
	
	input				wx,
	input		[7:0]	nx,
	
	input				wd,
	input		[7:0]	nd
);

reg [7:0]	vreg[0:15];

assign vx = vreg[x];
assign vy = vreg[y];
assign vd = vreg[d];

always @ (posedge clk) begin
	if (wx)
		vreg[x] <= nx;
	if (wd)
		vreg[d] <= nd;
end

endmodule

// CPU

module cpu(
	input						res,

	input						clk,
	input						clk_60hz_in,
	input						vsync_in,
	input						halt,

	input			[15:0]	keyMatrix,

	output reg				ram_en,
	output reg				ram_wr,
	input			[7:0]		ram_out,
	output reg	[7:0]		ram_in,
	output reg	[11:0]	ram_addr,
	
	output reg				hires = 0,
	
	output					audio_enable,
	
	output reg	[2:0]		blit_op = 0,
	output reg	[11:0]	blit_src = 0,
	output reg	[3:0]		blit_srcHeight = 0,
	output reg	[6:0] 	blit_destX = 0,
	output reg	[5:0] 	blit_destY = 0,
	output reg 				blit_enable = 0,
	input						blit_done_in,
	input						blit_collision,
	
	output reg	[15:0]	cur_instr = 16'h1337,
	
	output reg 				error = 0

);

// Bring signals into cpu clock domain

wire vsync;
util_sync_domain vsync_sync_inst(clk, vsync_in, vsync);

wire clk_60hz;
util_sync_domain clk60hz_sync_inst(clk, clk_60hz_in, clk_60hz);

wire blit_done;
util_sync_domain blit_done_inst(clk, blit_done_in, blit_done);


// Key matrix

wire [15:0] keyMatrix_edge;
edge_detect #(.width(16)) KeyMatrixEdgeDetect(clk, keyMatrix, keyMatrix_edge);
wire keyMatrix_signal = |keyMatrix_edge;

wire [3:0] keyMatrix_selected =
	keyMatrix_edge[0] ? 4'd0 :
	keyMatrix_edge[1] ? 4'd1 :
	keyMatrix_edge[2] ? 4'd2 :
	keyMatrix_edge[3] ? 4'd3 :
	keyMatrix_edge[4] ? 4'd4 :
	keyMatrix_edge[5] ? 4'd5 :
	keyMatrix_edge[6] ? 4'd6 :
	keyMatrix_edge[7] ? 4'd7 :
	keyMatrix_edge[8] ? 4'd8 :
	keyMatrix_edge[9] ? 4'd9 :
	keyMatrix_edge[10] ? 4'd10 :
	keyMatrix_edge[11] ? 4'd11 :
	keyMatrix_edge[12] ? 4'd12 :
	keyMatrix_edge[13] ? 4'd13 :
	keyMatrix_edge[14] ? 4'd14 :
	keyMatrix_edge[15] ? 4'd15 :
	4'bX;

reg [7:0]	rpl[0:7];

wire [7:0] randomNumber;

rng RandomNumberGenerator(
	.clk(clk),
	.number_o(randomNumber)
);

reg  [7:0] bcd_in;
wire [1:0] bcd_out1;
wire [3:0] bcd_out2;
wire [3:0] bcd_out3;

bcd BcdDecoder(
	.in(bcd_in),
	.out1(bcd_out1),
	.out2(bcd_out2),
	.out3(bcd_out3)
);

reg [11:0]	pc = 12'h180;
reg [11:0]	i = 0;
reg [11:0]	stack[0:15];
reg [3:0]	sp = 0;
reg [7:0]	delay_timer = 0;
reg [7:0]	sound_timer = 0;

assign audio_enable = sound_timer != 0;

reg [7:0] instr_buf;

wire [15:0] instr = {instr_buf, ram_out};

wire [3:0] fvx = instr[15:12] == 4'hB ? 4'd0 : instr[11:8];
wire [3:0] fvy = instr[7:4];
wire [7:0] fkk = instr[7:0];

wire [7:0] vx;
wire [7:0] vy;

reg x_write;
reg [7:0] x_new;

reg d_write;
wire [7:0] vd;
reg [7:0] d_new;
reg [3:0] d_reg;

reg [3:0] bytecounter;

CpuRegisters Registers(
	.clk(clk),

	.x(fvx),
	.y(fvy),
	
	.vx(vx),
	.vy(vy),
	.vd(vd),
	
	.wx(x_write),
	.nx(x_new),
	
	.wd(d_write),
	.nd(d_new),
	.d(d_reg)
);

wire[12:0] i_plus_vx = i + vx + 0;

task store_vx;
	input [7:0] v;
	begin
		x_write <= 1;
		x_new <= v;
	end
endtask

task store_vfvx;
	input [15:0] v;
	begin
		{d_new, x_new} <= v;
		d_reg <= 15;
		x_write <= 1;
		d_write <= 1;
	end
endtask

`define STATE_SETUP_R1			4'd0
`define STATE_WAIT				4'd1
`define STATE_SETUP_R2			4'd2
`define STATE_EXECUTE			4'd3
`define STATE_STORE_BCD_1		4'd4
`define STATE_STORE_BCD_2		4'd5
`define STATE_STORE_BCD_3		4'd6
`define STATE_MEM_R				4'd7
`define STATE_SETUP_MEM_W		4'd8
`define STATE_MEM_W				4'd9
`define STATE_BLIT_START		4'd10
`define STATE_BLIT_RESULT		4'd11
`define STATE_RPL_R				4'd12
`define STATE_RPL_W				4'd13

reg [3:0] state = `STATE_SETUP_R1;
reg [3:0] nstate;

wire clk_60hz_edge;
edge_detect Clk60HzEdge(clk, clk_60hz, clk_60hz_edge);

always @(posedge clk) begin
	if (res) begin
		delay_timer <= 0;
		sound_timer <= 0;
		state <= `STATE_SETUP_R1;
		nstate <= `STATE_SETUP_R1;
		x_write <= 0;
		d_write <= 0;
		sp <= 0;
		i <= 0;
		pc <= 12'h180;
		bytecounter <= 0;
		blit_enable <= 0;
		error <= 0;
	end else begin
		if (clk_60hz_edge) begin
			if (delay_timer != 0)
				delay_timer <= delay_timer - 1'd1;
			
			if (sound_timer != 0)
				sound_timer <= sound_timer - 1'd1;
		end;

		case (state)
			`STATE_SETUP_R1: begin
				ram_en <= 1;
				ram_wr <= 0;
				ram_addr <= pc;
				pc <= pc + 1'd1;
				state <= `STATE_WAIT;
				nstate <= `STATE_SETUP_R2;
				x_write <= 0;
				d_write <= 0;
			end
			`STATE_WAIT: begin
				state <= nstate;
			end
			`STATE_SETUP_R2: begin
				instr_buf <= ram_out;
				ram_addr <= pc;
				pc <= pc + 1'd1;
				state <= `STATE_WAIT;
				nstate <= `STATE_EXECUTE;
			end
			`STATE_EXECUTE: begin
				cur_instr <= instr;
				if (!halt || keyMatrix_signal) begin	// keyMatrix_signal is a hack to enable singlestepping over wait for keypress instruction
					ram_en <= 0;
					casez (instr)
						16'h00C?: if (vsync && blit_done) begin
							blit_op <= `BLIT_OP_SCROLL_DOWN;
							blit_destY <= instr[3:0];
							state <= `STATE_BLIT_START;
						end
						16'h00E0: if (vsync && blit_done) begin
							blit_op <= `BLIT_OP_CLEAR;
							state <= `STATE_BLIT_START;
						end
						16'h00EE: begin
							pc <= stack[sp - 1];
							sp <= sp - 1'd1;
							state <= `STATE_SETUP_R1;
						end
						16'h00FB: if (vsync && blit_done) begin
							blit_op <= `BLIT_OP_SCROLL_RIGHT;
							state <= `STATE_BLIT_START;
						end
						16'h00FC: if (vsync && blit_done) begin
							blit_op <= `BLIT_OP_SCROLL_LEFT;
							state <= `STATE_BLIT_START;
						end
						16'h00FD: begin
							// exit interpreter - do nothing (wait for user reset)
							error <= 1;
						end
						16'h00FE: begin
							hires <= 0;
							state <= `STATE_SETUP_R1;
						end
						16'h00FF: begin
							hires <= 1;
							state <= `STATE_SETUP_R1;
						end
						16'h1???: begin
							pc <= instr[11:0];
							state <= `STATE_SETUP_R1;
						end
						16'h2???: begin
							stack[sp] <= pc;
							sp <= sp + 1'd1;
							pc <= instr[11:0];
							state <= `STATE_SETUP_R1;
						end
						16'h3???: begin
							if (fkk == vx)
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end
						16'h4???: begin
							if (fkk != vx)
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end
						16'h5??0: begin
							if (vx == vy)
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end					
						16'h6???: begin
							store_vx(fkk);
							state <= `STATE_SETUP_R1;
						end
						16'h7???: begin
							store_vx(vx + fkk);
							state <= `STATE_SETUP_R1;
						end
						16'h8??0: begin
							store_vx(vy);
							state <= `STATE_SETUP_R1;
						end
						16'h8??1: begin
							store_vx(vx | vy);
							state <= `STATE_SETUP_R1;
						end
						16'h8??2: begin
							store_vx(vx & vy);
							state <= `STATE_SETUP_R1;
						end
						16'h8??3: begin
							store_vx(vx ^ vy);
							state <= `STATE_SETUP_R1;
						end
						16'h8??4: begin
							store_vfvx(vx + vy + 0);
							state <= `STATE_SETUP_R1;
						end
						16'h8??5: begin
							store_vfvx({1'b1,vx} - vy);
							state <= `STATE_SETUP_R1;
						end
						16'h8??6: begin
							store_vfvx({vx[0], 1'd0, vx[7:1]});
							state <= `STATE_SETUP_R1;
						end
						16'h8??7: begin
							store_vfvx({1'b1,vy} - vx);
							state <= `STATE_SETUP_R1;
						end
						16'h8??E: begin
							store_vfvx({vx, 1'd0});
							state <= `STATE_SETUP_R1;
						end
						16'h9??0: begin
							if (vx != vy)
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end
						16'hA???: begin
							i <= instr[11:0];
							state <= `STATE_SETUP_R1;
						end
						16'hB???: begin
							pc <= instr[11:0] + vx;
							state <= `STATE_SETUP_R1;
						end
						16'hC???: begin
							store_vx(randomNumber & fkk);
							state <= `STATE_SETUP_R1;
						end
						16'hD???: if(blit_done) begin
							if (instr[3:0] == 0) begin
								blit_op <= `BLIT_OP_SPRITE_16;
							end else begin
								blit_op <= `BLIT_OP_SPRITE;
								blit_srcHeight <= instr[3:0];
							end;
							blit_src <= i;
							blit_destX <= vx[6:0];
							blit_destY <= vy[5:0];
							state <= `STATE_BLIT_START;
						end
						16'hE?9E: begin
							if (keyMatrix[vx])
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end
						16'hE?A1: begin
							if (!keyMatrix[vx])
								pc <= pc + 2'd2;
							state <= `STATE_SETUP_R1;
						end
						16'hF?07: begin
							store_vx(delay_timer);
							state <= `STATE_SETUP_R1;
						end
						16'hF?0A: if (keyMatrix_signal) begin
							store_vx(keyMatrix_selected);
							state <= `STATE_SETUP_R1;
						end
						16'hF?15: begin
							delay_timer <= vx;
							state <= `STATE_SETUP_R1;
						end
						16'hF?18: begin
							sound_timer <= vx;
							state <= `STATE_SETUP_R1;
						end
						16'hF?1E: begin
							i <= i_plus_vx[11:0];
							d_write <= 1;
							d_reg <= 15;
							d_new <= i_plus_vx[12];
							state <= `STATE_SETUP_R1;
						end
						16'hF?29: begin
							i <= {2'b10, vx[3:0], 3'b000};
							state <= `STATE_SETUP_R1;
						end
						16'hF?30: begin
							i <= {vx[3:0], 4'b0000};
							state <= `STATE_SETUP_R1;
						end
						16'hF?33: begin
							bcd_in <= vx;
							state <= `STATE_STORE_BCD_1;
						end
						16'hF?55: begin
							d_reg <= 0;
							state <= `STATE_SETUP_MEM_W;
						end
						16'hF?65: begin
							bytecounter <= 0;
							ram_en <= 1'd1;
							ram_wr <= 1'd0;
							ram_addr <= i;
							state <= `STATE_WAIT;
							nstate <= `STATE_MEM_R;
						end
						16'hF?75: if (fvx[3] == 0) begin
							d_write <= 0;
							d_reg <= 0;
							state <= `STATE_RPL_W;
						end
						16'hF?85: if (fvx[3] == 0) begin
							bytecounter <= 0;
							state <= `STATE_RPL_R;
						end
					endcase
				end
			end
			`STATE_RPL_W: begin
				rpl[d_reg] <= vd;
				
				if (fvx == d_reg)
					state <= `STATE_SETUP_R1;
				else
					d_reg <= d_reg + 1'b1;
			end
			`STATE_RPL_R: begin
				d_new <= rpl[bytecounter];
				d_write <= 1;
				d_reg <= bytecounter;
				
				if (fvx == bytecounter)
					state <= `STATE_SETUP_R1;
				else
					bytecounter <= bytecounter + 1'b1;
			end
			`STATE_STORE_BCD_1: begin
				ram_en <= 1'd1;
				ram_wr <= 1'd1;
				ram_in <= bcd_out1;
				ram_addr <= i;
				state <= `STATE_STORE_BCD_2;
			end
			`STATE_STORE_BCD_2: begin
				ram_in <= bcd_out2;
				ram_addr <= ram_addr + 1'd1;
				state <= `STATE_STORE_BCD_3;
			end
			`STATE_STORE_BCD_3: begin
				ram_in <= bcd_out3;
				ram_addr <= ram_addr + 1'd1;
				state <= `STATE_SETUP_R1;
			end
			`STATE_MEM_R: begin
				d_new <= ram_out;
				d_write <= 1;
				d_reg <= bytecounter;
				if (bytecounter == fvx) begin
					ram_en <= 1'd0;
					state <= `STATE_SETUP_R1;
				end else begin
					ram_addr <= ram_addr + 1'd1;
					bytecounter <= bytecounter + 1'd1;
					state <= `STATE_WAIT;
					nstate <= `STATE_MEM_R;
				end;
			end
			`STATE_SETUP_MEM_W: begin
				ram_in <= vd;
				ram_en <= 1;
				ram_wr <= 1;
				ram_addr <= i;
				
				if (fvx == 0) begin
					state <= `STATE_SETUP_R1;
				end else begin
					d_reg <= d_reg + 1'd1;
					state <= `STATE_MEM_W;
				end;
			end
			`STATE_MEM_W: begin
				ram_addr <= ram_addr + 1'd1;
				ram_in <= vd;
				
				if (d_reg == fvx) begin
					state <= `STATE_SETUP_R1;
				end else begin
					d_reg <= d_reg + 1'd1;
				end;
			end
			`STATE_BLIT_START: begin
				blit_enable <= 1'd1;
				state <= `STATE_BLIT_RESULT;
			end
			`STATE_BLIT_RESULT: if (blit_done) begin
				blit_enable <= 1'd0;
				d_reg <= 15;
				d_write <= 1;
				d_new <= blit_collision;
				state <= `STATE_SETUP_R1;
			end
		endcase
	end
end

endmodule
