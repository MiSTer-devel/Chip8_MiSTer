// Gamepad -> CHIP-8 hex keypad. The result is ORed with the PC keyboard.
//
// MiSTer joystick bits, per the CONF_STR "J1,..." list in Chip8.sv (the
// names in brackets are the default SNES-style buttons from the "jn," line):
//   [0]=right [1]=left [2]=down [3]=up
//   [4]=Fire (A)  [5]=Extra (B)  [6]=Key A (Y)  [7]=Key B (X)
//   [8]=Key C (L) [9]=Key D (R)  [10]=Key E (Select) [11]=Key F (Start)
//
// No mode presses one key from two inputs. The first four modes reach all 16
// keys: 4 directions + 8 buttons + 4 diagonals, where a diagonal presses its
// own key instead of its two directions. The last two leave keys unmapped
// and a diagonal there presses both directions.
//
//                 U D L R   A B Y X   L R Se St   UL UR DL DR
//   0 8-way       2 8 4 6   5 0 A B   C D E  F    1  3  7  9
//   1 SNES        2 8 4 6   A 5 0 B   C D E  F    1  3  7  9
//   2 CHIP-8      5 8 7 9   6 4 2 0   C D E  F    1  3  A  B
//   3 SCHIP 3-C   E F 3 C   A 0 5 B   4 6 2  1    7  9  8  D
//   4 SCHIP 7-8   3 6 7 8   1 4 A 0   C D E  F    -  -  -  -
//   5 Paddle      1 4 (pad 1) or C D (pad 2), nothing else
//
//   8-way:     COSMAC-VIP_MiSTer profile 0, extended to the whole pad.
//   SNES:      8-way with fire on B and extra on Y.
//   CHIP-8:    COSMAC-VIP_MiSTer profile 1 (the 5/7/8/9 cluster with 6 and 4,
//              the commonest layout in the chip-8-database).
//   SCHIP 3-C: left 3, right C, fire A (Spacefight 2091, Alien Hunter,
//              Joust). Up E, down F with A also fits the Timendus test suite.
//   SCHIP 7-8: up 3, down 6, left 7, right 8 (Syzygy, H. Piper; left/right
//              also Car Race and Field!). A and B are H. Piper's pipe keys.
//   Paddle:    the two-player bat games: 1/4 against C/D.

module chip8_joystick
(
	input  [31:0] joy,
	input         player,	// 0 = first pad, 1 = second pad
	input   [2:0] mode,
	output [15:0] keys
);

// One key per input, as 16 hex digits. Read right to left:
//   right left down up, A B Y X, L R Select Start, UL UR DL DR
// "used" has a bit per input in the same order. "diag" gives the diagonals
// their own keys.
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

// Only the four real diagonals count; three directions at once, or two
// opposite ones, fall back to the plain directions.
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
