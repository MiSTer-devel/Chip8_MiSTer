    //              	U D L R   A B Y X   L R Se St   UL UR DL DR
    //  0 8-way     	2 8 4 6   5 0 A B   C D E  F    1  3  7  9
    //	1 SNES          2 8 4 6   A 5 0 B   C D E  F    1  3  7  9
    //	2 CHIP-8        5 8 7 9   6 4 2 0   C D E  F    1  3  A  B
    //	3 SCHIP 3-C     E F 3 C   A 0 5 B   4 6 2  1    7  9  8  D
    //	4 SCHIP 7-8     3 6 7 8   1 4 A 0   C D E  F    -  -  -  -
    //	5 Paddle        1 4      (U=C & D=D for pad 2)


module chip8_joystick
(
	input  [31:0] joy,
	input         player,	// 0 = first pad, 1 = second pad
	input   [2:0] mode,
	output [15:0] keys
);

// 16-digit hex key per input, right-to-left:
// R L D U, A B Y X, L R Select Start, UL UR DL DR.
// "used" follows this order, "diag" gives diagonals separate keys.
reg [63:0] map;
reg [15:0] used;
reg        diag;

always @* begin
	case (mode)
		3'd1:    begin map = 64'h9731_FEDC_B05A_2846; used = 16'hFFFF; diag = 1'b1; end
		3'd2:    begin map = 64'hBA31_FEDC_0246_5879; used = 16'hFFFF; diag = 1'b1; end
		3'd3:    begin map = 64'hD897_1264_B50A_EF3C; used = 16'hFFFF; diag = 1'b1; end
		3'd4:    begin map = 64'h0000_FEDC_0A41_3678; used = 16'h0FFF; diag = 1'b0; end
		3'd5:    begin
			map  = player ? 64'h0000_0000_0000_CD00 : 64'h0000_0000_0000_1400;
			used = 16'h000C;
			diag = 1'b0;
		end
		default: begin map = 64'h9731_FEDC_BA05_2846; used = 16'hFFFF; diag = 1'b1; end
	endcase
end

wire right = joy[0];
wire left  = joy[1];
wire down  = joy[2];
wire up    = joy[3];

wire [3:0] dirs   = {up, down, left, right};
wire       is_ul  = diag && dirs == 4'b1010;
wire       is_ur  = diag && dirs == 4'b1001;
wire       is_dl  = diag && dirs == 4'b0110;
wire       is_dr  = diag && dirs == 4'b0101;
wire       is_dia = is_ul | is_ur | is_dl | is_dr;

wire [15:0] in =
{
	is_dr, is_dl, is_ur, is_ul,
	joy[11:4],
	is_dia ? 4'd0 : joy[3:0]
};

reg [15:0] k;
integer i;
always @* begin
	k = 16'd0;
	for (i = 0; i < 16; i = i + 1)
		if (in[i] && used[i]) k[map[i*4 +: 4]] = 1'b1;
end

assign keys = k;

endmodule
