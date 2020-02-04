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

module chip8(
	input				res,
	
	input				disp_clk,	 // 13.500.000 or 25.152.000 Hz clock
	input				cpu_clk,	 // 20.000 Hz clock
	input				blit_clk, // 100.000.000 Hz clock, or as fast as it can get.
	
	input				cpu_halt,
	
	input				ntsc,
	input				vga_wide,
	
	output			vga_hsync,
	output			vga_vsync,
	output [2:0]	vga_red,
	output [2:0]	vga_green,
	output [2:1]	vga_blue,
	output			vga_de,
	
	output [15:0]	cpu_opcode,
	
	output			audio_enable,
	
//	input				ps2_data,
//	input				ps2_clk,
	input [10:0]   ps2_key,
	
	input				uploading,
	input				upload_en,
	input				upload_clk,
	input [11:0]	upload_addr,
	input [7:0]		upload_data,
	
	output			error
);

wire vga_hires; 			// whether to use the hires display
wire vga_beam_outside;	// the beam is outside the playfield

// Framebuffer RAM wires, used by VGA circuit

wire [15:0]	vga_fbuf_data;
wire [8:0]	vga_fbuf_addr;

// Framebuffer RAM wires, used by blitter

wire [15:0]	blit_fbuf_data_out, blit_fbuf_data_in;
wire [8:0]	blit_fbuf_addr;
wire			blit_fbuf_en;
wire			blit_fbuf_write;

// CPU RAM wires, used by blitter

wire [7:0]	blit_ram_data;
wire [11:0]	blit_ram_addr;

// CPU RAM wires, used by CPU

wire [7:0]	cpu_data_out, cpu_data_in;
wire [11:0]	cpu_addr;
wire			cpu_en;
wire			cpu_wr;

// Registers for blitter operations

wire [2:0]	blit_op;
wire [11:0]	blit_src_addr;
wire [3:0]	blit_src_height;
wire [6:0] 	blit_dest_x;
wire [5:0] 	blit_dest_y;
wire 			blit_enable;
wire			blit_ready;
wire			blit_collision;

// VGA framebuffer

framebuffer VGAFramebuffer(
	disp_clk,
	vga_fbuf_addr,
	vga_fbuf_data,

	blit_clk,
	blit_fbuf_en,
	blit_fbuf_write,
	blit_fbuf_addr,
	blit_fbuf_data_in,
	blit_fbuf_data_out
);

// PS/2 keyboard

wire [7:0]	keyboard_data;
wire			keyboard_ready;
reg  [15:0]	keyboard_matrix;
reg         keyboard_down_flag = 1;

//ps2in Ps2Decoder(
//	.ps2_clk  (ps2_clk),
//	.ps2_data (ps2_data),
//	.ready    (keyboard_ready),
//	.data     (keyboard_data)
//);

assign keyboard_ready = ps2_key[9];
assign keyboard_data = ps2_key[7:0];

//always @(posedge keyboard_ready)
//	if (keyboard_data == 8'hF0) begin
//		keyboard_down_flag <= 0;
//	end else begin
//		case (keyboard_data)
//			8'h16: keyboard_matrix[4'h1] = keyboard_down_flag;
//			8'h1E: keyboard_matrix[4'h2] = keyboard_down_flag;
//			8'h26: keyboard_matrix[4'h3] = keyboard_down_flag;
//			8'h25: keyboard_matrix[4'hC] = keyboard_down_flag;
//			8'h15: keyboard_matrix[4'h4] = keyboard_down_flag;
//			8'h1D: keyboard_matrix[4'h5] = keyboard_down_flag;
//			8'h24: keyboard_matrix[4'h6] = keyboard_down_flag;
//			8'h2D: keyboard_matrix[4'hD] = keyboard_down_flag;
//			8'h1C: keyboard_matrix[4'h7] = keyboard_down_flag;
//			8'h1B: keyboard_matrix[4'h8] = keyboard_down_flag;
//			8'h23: keyboard_matrix[4'h9] = keyboard_down_flag;
//			8'h2B: keyboard_matrix[4'hE] = keyboard_down_flag;
//			8'h1A: keyboard_matrix[4'hA] = keyboard_down_flag;
//			8'h22: keyboard_matrix[4'h0] = keyboard_down_flag;
//			8'h21: keyboard_matrix[4'hB] = keyboard_down_flag;
//			8'h2A: keyboard_matrix[4'hF] = keyboard_down_flag;
//		endcase
//		keyboard_down_flag <= 1;
//	end

// CPU memory

cpu_memory CpuMemory(
	.a_clk      (uploading ? upload_clk : cpu_clk),
	.a_en       (uploading ? upload_en : cpu_en),
	.a_write    (uploading ? 1'b1 : cpu_wr),
	.a_data_out (cpu_data_out),
	.a_data_in  (uploading ? upload_data : cpu_data_in),
	.a_addr     (uploading ? upload_addr : cpu_addr),
	
	.b_data (blit_ram_data),
	.b_addr (blit_ram_addr),
	.b_clk  (blit_clk)
);

vga_block Vga(
	.clk   (disp_clk),

	.ntsc  (ntsc),
	.hires (vga_hires),
	.wide  (vga_wide),
	
	.hsync (vga_hsync),
	.vsync (vga_vsync),
	.beam_outside (vga_beam_outside),
	.display_enable(vga_de),
	
	.red   (vga_red), 
	.green (vga_green),
	.blue  (vga_blue),
	
	.fbuf_addr (vga_fbuf_addr),
	.fbuf_data (vga_fbuf_data)
);


blitter Blitter(
	.clk(blit_clk),
	.hires(vga_hires),

	.operation(blit_op),
	.src(blit_src_addr),
	.srcHeight(blit_src_height),
	.destX(blit_dest_x), .destY(blit_dest_y),
	.enable(blit_enable),
	.ready(blit_ready),
	.collision(blit_collision),

	.buf_out(blit_fbuf_data_out),
	.buf_in(blit_fbuf_data_in),
	.buf_addr(blit_fbuf_addr),
	.buf_enable(blit_fbuf_en),
	.buf_write(blit_fbuf_write),
	
	.cpu_out(blit_ram_data),
	.cpu_addr(blit_ram_addr)
);

// CPU

cpu CPU(
	.res(res),
	
	.clk(cpu_clk),
	.clk_60hz_in(vga_vsync),
	.vsync_in(vga_beam_outside),
	.halt(cpu_halt || uploading),
	
	.keyMatrix(keyboard_matrix),
	
	.ram_en(cpu_en),
	.ram_wr(cpu_wr),
	.ram_out(cpu_data_out),
	.ram_in(cpu_data_in),
	.ram_addr(cpu_addr),

	.hires(vga_hires),
	
	.audio_enable(audio_enable),

	.blit_op(blit_op),
	.blit_src(blit_src_addr),
	.blit_srcHeight(blit_src_height),
	.blit_destX(blit_dest_x),
	.blit_destY(blit_dest_y),
	.blit_enable(blit_enable),
	.blit_done_in(blit_ready),
	.blit_collision(blit_collision),
	
	.cur_instr(cpu_opcode),

	.error(error)
);
	


endmodule
