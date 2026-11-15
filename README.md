# FPGA SuperChip #

This is a Verilog implementation of the SuperChip virtual machine. The implementation can execute Chip-8 and SuperChip programs. Hybrids, the Chip-8X and MegaChip extensions are not supported.

This core has been ported from MiST to MiSTer by Paul Sajna.
Original core is by Carsten Elton Sørensen.

For an introduction to Chip-8 and SuperChip, please see [the Chip-8 article on Wikipedia](https://en.wikipedia.org/wiki/CHIP-8). 

SuperChip has traditionally been implemented as a virtual machine, but this is a pure Verilog implementation of the CPU, display and blitter. The CPU runs at a user selectable speed of a whopping 2.5 kHz or 6.25 kHz. An instruction usually takes 5 cycles, some a bit longer, so that is roughly 500 or 1250 instructions per second. The blitter runs at a much faster clock rate than the CPU, 50 MHz on the MiSTer, so sprite and scroll instructions only add a couple of CPU cycles.

# Instructions #

Press F12 to bring up the OSD. From here you can select a .CH8-file to load.

The picture has the shape it had on a COSMAC VIP, the machine CHIP-8 was written for: the analog output is the VIP's own raster (one lores pixel is one CDP1861 dot, a fixed 15.7 kHz 240p frame of 262 lines, or 31 kHz with the scandoubler), and Original on HDMI is the same shape, about 1.74:1 (1703:980), matching the COSMAC VIP core. Pixels are slightly taller than wide, as on the real machine. Aspect ratio and Scale otherwise work as in other MiSTer cores.

Palette selects the two colours of the picture: White, Amber, Green, Inverted, LCD (the look of earlier releases) or Custom. A custom palette is a 16-byte MiSTer Game Boy .gbp file; its first colour is used for lit dots and its last for the background.

The menu also allows the CPU speed to be selected, at roughly 500 or 1250 instructions per second. Neither models a particular real machine. Some games are better played on the slower setting, some on the faster.

The Chip-8 machine has a hex keypad for input. This has been mapped to the PC keyboard as follows:

    Chip-8:   PS/2:
    1 2 3 C   1 2 3 4
    4 5 6 D   Q W E R
    7 8 9 E   A S D F
    A 0 B F   Z X C V

# Download #

Downloads can be found in the [releases folder](https://github.com/MiSTer-devel/Chip8_MiSTer/tree/master/releases)
