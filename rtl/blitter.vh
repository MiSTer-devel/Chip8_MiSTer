`ifndef _blitter_vh_
`define _blitter_vh_

`define BLIT_OP_CLEAR			3'd0
`define BLIT_OP_SCROLL_LEFT	3'd1
`define BLIT_OP_SCROLL_RIGHT	3'd2

`define BLIT_OP_SCROLL_DOWN	3'd3
// Scroll down uses destY[3:0] for the number of lines to scroll

`define BLIT_OP_SPRITE			3'd4
`define BLIT_OP_SPRITE_16		3'd5

`endif
