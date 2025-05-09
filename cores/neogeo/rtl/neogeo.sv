//============================================================================
//  SNK NeoGeo for MiSTer
//
//  Copyright (C) 2018 Sean 'Furrtek' Gonsalves
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

// Current status:
// Neo CD CD check ok but crashes when loading. No more video glitches.

// How about not using a cache at all and DMAing directly from the data fed by the HPS ?
// The "sector ready" IRQ could be triggered just when a sector is requested, and the actual transfer
// could be done when the system ROM starts up the DMA transfer ?

// Neo CD times 12/05/2019:
// SECTOR_READY goes high at SECTOR_TIMER == 430631
// So it takes 600000-430631=169369 ticks to get a sector from HPS
// 169369/120M=1.41ms (1451 kB/s)
// DMA copy: 215 ticks for 10 bytes
// So 215/120M/10=179.17ns per byte (5450 kB/s)

// Neo CD times 11/05/2019:
// DMA copy: 616 ticks for 10 bytes
// So 215/120M/10=513.3ns per byte (1902 kB/s)

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign AUDIO_S   = 1;		// Signed
assign AUDIO_MIX = status[6:5];
assign AUDIO_L = snd_mix_l[16:1];
assign AUDIO_R = snd_mix_r[16:1];

assign LED_USER  = status[0] | bk_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = osd_btn;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

wire [1:0] ar       = status[33:32];
wire       vcrop_en = status[34];
wire [3:0] vcopt    = status[38:35];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd10 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd7  : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[40:39])
);

// status bit definition:
// 31       23       15       7
// --AA-PSS -------- L--CGGDD DEEMVTTR
//  :	status[0]		System Reset, used by the HPS, keep it there
// T:	status[2:1]		System type, 0=Console, 1=Arcade, 2=CD, 3=CDZ
// V:	status[3]		Video mode
// M:	status[4]		Memory card presence
// E:	status[6:5]		Stereo mix
// D:	status[9:7]		DIP switches
// G:	status[11:10]	Neo CD region
// C:	status[12]		Save memory card & backup RAM
// L:	status[12]		CD lid state (DEBUG)
//  :	status[14]		Manual Reset
//  :	status[20:15]  OSD options
// 0123456789 ABCDEFGHIJKLMNO

// Conditional modification of the CONF strings chaining according to chosen system type
// Con Arc CD CDz
// 00  01  10 11
// F   F   +  +  ~SYSTEM_CDx;
// +   +   S  S  SYSTEM_CDx;
// O   O   +  +  ~SYSTEM_CDx;
// +   O   +  +  SYSTEM_MVS;
// +   +   O  O  SYSTEM_CDx;

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXX XXX XXXXX XXXXXXX  XXXXXXXXXXXXX            XXXXXX 

`include "build_id.v"
localparam CONF_STR = {
	"NEOGEO;;",
	"-;",
	"FS1,*,Load ROM set;",
	"S1,CUECHD,Load CD Image;",
	"-;",
	"H3OP,FM,ON,OFF;",
	"H3OQ,ADPCMA,ON,OFF;",
	"H3OR,ADPCMB,ON,OFF;",
	"H3OS,PSG,ON,OFF;",
	"H3oP,ADPCMA CH 1,ON,OFF;",
	"H3oQ,ADPCMA CH 2,ON,OFF;",
	"H3oR,ADPCMA CH 3,ON,OFF;",
	"H3oS,ADPCMA CH 4,ON,OFF;",
	"H3oT,ADPCMA CH 5,ON,OFF;",
	"H3oU,ADPCMA CH 6,ON,OFF;",
	"H3-;",
	"O1,System Type,Console(AES),Arcade(MVS);",
	"OM,BIOS,UniBIOS,Original;",
	"O3,Video Mode,NTSC,PAL;",
	"-;",
	"o9A,Input,Joystick or Spinner,Joystick,Spinner,Mouse(Irr.Maze);",
	"oBC,Multitap,No,NEO-FTC1B,NeoTris;",
	"-;",
	"H0O4,Memory Card,Plugged,Unplugged;",
	"RL,Reload Memory Card;",
	"D4RC,Save Memory Card;",
	"OO,Autosave,OFF,ON;",
	"-;",
	"O2,CD Type,CD,CDZ;",
	"OTU,CD Speed,1x,2x,3x,4x;",
	"OAB,CD Region,US,EU,JP,AS;",
	"OF,CD lid,Closed,Opened;",
	"H2-;",
	"H2O7,[DIP] Settings,OFF,ON;",
	"H2O8,[DIP] Freeplay,OFF,ON;",
	"H2O9,[DIP] Freeze,OFF,ON;",
	"-;",
	"P1,Audio & Video;",
	"P1-;",
	"P1OG,Width,320px,304px;",
	"P1o01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OIK,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"d5P1o2,Vertical Crop,Disabled,216p(5x);",
	"d5P1o36,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1o78,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O56,Stereo Mix,none,25%,50%,100%;",
	"P1-;",
	"-;",
	"RE,Reset & apply;",  // decouple manual reset from system reset 
	"J1,A,B,C,D,Start,Select,Coin,ABC;",	// ABC is a special key to press A+B+C at once, useful for keyboards that don't allow more than 2 keypresses at once
	"jn,A,B,X,Y,Start,Select,L,R;",	        // name mapping 
	"jp,B,A,D,C,Start,Select,L,R;",	        // positional mapping consistent with NeoGeoCD controller
	"V,v",`BUILD_DATE						// 
};


////////////////////   CLOCKS   ///////////////////

wire locked;
wire CLK_48M, CLK_96M;
assign CLK_VIDEO = CLK_48M;
wire clk_sys = CLK_48M;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(CLK_96M),
	.outclk_1(CLK_48M),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(locked)
);

reg CLK_EN_24M_N, CLK_EN_24M_P;
always @(posedge CLK_48M) begin
	CLK_EN_24M_N <= ~CLK_EN_24M_N;
	CLK_EN_24M_P <= CLK_EN_24M_N;
end

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg sys_mvs = 0, sys_mvs2 = 0;
	reg [2:0] state = 0;
	reg sys_mvs_r;

	sys_mvs  <= SYSTEM_MVS;
	sys_mvs2 <= sys_mvs;

	cfg_write <= 0;
	if(sys_mvs2 == sys_mvs && sys_mvs2 != sys_mvs_r) begin
		state <= 1;
		sys_mvs_r <= sys_mvs2;
	end

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= sys_mvs_r ? 2576980378 : 2865308404;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

// The watchdog should output nRESET but it makes video sync stop for a moment, so the
// MiSTer OSD jumps around. Provide an indication for devs that a watchdog reset happened ?

reg [14:0] TRASH_ADDR;
reg SYSTEM_TYPE, SYSTEM_CD_TYPE;

reg nRESET;
always @(posedge CLK_48M) begin
	reg rst_n;

	nRESET <= rst_n;
	rst_n <= &TRASH_ADDR;
	if(CLK_EN_24M_N && ~&TRASH_ADDR) TRASH_ADDR <= TRASH_ADDR + 1'b1;

	if (status[0] | status[14] | buttons[1] | bk_loading | RESET) begin
		TRASH_ADDR <= 0;
		SYSTEM_TYPE <= status[1];	// Latch the system type on reset
		SYSTEM_CD_TYPE <= status[2];
	end
end

reg osd_btn = 0;
always @(posedge CLK_48M) begin
	integer timeout = 0;
	reg     last_rst = 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 48000000) begin
			timeout <= timeout + 1;
			osd_btn <= 1;
		end
	end
end

//////////////////   HPS I/O   ///////////////////

// VD 0: Save file
wire  [1:0] img_mounted;
wire        sd_buff_wr, img_readonly;
wire  [7:0] sd_buff_addr;	// Address inside 256-word sector
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din[2];
wire [15:0] sd_req_type;
wire [63:0] img_size;
wire [31:0] sd_lba[2];
wire  [1:0] sd_wr;
wire  [1:0] sd_rd;
wire  [1:0] sd_ack;

wire [15:0] joystick_0;	// ----HNLS DCBAUDLR
wire [15:0] joystick_1;
wire [15:0] joystick_2;
wire [15:0] joystick_3;
wire  [8:0] spinner_0, spinner_1;
wire  [1:0] buttons;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;
wire        forced_scandoubler;
wire [63:0] status;

wire [64:0] rtc;

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_idx;

wire SYSTEM_MVS = SYSTEM_TYPE & ~cd_en;
wire SYSTEM_CDx = cd_en;
wire SYSTEM_CDZ = SYSTEM_CDx & SYSTEM_CD_TYPE;

wire [15:0] sdram_sz;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0), .joystick_1(joystick_1),
	.joystick_2(joystick_2), .joystick_3(joystick_3),
	.spinner_0(spinner_0), .spinner_1(spinner_1),
	.ps2_mouse(ps2_mouse),
	.buttons(buttons),
	.ps2_key(ps2_key),

	.status(status),				// status read (32 bits)
	.status_menumask({status[22], 9'd0, en216p, bk_autosave | ~bk_pending, ~dbg_menu,~SYSTEM_MVS,1'b0,SYSTEM_CDx}),

	.RTC(rtc),
	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

	// Loading signals
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_idx),
	.ioctl_wait((ddr_loading & ddram_wait) | memcp_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.EXT_BUS(EXT_BUS)
);

reg [7:0] ioctl_index;
always @(posedge clk_sys) ioctl_index <= ioctl_idx;

reg dbg_menu = 0;
always @(posedge clk_sys) begin
	reg old_stb;
	reg enter = 0;
	reg esc = 0;
	
	old_stb <= ps2_key[10];
	if(old_stb ^ ps2_key[10]) begin
		if(ps2_key[7:0] == 'h5A) enter <= ps2_key[9];
		if(ps2_key[7:0] == 'h76) esc   <= ps2_key[9];
	end
	
	if(enter & esc) begin
		dbg_menu <= ~dbg_menu;
		enter <= 0;
		esc <= 0;
	end
end

//////////////////   Her Majesty   ///////////////////

reg  [31:0] cfg = 0;
wire [15:0] snd_right;
wire [15:0] snd_left;

wire nRESETP, nSYSTEM, CARD_WE, SHADOW, nVEC, nREGEN, nSRAMWEN, PALBNK;
wire CD_nRESET_Z80;

// Clocks
wire CLK_EN_12M, CLK_EN_12M_N, CLK_68KCLK, CLK_68KCLKB, CLK_EN_6MB, CLK_EN_1HB, CLK_EN_4M_P, CLK_EN_4M_N, CLK_EN_68K_P, CLK_EN_68K_N;

// 68k stuff
wire [15:0] M68K_DATA;
wire [23:1] M68K_ADDR;
wire A22Z, A23Z;
wire M68K_RW, nAS, nLDS, nUDS, nDTACK, nHALT, nBR, nBG, nBGACK;
wire [15:0] M68K_DATA_BYTE_MASK;
wire [15:0] FX68K_DATAIN;
wire [15:0] FX68K_DATAOUT;
wire IPL0, IPL1;
wire FC0, FC1, FC2;
reg [3:0] P_BANK;

// RTC stuff
wire RTC_DOUT, RTC_DIN, RTC_CLK, RTC_STROBE, RTC_TP;

// OEs and WEs
wire nSROMOEL, nSROMOEU, nSROMOE;
wire nROMOEL, nROMOEU;
wire nPORTOEL, nPORTOEU, nPORTWEL, nPORTWEU, nPORTADRS;
wire nSRAMOEL, nSRAMOEU, nSRAMWEL, nSRAMWEU;
wire nWRL, nWRU, nWWL, nWWU;
wire nLSPOE, nLSPWE;
wire nPAL, nPAL_WE;
wire nBITW0, nBITW1, nBITWD0, nDIPRD0, nDIPRD1;
wire nSDROE, nSDPOE;

// RAM outputs
wire [7:0] WRAML_OUT;
wire [7:0] WRAMU_OUT;
wire [15:0] SRAM_OUT;
wire [7:0] CD_Z80_RAM_OUT;

wire [14:0] WRAM_ADDR;
wire [7:0] WRAML_DATA, WRAMU_DATA;
wire WRAML_WREN, WRAMU_WREN;

// Memory card stuff
wire [23:0] CDA;
wire [2:0] BNK;
wire [7:0] CDD;
wire nCD1, nCD2;
wire nCRDO, nCRDW, nCRDC;
wire nCARDWEN, CARDWENB;

// Z80 stuff
wire [7:0] SDD_IN, SDD_OUT, Z80_SDD_OUT;
wire [7:0] SDD_RD_C1;
wire [15:0] SDA, Z80_SDA;
wire nSDRD, nSDWR, nMREQ, nIORQ, nBUSAK;
wire Z80_nSDRD, Z80_nSDWR, Z80_nMREQ;
wire Z80_nINT, Z80_nNMI, nSDW, nSDZ80R, nSDZ80W, nSDZ80CLR;
wire nSDROM, nSDMRD, nSDMWR, SDRD0, SDRD1, nZRAMCS;
wire n2610CS, n2610RD, n2610WR;

// Graphics stuff
wire [23:0] PBUS;
wire [7:0] LO_ROM_DATA;
wire nPBUS_OUT_EN;

wire [19:0] C_LATCH;
reg   [3:0] C_LATCH_EXT;
wire [63:0] CR_DOUBLE;
wire [26:0] CROM_ADDR;

wire [1:0] FIX_BANK;
wire [15:0] S_LATCH;
wire [7:0] FIXD;
wire [10:0] FIXMAP_ADDR;

wire CWE, BWE, BOE;

wire [14:0] SLOW_VRAM_ADDR;
reg [15:0] SLOW_VRAM_DATA_IN;
wire [15:0] SLOW_VRAM_DATA_OUT;

wire [10:0] FAST_VRAM_ADDR;
wire [15:0] FAST_VRAM_DATA_IN;
wire [15:0] FAST_VRAM_DATA_OUT;

wire [11:0] PAL_RAM_ADDR;
wire [15:0] PAL_RAM_DATA;
reg [15:0] PAL_RAM_REG;

wire PCK1, PCK2, EVEN1, EVEN2, LOAD, H;
wire PCK1_EN_P, PCK2_EN_P;
wire PCK1_EN_N, PCK2_EN_N;
wire DOTA, DOTB;
wire CA4, S1H1, S2H1;
wire CHBL, nBNKB, VCS;
wire CHG, LD1, LD2, SS1, SS2;
wire [3:0] GAD;
wire [3:0] GBD;
wire [3:0] WE;
wire [3:0] CK;

wire CD_VIDEO_EN, CD_FIX_EN, CD_SPR_EN;

// SDRAM multiplexing stuff
wire [15:0] SROM_DATA;
wire [15:0] PROM_DATA;

parameter INDEX_SPROM = 0;
parameter INDEX_LOROM = 1;
parameter INDEX_SFIXROM = 2;
parameter INDEX_P1ROM_A = 4;
parameter INDEX_P1ROM_B = 5;
parameter INDEX_P2ROM = 6;
parameter INDEX_S1ROM = 8;
parameter INDEX_M1ROM = 9;
parameter INDEX_MEMCP = 10;
parameter INDEX_CROM0 = 15;
parameter INDEX_VROMS = 16;
parameter INDEX_CROMS = 64;

wire video_mode = status[3];

wire       ms5p_bank  = cfg[17];
wire       xram       = cfg[18];
wire       adpcma_ext = cfg[19];
wire [2:0] cart_pchip = cfg[22:20];
wire       use_pcm    = cfg[23];
wire [1:0] cart_chip  = cfg[25:24]; // legacy option: 0 - none, 1 - PRO-CT0, 2 - Link MCU
wire [1:0] cmc_chip   = cfg[27:26]; // type 1/2
wire       rom_wait   = cfg[28];    // ROMWAIT from cart. 0 - Full speed, 1 - 1 wait cycle
wire [1:0] p_wait     = cfg[30:29]; // PWAIT from cart. 0 - Full speed, 1 - 1 wait cycle, 2 - 2 cycles
wire       cd_en      = cfg[31];    // Neo CD

// Memory card and backup ram image save/load
assign sd_rd[0]       = bk_rd;
assign sd_wr[0]       = bk_wr;
assign sd_lba[0]      = bk_lba;
assign sd_buff_din[0] = bk_dout;
wire   bk_ack         = sd_ack[0];

assign sd_rd[1]       = 0;
assign sd_wr[1]       = 0;
assign sd_buff_din[1] = 0;
assign sd_lba[1]      = 0;

wire downloading = status[0];
reg bk_rd, bk_wr;
reg bk_ena = 0;
reg bk_pending = 0;
reg [31:0] bk_lba;

wire bk_autosave = status[24];
// Memory write flag for backup memory & memory card
// (~nBWL | ~nBWU) : [AES] Unibios (set to MVS) softdip settings, [MVS] cab settings, dates, timer, high scores, saves, & bookkeeeping
// CARD_WE         : [AES/MVS] game saves and high scores
wire bk_change = sram_slot_we | CARD_WE;
wire memcard_change;

reg sram_slot_we;
always @(posedge clk_sys) begin
	sram_slot_we <= 0;
	if(~nBWL | ~nBWU) begin
		sram_slot_we <= (M68K_ADDR[15:1] >= 'h190 && M68K_ADDR[15:1] < 'h4190);
	end
end

always @(posedge clk_sys) begin
	reg old_downloading = 0;

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	// Save file always mounted in the end of downloading state.
	if(downloading && img_mounted[0] && !img_readonly) bk_ena <= 1;

	// Determine whether file needs to be written
	if (bk_change)     bk_pending <= 1;
	else if (bk_state) bk_pending <= 0;
end

wire bk_load    = status[21];
wire bk_save    = status[12] | (bk_autosave & OSD_STATUS);
reg  bk_loading = 0;
reg  bk_state   = 0;

always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_load = 0, old_save = 0, old_ack;

	old_downloading <= downloading;

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= bk_ack;

	if(~old_ack & bk_ack) {bk_rd, bk_wr} <= 0;

	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save & bk_pending))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			bk_lba <= 0;
			bk_rd  <=  bk_load;
			bk_wr  <= ~bk_load;
		end
		// always load backup so it will erase the memory if doesn't exist
		if(old_downloading & ~downloading & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			bk_lba <= 0;
			bk_rd  <= 1;
			bk_wr  <= 0;
		end
	end else begin
		if(old_ack & ~bk_ack) begin
			if (bk_lba >= 'h8F) begin // 64KB + 8KB regardless the selected system
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				bk_lba <= bk_lba + 1'd1;
				bk_rd  <=  bk_loading;
				bk_wr  <= ~bk_loading;
			end
		end
	end
end

wire [1:0] CD_REGION;
always @(status[11:10])
begin
	// CD Region code remap:
	// status[11:10] remap
	// 00            10 US
	// 01            01 EU
	// 10            11 JP
	// 11            00 ASIA
	case(status[11:10])
		 2'b00: CD_REGION = 2'b10;
		 2'b01: CD_REGION = 2'b01;
		 2'b10: CD_REGION = 2'b11;
		 2'b11: CD_REGION = 2'b00;
	endcase
end

wire [2:0] CD_TR_AREA;	// Transfer area code
wire [15:0] CD_TR_WR_DATA;
wire [19:1] CD_TR_WR_ADDR;
wire [1:0] CD_BANK_SPR;

wire CD_TR_WR_SPR, CD_TR_WR_PCM, CD_TR_WR_Z80, CD_TR_WR_FIX;
wire CD_TR_RD_SPR, CD_TR_RD_FIX, CD_TR_RD_Z80, CD_TR_RD_PCM;
wire CD_USE_SPR, CD_USE_FIX, CD_USE_Z80, CD_USE_PCM;
wire CD_UPLOAD_EN;
wire CD_BANK_PCM;
wire CD_IRQ;
wire CD_VBLANK_IRQ_EN, CD_TIMER_IRQ_EN;
wire DMA_RUNNING, DMA_WR_OUT, DMA_RD_OUT;
wire [15:0] DMA_DATA_OUT;
wire [23:0] DMA_ADDR_IN;
wire [23:0] DMA_ADDR_OUT;

wire [15:0] DMA_DATA_IN = CD_TR_RD_PCM ? { 8'h00, ADPCMA_DOUT } : PROM_DATA;

wire DMA_SDRAM_BUSY;
wire PROM_DATA_READY;

wire [15:0] CD_AUDIO_L, CD_AUDIO_R;

//CD communication
reg [48:0] cd_in;
wire [48:0] cd_out;

wire [35:0] EXT_BUS;

wire CD_DATA_WR_READY, CDDA_WR_READY;

hps_ext hps_ext
(
	.clk_sys(clk_sys),
	.EXT_BUS(EXT_BUS),

	.cd_data_ready(CD_DATA_WR_READY),
	.cdda_ready(CDDA_WR_READY),

	.cd_in(cd_in),
	.cd_out(cd_out)
);

reg [39:0] CDD_STATUS;
wire [39:0] CDD_COMMAND_DATA;
wire CDD_COMMAND_SEND;
reg CDD_STATUS_LATCH;
wire [1:0] cd_speed = status[30:29];

always @(posedge clk_sys) begin
	reg cd_out48_last = 1;
	reg cdd_send_old = 0;

	CDD_STATUS_LATCH <= 0;
	if (cd_out[48] != cd_out48_last)  begin
		cd_out48_last <= cd_out[48];
		CDD_STATUS <= cd_out[39:0];
		CDD_STATUS_LATCH <= 1;
	end

	cdd_send_old <= CDD_COMMAND_SEND;
	if (CDD_COMMAND_SEND && !cdd_send_old) begin
		cd_in[47:0] <= {6'd0,cd_speed,CDD_COMMAND_DATA};
		cd_in[48] <= ~cd_in[48];
	end else begin
		if (old_reset & ~nRESET) begin
			cd_in[47:0] <= 8'hFF;
			cd_in[48] <= ~cd_in[48];
		end
	end
end

//extend ioctl_wr for 16 cycles
reg  ioctl_wr_x;
always @(posedge clk_sys) begin
	reg [3:0] cnt = 0;

	if (ioctl_wr) begin
		cnt <= 4'd15;
		ioctl_wr_x <= 1;
	end
	else if (cnt) begin
		cnt <= cnt - 1'd1;
	end
	else begin
		ioctl_wr_x <= 0;
	end
end

localparam CD_MCLK = 48335658;

wire CDDA_CLK;
CEGen CEGEN_CDDA_CLK
(
	.CLK(CLK_48M),
	.RST_N(nRESET),
	.IN_CLK(CD_MCLK),
	.OUT_CLK(44100),
	.CE(CDDA_CLK)
);

wire CD_DATA_DOWNLOAD = ioctl_download & (ioctl_index[5:0] == 6'h02);
wire CD_DATA_WR = ioctl_wr_x & CD_DATA_DOWNLOAD;

wire CDDA_DOWNLOAD = ioctl_download & (ioctl_index[5:0] == 6'h04);
wire CDDA_WR = ioctl_wr_x & CDDA_DOWNLOAD;

cd_sys #(.MCLK(CD_MCLK)) cdsystem(
	.nRESET(nRESET),
	.clk_sys(CLK_48M), .CLK_68KCLK_EN(CLK_EN_68K_P),
	.M68K_ADDR(M68K_ADDR), .M68K_DATA(M68K_DATA), .A22Z(A22Z), .A23Z(A23Z),
	.nLDS(nLDS), .nUDS(nUDS), .M68K_RW(M68K_RW), .nAS(nAS), .nDTACK(nDTACK_ADJ),
	.nBR(nBR), .nBG(nBG), .nBGACK(nBGACK),
	.SYSTEM_CDx(SYSTEM_CDx),
	.CD_REGION(CD_REGION),
	.CD_SPEED(cd_speed),
	.CD_LID(~status[15] ^ SYSTEM_CDZ),	// CD lid state (DEBUG)
	.CD_VIDEO_EN(CD_VIDEO_EN), .CD_FIX_EN(CD_FIX_EN), .CD_SPR_EN(CD_SPR_EN),
	.CD_nRESET_Z80(CD_nRESET_Z80),
	.CD_TR_WR_SPR(CD_TR_WR_SPR), .CD_TR_WR_PCM(CD_TR_WR_PCM),
	.CD_TR_WR_Z80(CD_TR_WR_Z80), .CD_TR_WR_FIX(CD_TR_WR_FIX),
	.CD_TR_RD_FIX(CD_TR_RD_FIX), .CD_TR_RD_SPR(CD_TR_RD_SPR),
	.CD_TR_RD_Z80(CD_TR_RD_Z80), .CD_TR_RD_PCM(CD_TR_RD_PCM),
	.CD_USE_FIX(CD_USE_FIX), .CD_USE_SPR(CD_USE_SPR),
	.CD_USE_Z80(CD_USE_Z80), .CD_USE_PCM(CD_USE_PCM),
	.CD_TR_AREA(CD_TR_AREA),
	.CD_BANK_SPR(CD_BANK_SPR), .CD_BANK_PCM(CD_BANK_PCM),
	.CD_TR_WR_DATA(CD_TR_WR_DATA), .CD_TR_WR_ADDR(CD_TR_WR_ADDR),
	.CD_UPLOAD_EN(CD_UPLOAD_EN),
	.CD_IRQ(CD_IRQ), .IACK(IACK),
	.CD_VBLANK_IRQ_EN(CD_VBLANK_IRQ_EN), .CD_TIMER_IRQ_EN(CD_TIMER_IRQ_EN),
	.CDD_STATUS_IN(CDD_STATUS), .CDD_STATUS_LATCH(CDD_STATUS_LATCH),
	.CDD_COMMAND_DATA(CDD_COMMAND_DATA), .CDD_COMMAND_SEND(CDD_COMMAND_SEND),
	.CD_DATA_DOWNLOAD(CD_DATA_DOWNLOAD), .CD_DATA_WR(CD_DATA_WR),
	.CD_DATA_DIN(ioctl_dout),
	.CD_DATA_ADDR(ioctl_addr[11:1]),
	.CD_DATA_WR_READY(CD_DATA_WR_READY),
	.CDDA_RD(CDDA_CLK), .CDDA_WR(CDDA_WR),
	.CD_AUDIO_L(CD_AUDIO_L), .CD_AUDIO_R(CD_AUDIO_R),
	.CDDA_WR_READY(CDDA_WR_READY),
	.DMA_RUNNING(DMA_RUNNING),
	.DMA_DATA_IN(DMA_DATA_IN), .DMA_DATA_OUT(DMA_DATA_OUT),
	.DMA_WR_OUT(DMA_WR_OUT), .DMA_RD_OUT(DMA_RD_OUT),
	.DMA_ADDR_IN(DMA_ADDR_IN),		// Used for reading
	.DMA_ADDR_OUT(DMA_ADDR_OUT),	// Used for writing
	.DMA_SDRAM_BUSY(DMA_SDRAM_BUSY | ddram_wait | ADPCMA_RD_WAIT)
);

// The P1 zone is writable on the Neo CD
// Is there a write enable register for it ?
wire CD_EXT_WR = DMA_RUNNING ? (SYSTEM_CDx & (DMA_ADDR_OUT[23:21] == 3'd0) & DMA_WR_OUT) :               // DMA writes to $000000~$1FFFFF
										 (SYSTEM_CDx & ~|{A23Z, A22Z, M68K_ADDR[21]} & ~M68K_RW & ~(nLDS & nUDS));	// CPU writes to $000000~$1FFFFF

wire nROMOE = nROMOEL & nROMOEU;
wire nPORTOE = nPORTOEL & nPORTOEU;

// CD system work ram is in SDRAM
wire CD_EXT_RD = DMA_RUNNING ? (SYSTEM_CDx & (DMA_ADDR_IN[23:21] == 3'd0) & DMA_RD_OUT) :		// DMA reads from $000000~$1FFFFF
										 (SYSTEM_CDx & (~nWRL | ~nWRU));											// CPU reads from $100000~$1FFFFF

wire        sdram_ready;
wire [26:1] sdram_addr;
wire [15:0] sdram_dout;
wire [15:0] sdram_din;

// ioctl_download is used to load the system ROM on CD systems, we need it !
reg ioctl_en;
always_ff @(posedge clk_sys) begin
	ioctl_en <= SYSTEM_CDx ? (ioctl_index == INDEX_SPROM) :
					(ioctl_index != INDEX_LOROM && ioctl_index != INDEX_M1ROM && ioctl_index != INDEX_MEMCP && (ioctl_index < INDEX_VROMS || ioctl_index >= INDEX_CROMS));
end

wire [26:0] CROM_LOAD_ADDR = ({ioctl_addr[25:0], 1'b0} + {ioctl_index[7:1]-INDEX_CROMS[7:1], 18'h00000, ioctl_index[0], 1'b0});
wire [26:0] VROM_LOAD_ADDR = ({1'b0, ioctl_addr[25:0]} + {ioctl_index[7:0]-INDEX_VROMS[7:0], 19'h00000});

localparam SPROM_OFFSET   = 27'h0000000; // System ROM: $0000000~$007FFFF
localparam SFIXROM_OFFSET = 27'h0020000; // SFIX:       $0020000~$003FFFF (in sys ROM)
localparam S1ROM_OFFSET   = 27'h0080000; // S1:         $0080000~$00FFFFF
localparam P1ROM_A_OFFSET = 27'h0200000; // P1+:        $0200000~...
localparam P1ROM_B_OFFSET = 27'h0280000; // P1:         $0280000~$02FFFFF (secondary 512KB)
localparam P2ROM_OFFSET   = 27'h0300000; // P2+:        $0300000~...

wire [26:0] ioctl_addr_offset =
	(ioctl_index == INDEX_SPROM)   ?	{SPROM_OFFSET[26:19]  , ioctl_addr[18:0]} : // System ROM: $0000000~$007FFFF
	(ioctl_index == INDEX_SFIXROM) ? {SFIXROM_OFFSET[26:17], ioctl_addr[16:0]} : // SFIX:       $0020000~$003FFFF (in sys ROM)
	(ioctl_index == INDEX_S1ROM)   ?	{S1ROM_OFFSET[26:19]  , ioctl_addr[18:0]} : // S1:         $0080000~$00FFFFF
	(ioctl_index == INDEX_P1ROM_A) ?  P1ROM_A_OFFSET       + ioctl_addr        : // P1+:        $0200000~...
	(ioctl_index == INDEX_P1ROM_B) ? {P1ROM_B_OFFSET[26:19], ioctl_addr[18:0]} : // P1:         $0280000~$02FFFFF (secondary 512KB)
	(ioctl_index == INDEX_P2ROM)   ?  P2ROM_OFFSET         + ioctl_addr        : // P2+:        $0300000~...
	(ioctl_index == INDEX_CROM0)   ? {CROM_START, 20'd0}   + ioctl_addr        : // C:          end of P, consolidated CROM
	(ioctl_index >= INDEX_CROMS)   ? {CROM_START, 20'd0}   + CROM_LOAD_ADDR    : // C*:         end of P
	27'h0100000; // undefined case, use work RAM address to make sure no ROM gets overwritten

reg  [6:0] CROM_START;
reg [26:0] P2ROM_MASK, CROM_MASK, V1ROM_MASK, V2ROM_MASK, MROM_MASK;
always_ff @(posedge clk_sys) begin
	reg old_rst;
	reg old_download;

	old_rst <= status[0];

	if(status[0]) begin
		if (SYSTEM_CDx) begin
			CROM_MASK  <= 27'h3FFFFF; // 4MB
			V1ROM_MASK <= 27'hFFFFF;  // 1MB
			MROM_MASK  <= 27'hFFFF;   // 64KB
		end else begin
			P2ROM_MASK <= P2ROM_MASK | P2ROM_MASK[26:1];
			CROM_MASK  <= CROM_MASK  | CROM_MASK[26:1];
			V1ROM_MASK <= adpcma_ext ? 27'h1FFFFFF : (V1ROM_MASK | V1ROM_MASK[26:1]);
			V2ROM_MASK <= adpcma_ext ? 27'h0       : (V2ROM_MASK | V2ROM_MASK[26:1]);
			MROM_MASK  <= MROM_MASK  | MROM_MASK[26:1];
		end
	end

	if(ioctl_wr) begin
			  if(ioctl_index >= INDEX_CROMS)  CROM_MASK  <= CROM_MASK  | CROM_LOAD_ADDR;
		else if(ioctl_index >= INDEX_VROMS) begin
			if(~VROM_LOAD_ADDR[24]) 			 V1ROM_MASK <= V1ROM_MASK | VROM_LOAD_ADDR;
			else  									 V2ROM_MASK <= V2ROM_MASK | VROM_LOAD_ADDR;
		end
		else if(ioctl_index == INDEX_CROM0)  CROM_MASK  <= CROM_MASK  | ioctl_addr;
		else if(ioctl_index == INDEX_M1ROM)  MROM_MASK  <= MROM_MASK  | ioctl_addr;
		else if(ioctl_index == INDEX_P2ROM || ioctl_index == INDEX_P1ROM_A) begin
			if(ioctl_addr_offset >= P2ROM_OFFSET) P2ROM_MASK <= P2ROM_MASK | (ioctl_addr_offset - P2ROM_OFFSET);
		end
		
		if(ioctl_index == INDEX_MEMCP && ioctl_addr == 6 && cp_op) begin
			if(cp_idx >= INDEX_VROMS) begin
				if(cp_idx < (INDEX_VROMS+32)) V1ROM_MASK <= V1ROM_MASK | (cp_end[23:0]-1'd1);
				else  								V2ROM_MASK <= V2ROM_MASK | (cp_end[23:0]-1'd1);
			end
			else if(cp_idx == INDEX_CROM0)  CROM_MASK  <= CROM_MASK  | (cp_size-1'd1);
			else if(cp_idx == INDEX_M1ROM)  MROM_MASK  <= MROM_MASK  | (cp_size-1'd1);
			else if(cp_idx == INDEX_P2ROM || cp_idx == INDEX_P1ROM_A) begin
				if((cp_end-1'd1)>=P2ROM_OFFSET) P2ROM_MASK <= P2ROM_MASK | (cp_end - P2ROM_OFFSET - 1'd1);
			end

			if(cp_idx == INDEX_P2ROM || cp_idx == INDEX_P1ROM_A) begin
				if(CROM_START < cp_end[26:20]) CROM_START <= cp_end[26:20];
			end
		end

		if(old_download && ~ioctl_download && (ioctl_index == INDEX_P2ROM || ioctl_index == INDEX_P1ROM_A)) begin
			if(CROM_START < ioctl_addr_offset[26:20]) CROM_START <= ioctl_addr_offset[26:20];
		end
	end

	if(~old_rst & status[0]) begin
		CROM_MASK  <= 0;
		V1ROM_MASK <= 0;
		V2ROM_MASK <= 0;
		MROM_MASK  <= 0;
		P2ROM_MASK <= 0;
		CROM_START <= 3;
	end
	
	old_download <= ioctl_download;
	if(old_download && ~ioctl_download && (ioctl_index == INDEX_P2ROM || ioctl_index == INDEX_P1ROM_A)) begin
		if(CROM_START < ioctl_addr_offset[26:20]) CROM_START <= ioctl_addr_offset[26:20];
	end
end

reg [26:0] ioctl_addr_r;
reg        ioctl_wr_r;
always @(posedge clk_sys) begin
	ioctl_addr_r <= ioctl_addr_offset;
	ioctl_wr_r <= ioctl_wr;
end

reg ioctl_wr_rd, ioctl_wr_rd1;
always @(posedge CLK_96M) begin
	ioctl_wr_rd <= ioctl_wr_r;
	ioctl_wr_rd1 <= ioctl_wr_rd;
end

wire SDRAM_WR;
wire SDRAM_RD;
wire SDRAM_RFSH;
wire [1:0] SDRAM_BS;
wire sdr2_en;

sdram_mux SDRAM_MUX(
	.CLK(CLK_96M),
	.nRESET(nRESET),
	.nSYSTEM_G(nSYSTEM_G),
	.SYSTEM_CDx(SYSTEM_CDx),
	
	.M68K_ADDR(M68K_ADDR),
	.M68K_DATA(M68K_DATA),
	.nAS(nAS | (FC1 == FC0)),
	.nLDS(nLDS),
	.nUDS(nUDS),
	.nROMOE(nROMOE),
	.nPORTOE(nPORTOE),
	.nSROMOE(nSROMOE),
	.DATA_TYPE(~FC1 & FC0), // 0 - program, 1 - data, 
	.P2ROM_ADDR(P2ROM_ADDR & P2ROM_MASK),
	.PROM_DATA(PROM_DATA),
	.PROM_DATA_READY(PROM_DATA_READY),

	.CD_TR_AREA(CD_TR_AREA),
	.CD_EXT_WR(CD_EXT_WR),
	.CD_EXT_RD(CD_EXT_RD),
	.CD_USE_FIX(CD_USE_FIX),
	.CD_TR_RD_FIX(CD_TR_RD_FIX),
	.CD_TR_WR_FIX(CD_TR_WR_FIX),
	.CD_BANK_SPR(CD_BANK_SPR),
	.CD_USE_SPR(CD_USE_SPR),
	.CD_TR_RD_SPR(CD_TR_RD_SPR),
	.CD_TR_WR_SPR(CD_TR_WR_SPR),

	.DMA_ADDR_OUT(DMA_ADDR_OUT),
	.DMA_ADDR_IN(DMA_ADDR_IN),
	.DMA_DATA_OUT(DMA_DATA_OUT),
	.DMA_RUNNING(DMA_RUNNING),
	.DMA_SDRAM_BUSY(DMA_SDRAM_BUSY),

	.PCK1(PCK1),
	.SPR_EN(SPR_EN),
	.CROM_ADDR({CROM_ADDR[26:20] + (SYSTEM_CDx ? 7'd8 : CROM_START), CROM_ADDR[19:0]}),
	.CR_DOUBLE(CR_DOUBLE),

	.PCK2(PCK2),
	.S_LATCH(S_LATCH),
	.FIX_BANK(FIX_BANK),
	.FIX_EN(FIX_EN),

	.SROM_DATA(SROM_DATA),

	.DL_EN(ioctl_download & ioctl_en),
	.DL_ADDR(ioctl_addr_r),
	.DL_DATA(ioctl_dout),
	.DL_WR(~ioctl_wr_rd1 & ioctl_wr_rd),

	.REFRESH_EN(RFSH),

	.SDRAM_ADDR(sdram_addr),
	.SDRAM_DOUT(sdram_dout),
	.SDRAM_DIN(sdram_din),
	.SDRAM_WR(SDRAM_WR),
	.SDRAM_RD(SDRAM_RD),
	.SDRAM_RFSH(SDRAM_RFSH),
	.SDRAM_BS(SDRAM_BS),
	.SDRAM_READY(sdram_ready)
);

reg  [1:0] sdr_pri_128_64;
wire sdr_pri_cpsel = (~sdr_cpaddr[26] | sdr_pri_128_64[1]) & (~sdr_cpaddr[25] | sdr_pri_128_64[0]);
always @(posedge CLK_96M) if (~nRESET) sdr_pri_128_64 <= {~sdram_sz[14] & &sdram_sz[1:0], ~sdram_sz[14] & sdram_sz[1]};

wire sdram1_ready, sdram2_ready;
wire [15:0] sdram1_dout, sdram2_dout;

sdram ram1(
	.SDRAM_CLK(SDRAM_CLK),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_A(SDRAM_A),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_EN(1),

	.init(~locked),	// Init SDRAM as soon as the PLL is locked
	.clk(CLK_96M),
	.addr(sdram_addr[26:1]),
	.sel(sdr_pri_sel),
	.dout(sdram1_dout),
	.din(sdram_din),
	.bs(SDRAM_BS),
	.wr(SDRAM_WR),
	.rd(SDRAM_RD),
	.refresh(SDRAM_RFSH),
	.ready(sdram1_ready),

	.cpsel(sdr_pri_cpsel),
	.cpaddr(sdr_cpaddr[26:1]),
	.cpdin(sdr_cpdin),
	.cprd(sdr1_cprd),
	.cpreq(sdr_cpreq),
	.cpbusy(sdr1_cpbusy)
);

`ifdef MISTER_DUAL_SDRAM
sdram ram2(
	.SDRAM_CLK(SDRAM2_CLK),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nCAS(SDRAM2_nCAS),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_EN(SDRAM2_EN),

	.init(~locked),	// Init SDRAM as soon as the PLL is locked
	.clk(CLK_96M),
	.addr(sdram_addr[25:1]),
	.sel(~sdr_pri_sel),
	.dout(sdram2_dout),
	.din(sdram_din),
	.bs(SDRAM_BS),
	.wr(SDRAM_WR),
	.rd(SDRAM_RD),
	.refresh(SDRAM_RFSH),
	.ready(sdram2_ready),

	.cpsel(~sdr_pri_cpsel),
	.cpaddr(sdr_cpaddr[25:1]),
	.cpdin(sdr_cpdin),
	.cprd(sdr2_cprd),
	.cpreq(sdr_cpreq),
	.cpbusy(sdr2_cpbusy)
);

wire sdr_pri_sel = (~sdram_addr[26] | sdr_pri_128_64[1]) & (~sdram_addr[25] | sdr_pri_128_64[0]);
assign sdr2_en   = SDRAM2_EN;
`else
wire   sdr_pri_sel = 1;
assign sdram2_dout = '0;
assign sdram2_ready = 1;
assign sdr2_cprd = 0;
assign sdr2_cpbusy = 0;
assign sdr2_en = 0;
`endif

assign sdram_dout  = sdr_pri_sel ? sdram1_dout : sdram2_dout;
assign sdram_ready = sdram2_ready & sdram1_ready;

wire [2:0] P1_OUT, P2_OUT;

neo_d0 D0(
	.CLK(CLK_48M),
	.CLK_EN_24M_P(CLK_EN_24M_P),
	.CLK_EN_24M_N(CLK_EN_24M_N),
	.nRESET(nRESET), .nRESETP(nRESETP),
	.CLK_68KCLK(CLK_68KCLK), .CLK_68KCLKB(CLK_68KCLKB), .CLK_EN_12M(CLK_EN_12M), .CLK_EN_12M_N(CLK_EN_12M_N), .CLK_EN_6MB(CLK_EN_6MB), .CLK_EN_1HB(CLK_EN_1HB),
	.CLK_EN_68K_P(CLK_EN_68K_P), .CLK_EN_68K_N(CLK_EN_68K_N),
	.M68K_ADDR_A4(M68K_ADDR[4]),
	.M68K_DATA(M68K_DATA[5:0]),
	.nBITWD0(nBITWD0),
	.SDA_H(SDA[15:11]), .SDA_L(SDA[4:2]),
	.nSDRD(nSDRD),	.nSDWR(nSDWR), .nMREQ(nMREQ),	.nIORQ(nIORQ),
	.nZ80NMI(Z80_nNMI),
	.nSDW(nSDW), .nSDZ80R(nSDZ80R), .nSDZ80W(nSDZ80W),	.nSDZ80CLR(nSDZ80CLR),
	.nSDROM(nSDROM), .nSDMRD(nSDMRD), .nSDMWR(nSDMWR), .nZRAMCS(nZRAMCS),
	.SDRD0(SDRD0),	.SDRD1(SDRD1),
	.n2610CS(n2610CS), .n2610RD(n2610RD), .n2610WR(n2610WR),
	.P1_OUT(P1_OUT), .P2_OUT(P2_OUT),
	.BNK(BNK)
);

// Re-priority-encode the interrupt lines with the CD_IRQ one (IPL* are active-low)
//
//  IPL2 IPL1 IPL0    Cartridge        CD
//    1    1    1     No IRQ           No IRQ
//    1    1    0     Vblank    (64)   Vblank (68)
//    1    0    1     Timer     (68)   CD IRQ (54/58)
//    1    0    0     Cold boot (6C)   Timer  (64)
//
wire [1:0] CD_IPL = {IPL1,IPL0} == 2'b01 ? 2'b00     // Level 3 Timer
                    : CD_IRQ ? 2'b01                 // Level 2 CD IRQ
                    : {IPL1,IPL0} == 2'b10 ? 2'b10   // Level 1 VBlank
                    : 2'b11;

wire [1:0] IPL_OUT = ~SYSTEM_CDx ? { IPL1,IPL0 } : CD_IPL;

// Because of the SDRAM latency, nDTACK is handled differently for ROM zones
// If the address is in a ROM zone, PROM_DATA_READY is used to extend the normal nDTACK output by NEO-C1
wire nDTACK_ADJ = ~&{nSROMOE, nROMOE, nPORTOE, ~CD_EXT_RD, ~CD_TR_RD_FIX, ~CD_TR_RD_SPR} ? ~PROM_DATA_READY | nDTACK
                    : (CD_TR_WR_PCM) ? ~ddram_dtack | nDTACK
                    : (CD_TR_RD_PCM) ? ~ADPCMA_RD_DTACK | nDTACK
                    : nDTACK;

cpu_68k M68KCPU(
	.CLK(CLK_48M),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.CLK_EN_68K_N(CLK_EN_68K_N),
	.nRESET(nRESET_WD),
	.M68K_ADDR(M68K_ADDR),
	.FX68K_DATAIN(FX68K_DATAIN), .FX68K_DATAOUT(FX68K_DATAOUT),
	.nLDS(nLDS), .nUDS(nUDS), .nAS(nAS), .M68K_RW(M68K_RW),
	.nDTACK(nDTACK_ADJ),	// nDTACK
	.IPL2(1'b1), .IPL1(IPL_OUT[1]), .IPL0(IPL_OUT[0]),
	.FC2(FC2), .FC1(FC1), .FC0(FC0),
	.nBG(nBG), .nBR(nBR), .nBGACK(nBGACK),
	.SYSTEM_CDx(SYSTEM_CDx)
);

wire IACK = &{FC2, FC1, FC0};

// FX68K doesn't like byte masking with Z's, replace with 0's:
assign M68K_DATA_BYTE_MASK = (~|{nLDS, nUDS}) ? M68K_DATA :
										(~nLDS) ? {8'h00, M68K_DATA[7:0]} :
										(~nUDS) ? {M68K_DATA[15:8], 8'h00} :
										16'h0000;

assign M68K_DATA = M68K_RW ? 16'bzzzzzzzz_zzzzzzzz : FX68K_DATAOUT;
assign FX68K_DATAIN = M68K_RW ? M68K_DATA_BYTE_MASK : 16'h0000;

assign FIXD = CD_USE_FIX ? 8'bzzzz_zzzz : S2H1 ? SROM_DATA[15:8] : SROM_DATA[7:0];

// Disable ROM read in PORT zone if the game uses a special chip
assign M68K_DATA = (nROMOE & nSROMOE & ~CD_TR_RD_SPR & |{nPORTOE, cart_chip, cart_pchip, xram, CD_TR_RD_FIX}) ? 16'bzzzzzzzzzzzzzzzz : PROM_DATA;

// Output correct FIX byte
assign M68K_DATA[7:0] = ~CD_TR_RD_FIX ? 8'bzzzz_zzzz : (M68K_ADDR[4] ? PROM_DATA[15:8] : PROM_DATA[7:0]);

// Neo CD 68k work RAM is in SDRAM so we can use this for Z80 RAM instead.
assign WRAM_ADDR = SYSTEM_CDx ? SDA[15:1] : M68K_ADDR[15:1];
assign { WRAMU_DATA, WRAML_DATA } = SYSTEM_CDx ? { SDD_OUT, SDD_OUT } : { M68K_DATA[15:0] };
assign WRAMU_WREN = SYSTEM_CDx ? (~nSDMWR & SDA[0])  : ~nWWU;
assign WRAML_WREN = SYSTEM_CDx ? (~nSDMWR & ~SDA[0]) : ~nWWL;

// 68k/Z80 work RAM
dpram #(15) WRAML(
	.clock_a(CLK_48M),
	.address_a(WRAM_ADDR),
	.data_a(WRAML_DATA),
	.wren_a(WRAML_WREN),
	.q_a(WRAML_OUT),

	.clock_b(CLK_48M),
	.address_b(TRASH_ADDR),
	.data_b(TRASH_ADDR[7:0]),
	.wren_b(~nRESET)
);

dpram #(15) WRAMU(
	.clock_a(CLK_48M),
	.address_a(WRAM_ADDR),
	.data_a(WRAMU_DATA),
	.wren_a(WRAMU_WREN),
	.q_a(WRAMU_OUT),

	.clock_b(CLK_48M),
	.address_b(TRASH_ADDR),
	.data_b(TRASH_ADDR[7:0]),
	.wren_b(~nRESET)
);

wire [23:0] P2ROM_ADDR_PVC, P2ROM_ADDR_SMA;
wire [23:0] P2ROM_ADDR = cart_pchip ? (P2ROM_ADDR_PVC | P2ROM_ADDR_SMA) : {P_BANK, M68K_ADDR[19:1], 1'b0};

neo_pvc neo_pvc
(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),

	.ENABLE(cart_pchip == 2),

	.M68K_ADDR(M68K_ADDR),
	.M68K_DATA(M68K_DATA),
	.PROM_DATA(PROM_DATA),
	.nPORTOEL(nPORTOEL),
	.nPORTOEU(nPORTOEU),
	.nPORTWEL(nPORTWEL),
	.nPORTWEU(nPORTWEU),
	.P2_ADDR(P2ROM_ADDR_PVC)
);

neo_sma neo_sma
(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),

	.TYPE(cart_pchip),

	.M68K_ADDR(M68K_ADDR),
	.M68K_DATA(M68K_DATA),
	.PROM_DATA(PROM_DATA),
	.nPORTOEL(nPORTOEL),
	.nPORTOEU(nPORTOEU),
	.nPORTWEL(nPORTWEL),
	.nPORTWEU(nPORTWEU),
	.P2_ADDR(P2ROM_ADDR_SMA)
);

wire XRAM_CS = ~nPORTADRS && !M68K_ADDR[19:13] && xram;
wire [15:0] XRAM_OUT;
wire [15:0] xram_buff_dout;

dpram #(12) XRAML(
	.clock_a(CLK_48M),
	.address_a(M68K_ADDR[12:1]),
	.data_a(M68K_DATA[7:0]),
	.wren_a(~nPORTWEL & XRAM_CS),
	.q_a(XRAM_OUT[7:0]),

	.clock_b(clk_sys),
	.address_b(memcard_addr),
	.wren_b(memcard_wr & xram),
	.data_b(sd_buff_dout[7:0]),
	.q_b(xram_buff_dout[7:0])
);

dpram #(12) XRAMU(
	.clock_a(CLK_48M),
	.address_a(M68K_ADDR[12:1]),
	.data_a(M68K_DATA[15:8]),
	.wren_a(~nPORTWEU & XRAM_CS),
	.q_a(XRAM_OUT[15:8]),

	.clock_b(clk_sys),
	.address_b(memcard_addr),
	.wren_b(memcard_wr & xram),
	.data_b(sd_buff_dout[15:8]),
	.q_b(xram_buff_dout[15:8])
);

assign M68K_DATA[7:0]  = (XRAM_CS & ~nPORTOEL) ? XRAM_OUT[7:0]  : 8'bZ;
assign M68K_DATA[15:8] = (XRAM_CS & ~nPORTOEU) ? XRAM_OUT[15:8] : 8'bZ;

assign M68K_DATA[7:0] = (~nPORTOEL && M68K_ADDR[19] && !M68K_ADDR[18:1] && xram) ? {~joystick_0[8],1'b1,~joystick_0[9],~joystick_0[11],2'b11, ~joystick_1[10],~joystick_0[10]} : 8'bZ;

// Work RAM or CD extended RAM read
assign M68K_DATA[7:0]  = nWRL ? 8'bzzzzzzzz : SYSTEM_CDx ? PROM_DATA[7:0]  : WRAML_OUT;
assign M68K_DATA[15:8] = nWRU ? 8'bzzzzzzzz : SYSTEM_CDx ? PROM_DATA[15:8] : WRAMU_OUT;

wire save_wr    =  sd_buff_wr & bk_ack;
wire sram_wr    = ~bk_lba[7] & save_wr; // 000000~00FFFF
wire memcard_wr =  bk_lba[7] & save_wr; // 010000-011FFF
wire [14:0] sram_addr    = {bk_lba[6:0], sd_buff_addr}; //64KB
wire [11:0] memcard_addr = {bk_lba[3:0], sd_buff_addr}; //8KB

// Backup RAM
wire nBWL = nSRAMWEL | nSRAMWEN_G;
wire nBWU = nSRAMWEU | nSRAMWEN_G;

wire [15:0] sram_buff_dout;
backup BACKUP
(
	.CLK(CLK_48M),
	.M68K_ADDR(M68K_ADDR[15:1]),
	.M68K_DATA(M68K_DATA),
	.nBWL(nBWL), .nBWU(nBWU),
	.SRAM_OUT(SRAM_OUT),
	.clk_sys(clk_sys),
	.sram_addr(sram_addr),
	.sram_wr(sram_wr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din_sram(sram_buff_dout)
);

// Backup RAM is only for MVS
assign M68K_DATA[7:0] = (nSRAMOEL | ~SYSTEM_MVS) ? 8'bzzzzzzzz : SRAM_OUT[7:0];
assign M68K_DATA[15:8] = (nSRAMOEU | ~SYSTEM_MVS) ? 8'bzzzzzzzz : SRAM_OUT[15:8];

// Memory card
assign {nCD1, nCD2} = {2{status[4] & ~SYSTEM_CDx}};	// Always plugged in CD systems
assign CARD_WE = (SYSTEM_CDx | (~nCARDWEN & CARDWENB)) & ~nCRDW;

wire [15:0] memcard_buff_dout;
memcard MEMCARD(
	.CLK(CLK_48M),
	.SYSTEM_CDx(SYSTEM_CDx),
	.CDA(CDA), .CDD(CDD),
	.CARD_WE(CARD_WE),
	.M68K_DATA(M68K_DATA[7:0]),
	.clk_sys(clk_sys),
	.memcard_addr(memcard_addr),
	.memcard_wr(memcard_wr),
	.memcard_din(sd_buff_dout),
	.memcard_dout(memcard_buff_dout)
);

// Feed save file writer with backup RAM data or memory card data
wire [15:0] bk_dout = ~bk_lba[7] ? sram_buff_dout : xram ? xram_buff_dout : memcard_buff_dout;

assign CROM_ADDR = {C_LATCH_EXT, C_LATCH, 3'b000} & CROM_MASK;

zmc ZMC(
	.CLK(CLK_48M),
	.nRESET(nRESET),
	.nSDRD0(SDRD0),
	.SDA_L(SDA[1:0]), .SDA_U(SDA[15:8]),
	.MA(MA)
);

// Bankswitching for the PORT zone, do all games use a 1MB window ?
// P_BANK stays at 0 for CD systems
always @(posedge CLK_48M)
begin
	reg nPORTWEL_d;
	nPORTWEL_d <= nPORTWEL;

	if (!nRESET || SYSTEM_CDx) P_BANK <= 0;
	else if (~nPORTWEL & nPORTWEL_d) begin
		if(~ms5p_bank) P_BANK <= M68K_DATA[3:0];
		else if(&M68K_ADDR[19:4] && M68K_ADDR[3:1] == 2) P_BANK <= M68K_DATA[7:4] - 1'd1;
	end
end

// PRO-CT0 used as security chip
wire [3:0] GAD_SEC;
wire [3:0] GBD_SEC;

reg nPORTWEL_D;
always @(posedge CLK_48M) nPORTWEL_D <= nPORTWEL;

zmc2_dot ZMC2DOT(
	.CLK(CLK_48M),
	.CLK_EN_12M_N(nPORTWEL_D & ~nPORTWEL),
	.EVEN(M68K_ADDR[2]), .LOAD(M68K_ADDR[1]), .H(M68K_ADDR[3]),
	.CR({
		M68K_ADDR[19], M68K_ADDR[15], M68K_ADDR[18], M68K_ADDR[14],
		M68K_ADDR[17], M68K_ADDR[13], M68K_ADDR[16], M68K_ADDR[12],
		M68K_ADDR[11], M68K_ADDR[7], M68K_ADDR[10], M68K_ADDR[6],
		M68K_ADDR[9], M68K_ADDR[5], M68K_ADDR[8], M68K_ADDR[4],
		M68K_DATA[15], M68K_DATA[11], M68K_DATA[14], M68K_DATA[10],
		M68K_DATA[13], M68K_DATA[9], M68K_DATA[12], M68K_DATA[8],
		M68K_DATA[7], M68K_DATA[3], M68K_DATA[6], M68K_DATA[2],
		M68K_DATA[5], M68K_DATA[1], M68K_DATA[4], M68K_DATA[0]
		}),
	.GAD(GAD_SEC), .GBD(GBD_SEC)
);	

assign M68K_DATA[7:0] = ((cart_chip == 1) & ~nPORTOEL) ?
								{GBD_SEC[1], GBD_SEC[0], GBD_SEC[3], GBD_SEC[2],
								GAD_SEC[1], GAD_SEC[0], GAD_SEC[3], GAD_SEC[2]} : 8'bzzzzzzzz;

neo_273 NEO273(
	.CLK(CLK_48M),
	.PBUS(PBUS[19:0]),
	.PCK1B_EN(PCK1_EN_N), .PCK2B_EN(PCK2_EN_N),
	.C_LATCH(C_LATCH), .S_LATCH(S_LATCH)
);

// 4 MSBs not handled by NEO-273
always @(posedge CLK_48M) begin
	if (PCK1_EN_N) C_LATCH_EXT <= PBUS[23:20];
end

neo_cmc neo_cmc
(
	.CLK(CLK_48M),
	.PCK2B_EN(PCK2_EN_N),
	.PBUS(PBUS[14:0]),
	.TYPE(cmc_chip),
	.ADDR(FIXMAP_ADDR),
	.BANK(FIX_BANK)
);


// Fake COM MCU
wire [15:0] COM_DOUT;

com COM(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),
	.nPORTOEL(nPORTOEL), .nPORTOEU(nPORTOEU), .nPORTWEL(nPORTWEL),
	.M68K_DIN(COM_DOUT)
);

assign M68K_DATA = (cart_chip == 2) ? COM_DOUT : 16'bzzzzzzzz_zzzzzzzz;

syslatch SL(
	.nRESET(nRESET),
	.CLK(CLK_48M),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.M68K_ADDR(M68K_ADDR[4:1]),
	.nBITW1(nBITW1),
	.SHADOW(SHADOW), .nVEC(nVEC), .nCARDWEN(nCARDWEN),	.CARDWENB(CARDWENB), .nREGEN(nREGEN), .nSYSTEM(nSYSTEM), .nSRAMWEN(nSRAMWEN), .PALBNK(PALBNK)
);

wire nSRAMWEN_G = SYSTEM_MVS ? nSRAMWEN : 1'b1;	// nSRAMWEN is only for MVS
wire nSYSTEM_G = SYSTEM_MVS ? nSYSTEM : 1'b1;	// nSYSTEM is only for MVS

neo_e0 E0(
	.M68K_ADDR(M68K_ADDR[23:1]),
	.BNK(BNK),
	.nSROMOEU(nSROMOEU),	.nSROMOEL(nSROMOEL), .nSROMOE(nSROMOE),
	.nVEC(nVEC),
	.A23Z(A23Z), .A22Z(A22Z),
	.CDA(CDA)
);

neo_f0 F0(
	.CLK(CLK_48M),
	.nRESET(nRESET),
	.nDIPRD0(nDIPRD0), .nDIPRD1(nDIPRD1),
	.nBITW0(nBITW0), .nBITWD0(nBITWD0),
	.DIPSW({~status[9:8], 5'b11111, ~status[7]}),
	.COIN1(~joystick_0[10]), .COIN2(~joystick_1[10]),
	.M68K_ADDR(M68K_ADDR[7:4]),
	.M68K_DATA(M68K_DATA[7:0]),
	.SYSTEMB(~nSYSTEM_G),
	.RTC_DOUT(RTC_DOUT), .RTC_TP(RTC_TP), .RTC_DIN(RTC_DIN), .RTC_CLK(RTC_CLK), .RTC_STROBE(RTC_STROBE),
	.SYSTEM_TYPE(SYSTEM_MVS)
);

uPD4990 RTC(
	.rtc(rtc),
	.nRESET(nRESET),
	.CLK(CLK_48M),
	.CLK_EN_12M(CLK_EN_12M),
	.DATA_CLK(RTC_CLK), .STROBE(RTC_STROBE),
	.DATA_IN(RTC_DIN), .DATA_OUT(RTC_DOUT),
	.CS(1'b1), .OE(1'b1),
	.TP(RTC_TP)
);

neo_g0 G0(
	.M68K_DATA(M68K_DATA),
	.G0(nCRDC), .G1(nPAL), .DIR(M68K_RW), .WE(nPAL_WE),
	.CDD({8'hFF, CDD}), .PC(PAL_RAM_DATA)
);

wire [11:0] joy_0a = P1_OUT[0] ? (joystick_2[11:0] | {P1_OUT[2],5'b00000}) : (joystick_0[11:0] | {P1_OUT[2],4'b0000});
wire [11:0] joy_1a = P1_OUT[0] ? (joystick_3[11:0] | {P1_OUT[2],5'b00000}) : (joystick_1[11:0] | {P1_OUT[2],4'b0000});

wire [11:0] joy_0b = ({12{P1_OUT[0]}} & joystick_0[11:0]) | ({12{P1_OUT[1]}} & joystick_2[11:0]) | {P1_OUT[2], 9'd0};
wire [11:0] joy_1b = ({12{P2_OUT[0]}} & joystick_1[11:0]) | ({12{P2_OUT[1]}} & joystick_3[11:0]) | {P2_OUT[2], 9'd0};

wire [11:0] joy_0 = status[43] ? joy_0a : status[44] ? joy_0b : joystick_0;
wire [11:0] joy_1 = status[43] ? joy_1a : status[44] ? joy_1b : joystick_1;


neo_c1 C1(
	.CLK(CLK_48M),
	.M68K_ADDR(M68K_ADDR[21:17]),
	.M68K_DATA(M68K_DATA[15:8]), .A22Z(A22Z), .A23Z(A23Z),
	.nLDS(nLDS), .nUDS(nUDS), .RW(M68K_RW), .nAS(nAS),
	.nROMOEL(nROMOEL), .nROMOEU(nROMOEU),
	.nPORTOEL(nPORTOEL), .nPORTOEU(nPORTOEU), .nPORTWEL(nPORTWEL), .nPORTWEU(nPORTWEU),
	.nPORT_ZONE(nPORTADRS),
	.nWRL(nWRL), .nWRU(nWRU), .nWWL(nWWL), .nWWU(nWWU),
	.nSROMOEL(nSROMOEL), .nSROMOEU(nSROMOEU),
	.nSRAMOEL(nSRAMOEL), .nSRAMOEU(nSRAMOEU), .nSRAMWEL(nSRAMWEL), .nSRAMWEU(nSRAMWEU),
	.nLSPOE(nLSPOE), .nLSPWE(nLSPWE),
	.nCRDO(nCRDO), .nCRDW(nCRDW), .nCRDC(nCRDC),
	.nSDW(nSDW),
	.P1_IN(~{(joy_0[9:8]|ps2_mouse[2]), {use_mouse ? ms_pos : use_sp ? {|{joy_0[7:4],ps2_mouse[1:0]},sp0} : {joy_0[7:4]|{3{~xram & joy_0[11]}}, joy_0[0], joy_0[1], joy_0[2], joy_0[3]}}}),
	.P2_IN(~{ joy_1[9:8],               {use_mouse ? ms_btn : use_sp ? {|{joy_1[7:4]},               sp1} : {joy_1[7:4]|{3{~xram & joy_1[11]}}, joy_1[0], joy_1[1], joy_1[2], joy_1[3]}}}),
	.nCD1(nCD1), .nCD2(nCD2),
	.nWP(0),			// Memory card is never write-protected
	.nROMWAIT(~rom_wait), .nPWAIT0(~p_wait[0]), .nPWAIT1(~p_wait[1]), .PDTACK(1),
	.SDD_WR(SDD_OUT),
	.SDD_RD(SDD_RD_C1),
	.nSDZ80R(nSDZ80R), .nSDZ80W(nSDZ80W), .nSDZ80CLR(nSDZ80CLR),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.nDTACK(nDTACK),
	.nBITW0(nBITW0), .nBITW1(nBITW1),
	.nDIPRD0(nDIPRD0), .nDIPRD1(nDIPRD1),
	.nPAL_ZONE(nPAL),
	.SYSTEM_TYPE({SYSTEM_CDx, SYSTEM_MVS})
);

reg       use_sp;
reg [6:0] sp0, sp1;
always @(posedge clk_sys) begin
	reg old_sp0, old_sp1, old_ms;

	old_sp0 <= spinner_0[8];
	if(old_sp0 ^ spinner_0[8]) sp0 <= sp0 - spinner_0[6:0];
	
	old_ms <= ps2_mouse[24];
	if(old_ms ^ ps2_mouse[24]) sp0 <= sp0 - ps2_mouse[14:8];

	old_sp1 <= spinner_1[8];
	if(old_sp1 ^ spinner_1[8]) sp1 <= sp1 - spinner_1[6:0];

	if(status[42]) use_sp <= 1;
	else if(status[41]) use_sp <= 0;
	else begin
		if((old_sp0 ^ spinner_0[8]) || (old_sp1 ^ spinner_1[8]) || (old_ms ^ ps2_mouse[24])) use_sp <= 1;
		if(joystick_0[3:0] || joystick_1[3:0]) use_sp <= 0;
	end
end

wire       use_mouse = &status[42:41];

reg        ms_xy;
reg  [7:0] ms_x, ms_y;
wire [7:0] ms_pos = ms_xy ? ms_y : ms_x;
wire [7:0] ms_btn = {2'b00, ps2_mouse[1:0], 4'b0000};

always @(posedge clk_sys) begin
	reg old_ms;

	if(!nBITW0 && !M68K_ADDR[6:3]) ms_xy <= M68K_DATA[0];

	old_ms <= ps2_mouse[24];
	if(old_ms ^ ps2_mouse[24]) begin
		ms_x <= ms_x + ps2_mouse[15:8];
		ms_y <= ms_y - ps2_mouse[23:16];
	end
end

zmc2_dot ZMC2(
	.CLK(CLK_48M),
	.CLK_EN_12M_N(CLK_EN_12M_N),
	.EVEN(EVEN1), .LOAD(LOAD), .H(H),
	.CR(CA4 ? CR_DOUBLE[63:32] : CR_DOUBLE[31:0]),
	.GAD(GAD), .GBD(GBD),
	.DOTA(DOTA), .DOTB(DOTB)
);

dpram #(16) LO(
	.clock_a(clk_sys),
	.address_a(ioctl_addr[16:1]),
	.data_a(ioctl_dout[7:0]),
	.wren_a(ioctl_download & (ioctl_index == INDEX_LOROM) & ioctl_wr),
	.clock_b(CLK_48M),
	.address_b(PBUS[15:0]),
	.q_b(LO_ROM_DATA)
);

// VCS is normally used as the LO ROM's nOE but the NeoGeo relies on the fact that the LO ROM
// will still have its output active for a short moment (~50ns) after nOE goes high
// nPBUS_OUT_EN is used internally by LSPC2 but it's broken out here to use the additional
// half mclk cycle it provides compared to VCS. This makes sure LO_ROM_DATA is valid when latched.
assign PBUS[23:16] = nPBUS_OUT_EN ? LO_ROM_DATA : 8'bzzzzzzzz;

spram #(11,16) UFV(
	.clock(CLK_48M),
	.address(FAST_VRAM_ADDR),
	.data(FAST_VRAM_DATA_OUT),
	.wren(~CWE),
	.q(FAST_VRAM_DATA_IN)
);

spram #(15,16) USV(
	.clock(CLK_48M),
	.address(SLOW_VRAM_ADDR),
	.data(SLOW_VRAM_DATA_OUT),
	.wren(~BWE),
	.q(SLOW_VRAM_DATA_IN)
);

wire [18:11] MA;
wire [7:0] Z80_RAM_DATA;

// 2KB Z80 work RAM (Cart)
spram #(11) Z80RAM(.clock(CLK_48M), .address(SDA[10:0]), .data(SDD_OUT), .wren(~(nZRAMCS | nSDMWR)), .q(Z80_RAM_DATA));

// 64KB Z80 work RAM (CD)
assign CD_Z80_RAM_OUT = SDA[0] ? WRAMU_OUT : WRAML_OUT;

assign SDD_IN = (~nSDZ80R)             ? SDD_RD_C1 :
					 (~nSDMRD & SYSTEM_CDx) ? CD_Z80_RAM_OUT :
					 (~nSDMRD & ~nSDROM)    ? M1_ROM_DATA :
					 (~nSDMRD & ~nZRAMCS)   ? Z80_RAM_DATA :
					 (~n2610CS & ~n2610RD)  ? YM2610_DOUT :
					 8'b00000000;

wire Z80_nRESET = SYSTEM_CDx ? nRESET & CD_nRESET_Z80 : nRESET;
wire CD_HAS_Z80_BUS = (CD_USE_Z80 & ~(nBUSAK & CD_nRESET_Z80));

wire [7:0] M1_ROM_DATA;
reg z80rd_req;
wire z80rd_ack;
wire z80_rom_rd = ~(nSDMRD | nSDROM | SYSTEM_CDx);
always @(posedge DDRAM_CLK) begin
	reg old_rd, old_rd1;
	
	old_rd <= z80_rom_rd;
	if(old_rd == z80_rom_rd) old_rd1 <= old_rd;

	if(~old_rd1 & old_rd) z80rd_req <= ~z80rd_req;
end

wire Z80_nWAIT = (z80rd_req == z80rd_ack);

cpu_z80 Z80CPU(
	.CLK(CLK_48M),
	.CLK4P_EN(CLK_EN_4M_P),
	.CLK4N_EN(CLK_EN_4M_N),
	.nRESET(Z80_nRESET),
	.SDA(Z80_SDA), .SDD_IN(SDD_IN), .SDD_OUT(Z80_SDD_OUT),
	.nIORQ(nIORQ),	.nMREQ(Z80_nMREQ), .nRD(Z80_nSDRD), .nWR(Z80_nSDWR),
	.nBUSRQ(~CD_USE_Z80), .nBUSAK(nBUSAK),
	.nINT(Z80_nINT), .nNMI(Z80_nNMI), .nWAIT(Z80_nWAIT)
);

assign { SDA, SDD_OUT } = ~CD_HAS_Z80_BUS ? { Z80_SDA, Z80_SDD_OUT } : DMA_RUNNING ? { DMA_ADDR_OUT[16:1], DMA_DATA_OUT[7:0] } : { M68K_ADDR[16:1], M68K_DATA[7:0] };
assign { nSDRD, nSDWR } = ~CD_HAS_Z80_BUS ? { Z80_nSDRD, Z80_nSDWR } : { ~CD_TR_RD_Z80, ~CD_TR_WR_Z80 };
assign { nMREQ }        = ~CD_HAS_Z80_BUS ? { Z80_nMREQ            } : {~(CD_TR_RD_Z80 | CD_TR_WR_Z80)};

assign M68K_DATA[7:0]   = ~(CD_HAS_Z80_BUS & CD_TR_RD_Z80) ? 8'bzzzz_zzzz : SDD_IN;

wire [19:0] ADPCMA_ADDR;
wire  [4:0] ADPCMA_BANK;
wire [23:0] ADPCMB_ADDR;

reg adpcm_wr, adpcm_rd;
reg old_download, old_reset, old_CD_TR_WR_PCM;
wire adpcm_wrack, adpcm_rdack;

wire ddr_loading = ioctl_download & (((ioctl_index >= INDEX_VROMS) & (ioctl_index < INDEX_CROMS)) | (ioctl_index == INDEX_M1ROM));
reg ddram_wait = 0;
reg ddram_dtack;

// Copied from Genesis_MiSTer/Genesis.sv
always @(posedge clk_sys)
begin
	
	old_download <= ddr_loading;
	old_reset <= nRESET;
	old_CD_TR_WR_PCM <= CD_TR_WR_PCM;

	if (old_reset & ~nRESET) ddram_wait <= 0;
	
	if (old_download & ~ddr_loading)
		ddram_wait <= 0;	// Needed ?

	if (ddram_dtack & nAS) begin
		ddram_dtack <= 0;
	end

	if (ddr_loading & ioctl_wr) begin
		ddram_wait <= 1;
		adpcm_wr <= ~adpcm_wr;
		ddr_waddr <= (ioctl_index == INDEX_M1ROM) ? {1'b1,ioctl_addr[24:0]} : VROM_LOAD_ADDR;
		ddr_wr_din <= ioctl_dout;
		ddr_we_byte <= 0;
	end else if (~old_CD_TR_WR_PCM & CD_TR_WR_PCM) begin // CD write to PCM
		ddram_wait <= 1;
		adpcm_wr <= ~adpcm_wr;
		ddr_waddr <= { 6'b00_0000, CD_BANK_PCM, (DMA_RUNNING ? DMA_ADDR_OUT[19:1] : M68K_ADDR[19:1])};
		ddr_wr_din <= DMA_RUNNING ? DMA_DATA_OUT : M68K_DATA;
		ddr_we_byte <= 1;
	end else if (ddram_wait & (adpcm_wr == adpcm_wrack)) begin
		ddram_wait <= 0;
		ddram_dtack <= 1;
	end
end

assign DDRAM_CLK = CLK_96M;

// The ddram request and ack signals work on either edge
// To trigger a read request, just set adpcm_rd to ~adpcm_rdack

reg ADPCMA_READ_REQ, ADPCMB_READ_REQ;
reg ADPCMA_READ_ACK, ADPCMB_READ_ACK;
reg [24:0] ADPCMA_ADDR_LATCH;	// 16MB(32MB)
reg [24:0] ADPCMB_ADDR_LATCH;	// 32MB
reg [23:0] ADPCMB_MASK;
reg [7:0] ADPCMA_ACK_COUNTER;
reg [10:0] ADPCMB_ACK_COUNTER;
wire ADPCMA_DATA_READY = ~((ADPCMA_READ_REQ ^ ADPCMA_READ_ACK) & (ADPCMA_ACK_COUNTER == 8'd0));
wire ADPCMB_DATA_READY = ~((ADPCMB_READ_REQ ^ ADPCMB_READ_ACK) & (ADPCMB_ACK_COUNTER == 11'd0));

reg OLD_CD_TR_RD_PCM;
reg ADPCMA_RD_DTACK, ADPCMA_RD_WAIT;
always @(posedge DDRAM_CLK) begin
	reg [1:0] ADPCMA_OE_SR;
	reg [1:0] ADPCMB_OE_SR;
	ADPCMA_OE_SR <= {ADPCMA_OE_SR[0], nSDROE};
	ADPCMA_ACK_COUNTER <= ADPCMA_ACK_COUNTER == 8'd0 ? 8'd0 : ADPCMA_ACK_COUNTER - 8'd1;
	ADPCMB_ACK_COUNTER <= ADPCMB_ACK_COUNTER == 11'd0 ? 11'd0 : ADPCMB_ACK_COUNTER - 11'd1;
	// Trigger ADPCM A data read on nSDROE falling edge
	if (ADPCMA_OE_SR == 2'b10 & ~CD_USE_PCM) begin
		ADPCMA_READ_REQ <= ~ADPCMA_READ_REQ;
		ADPCMA_ADDR_LATCH <= {ADPCMA_BANK, ADPCMA_ADDR} & V1ROM_MASK[24:0];
		// Data is needed on one previous 8MHz clk before next 666KHz clock->(96MHz/666KHz = 144)-12-4=128
		ADPCMA_ACK_COUNTER <= 8'd128;
	end
	
	ADPCMB_MASK <= use_pcm ? V1ROM_MASK[23:0] : V2ROM_MASK[23:0];
	
	// Trigger ADPCM B data read on nSDPOE falling edge
	ADPCMB_OE_SR <= {ADPCMB_OE_SR[0], nSDPOE};
	if (ADPCMB_OE_SR == 2'b10 & ~SYSTEM_CDx) begin
		ADPCMB_READ_REQ <= ~ADPCMB_READ_REQ;
		ADPCMB_ADDR_LATCH <= {~use_pcm, ADPCMB_ADDR & ADPCMB_MASK};
		// Data is needed on one previous 8MHz clk before next 55KHz clock->(96MHz/55KHz = 1728)-144-4=1580
		ADPCMB_ACK_COUNTER <= 11'd1580;
	end

	// ADPCM A read by 68K
	OLD_CD_TR_RD_PCM <= CD_TR_RD_PCM;
	if (~OLD_CD_TR_RD_PCM & CD_TR_RD_PCM) begin
		ADPCMA_ADDR_LATCH <= { 4'b0000, CD_BANK_PCM, (DMA_RUNNING ? DMA_ADDR_IN[19:1] : M68K_ADDR[19:1]) };
		ADPCMA_READ_REQ <= ~ADPCMA_READ_REQ;
		ADPCMA_RD_WAIT <= 1;
	end else if (ADPCMA_RD_WAIT & (ADPCMA_READ_REQ == ADPCMA_READ_ACK)) begin
		ADPCMA_RD_WAIT <= 0;
		ADPCMA_RD_DTACK <= 1;
	end

	if (ADPCMA_RD_DTACK & nAS) begin
		ADPCMA_RD_DTACK <= 0;
	end
end

assign M68K_DATA[7:0] = ~CD_TR_RD_PCM ? 8'bzzzz_zzzz : ADPCMA_DOUT;

wire [7:0] ADPCMA_DOUT;
wire [7:0] ADPCMA_DATA = (CD_USE_PCM || !V1ROM_MASK) ? 8'h80 : ADPCMA_DOUT;

wire [7:0] ADPCMB_DOUT;
wire [7:0] ADPCMB_DATA = (!ADPCMB_MASK) ? 8'h80 : ADPCMB_DOUT;

reg [27:0] ddr_waddr;
reg [15:0] ddr_wr_din;
reg ddr_we_byte;

ddram DDRAM(
	.*,
	
	.wraddr(ddr_waddr),
	.din(ddr_wr_din),
	.we_req(adpcm_wr),
	.we_ack(adpcm_wrack),
	.we_byte(ddr_we_byte),
	
	.rdaddr(ADPCMA_ADDR_LATCH),
	.dout(ADPCMA_DOUT),
	.rd_req(ADPCMA_READ_REQ),
	.rd_ack(ADPCMA_READ_ACK),

	.rdaddr2(ADPCMB_ADDR_LATCH),
	.dout2(ADPCMB_DOUT),
	.rd_req2(ADPCMB_READ_REQ),
	.rd_ack2(ADPCMB_READ_ACK),

	.rdaddr3({7'b10_0000_0,MA & MROM_MASK[18:11],SDA[10:0]}),
	.dout3(M1_ROM_DATA),
	.rd_req3(z80rd_req),
	.rd_ack3(z80rd_ack),

	.cpaddr({1'b1, ddr_cpaddr}),
	.cpdout(ddr_cpdout),
	.cpwr(ddr_cpwr),
	.cpreq(ddr_cpreq),
	.cpbusy(ddr_cpbusy)
);

wire [26:0] ddr_cpaddr = cur_off;
wire [63:0] ddr_cpdout;
wire        ddr_cpwr;
wire        ddr_cpbusy;
reg         ddr_cpreq;
wire [26:0] sdr_cpaddr = cp_addr + cur_off;
wire [15:0] sdr_cpdin;
wire        sdr1_cprd, sdr2_cprd;
wire        sdr_cprd = sdr1_cprd | sdr2_cprd;
wire        sdr1_cpbusy, sdr2_cpbusy;
wire        sdr_cpbusy = sdr1_cpbusy | sdr2_cpbusy;
reg         sdr_cpreq;

cpram cpram
(
	.clock(CLK_96M),
	.reset(~memcp_wait),

	.wr(ddr_cpwr),
	.data(ddr_cpdout),

	.rd(sdr_cprd),
	.q(sdr_cpdin)
);

reg         cp_op;
reg   [7:0] cp_idx;
reg  [26:0] cp_size;
reg  [26:0] cp_addr;
reg  [26:0] cp_last;
reg  [26:0] cur_off;

reg  [26:0] cp_end;

wire [26:0] cp_offset =
	(cp_idx == INDEX_SPROM)   ? SPROM_OFFSET       :
	(cp_idx == INDEX_SFIXROM) ? SFIXROM_OFFSET     :
	(cp_idx == INDEX_S1ROM)   ? S1ROM_OFFSET       :
	(cp_idx == INDEX_P1ROM_A) ? P1ROM_A_OFFSET     :
	(cp_idx == INDEX_P1ROM_B) ? P1ROM_B_OFFSET     :
	(cp_idx == INDEX_P2ROM)   ? P2ROM_OFFSET       :
	(cp_idx == INDEX_CROM0)   ? {CROM_START, 20'd0}:
	(cp_idx >= INDEX_VROMS)   ? ({cp_idx[7:0]-INDEX_VROMS[7:0], 19'h00000}) :
										 27'd0;

reg memcp_req = 0;
reg memcp_ack = 0;
wire memcp_wait = (memcp_req != memcp_ack);

always @(posedge clk_sys) begin
	if(ioctl_download && ioctl_index == INDEX_MEMCP) begin
		if(ioctl_wr) begin
			case(ioctl_addr[3:0])
				0: {cp_op,cp_idx} <= {~ioctl_dout[15],ioctl_dout[7:0]};
				2: cp_size[15:0]  <= ioctl_dout;
				4: begin
						cp_size[26:16] <= ioctl_dout[10:0];
						cp_addr     <= cp_offset;
						cp_end      <= cp_offset + {ioctl_dout[10:0], cp_size[15:0]};
					end
				6: if(ioctl_dout && cp_op) memcp_req <= ~memcp_req;
			endcase

			if(~cp_op) begin
				case(ioctl_addr[3:0])
					2: cfg[15:0]  <= ioctl_dout;
					4: cfg[31:16] <= ioctl_dout;
				endcase
			end
		end
	end
end

reg [1:0] memcp_state = 0;
always @(posedge CLK_96M) begin
	case(memcp_state)
		0: if(~memcp_wait) begin
				ddr_cpreq <= 0;
				sdr_cpreq <= 0;
				cur_off   <= 0;
			end
			else if((~sdr2_en && ~sdr_pri_cpsel) || (cur_off >= cp_size)) memcp_ack <= memcp_req;
			else begin
				ddr_cpreq   <= 1;
				memcp_state <= 1;
			end

		1: if(ddr_cpbusy) ddr_cpreq <= 0;
			else if(~ddr_cpreq & ~ddr_cpbusy) begin
				sdr_cpreq   <= 1;
				memcp_state <= 2;
			end

		2: if(sdr_cpbusy) sdr_cpreq <= 0;
			else if(~sdr_cpreq & ~sdr_cpbusy) begin
				cur_off     <= cur_off + 27'd1024;
				memcp_state <= 0;
			end
	endcase

	if(~memcp_wait) memcp_state <= 0;
end

wire [7:0] YM2610_DOUT;

reg adpcm_en;
reg [7:0] adpcma_d, adpcmb_d;
always @(posedge CLK_48M) begin
	reg en;
	en <= ADPCMA_DATA_READY & ADPCMB_DATA_READY;
	adpcm_en <= en;
	
	adpcma_d <= ADPCMA_DATA;
	adpcmb_d <= ADPCMB_DATA;
end

jt10 YM2610(
	.rst(~Z80_nRESET),
	.clk(CLK_48M), .cen((CLK_EN_4M_P | CLK_EN_4M_N) & adpcm_en),
	.addr(SDA[1:0]),
	.din(SDD_OUT), .dout(YM2610_DOUT),
	.cs_n(n2610CS), .wr_n(n2610WR),
	.irq_n(Z80_nINT),
	.adpcma_addr(ADPCMA_ADDR), .adpcma_bank(ADPCMA_BANK), .adpcma_roe_n(nSDROE), .adpcma_data(adpcma_d),
	.adpcmb_addr(ADPCMB_ADDR), .adpcmb_roe_n(nSDPOE), .adpcmb_data(SYSTEM_CDx ? 8'h08 : adpcmb_d),	// CD has no ADPCM-B
	.snd_right(snd_right), .snd_left(snd_left), .snd_enable(~{4{dbg_menu}} | ~status[28:25]), .ch_enable(~status[62:57])
);

wire [16:0] snd_mix_l = $signed(snd_left) + $signed(CD_AUDIO_L);
wire [16:0] snd_mix_r = $signed(snd_right) + $signed(CD_AUDIO_R);

 
// For Neo CD only
wire VIDEO_EN = SYSTEM_CDx ? CD_VIDEO_EN : 1'b1;
wire FIX_EN = SYSTEM_CDx ? CD_FIX_EN : 1'b1;
wire SPR_EN = SYSTEM_CDx ? CD_SPR_EN : 1'b1;
wire DOTA_GATED = SPR_EN & DOTA;
wire DOTB_GATED = SPR_EN & DOTB;
wire HSync; //,VSync;

lspc2_a2_sync	LSPC(
	.CLK(CLK_48M),
	.CLK_EN_24M_P(CLK_EN_24M_P),
	.CLK_EN_24M_N(CLK_EN_24M_N),
	.RESET(nRESET),
	.nRESETP(nRESETP),
	.LSPC_8M(), .LSPC_4M(),
	.LSPC_EN_4M_P(CLK_EN_4M_P), .LSPC_EN_4M_N(CLK_EN_4M_N),
	.M68K_ADDR(M68K_ADDR[3:1]), .M68K_DATA(M68K_DATA),
	.IPL0(IPL0), .IPL1(IPL1),
	.CD_VBLANK_IRQ_EN(CD_VBLANK_IRQ_EN | ~SYSTEM_CDx),
	.CD_TIMER_IRQ_EN(CD_TIMER_IRQ_EN | ~SYSTEM_CDx),
	.LSPOE(nLSPOE), .LSPWE(nLSPWE),
	.PBUS_OUT(PBUS[15:0]), .PBUS_IO(PBUS[23:16]),
	.nPBUS_OUT_EN(nPBUS_OUT_EN),
	.DOTA(DOTA_GATED), .DOTB(DOTB_GATED),
	.CA4(CA4), .S2H1(S2H1), .S1H1(S1H1),
	.LOAD(LOAD), .H(H), .EVEN1(EVEN1), .EVEN2(EVEN2),
	.PCK1(PCK1), .PCK2(PCK2),
	.PCK1_EN_N(PCK1_EN_N), .PCK2_EN_N(PCK2_EN_N),
	.PCK1_EN_P(PCK1_EN_P), .PCK2_EN_P(PCK2_EN_P),
	.CHG(CHG),
	.LD1(LD1), .LD2(LD2),
	.WE(WE), .CK(CK),	.SS1(SS1), .SS2(SS2),
	.HSYNC(HSync), //.VSYNC(VSync),
	.CHBL(CHBL), .BNKB(nBNKB),
	.VCS(VCS),
	.SVRAM_ADDR(SLOW_VRAM_ADDR),
	.SVRAM_DATA_IN(SLOW_VRAM_DATA_IN), .SVRAM_DATA_OUT(SLOW_VRAM_DATA_OUT),
	.BOE(BOE), .BWE(BWE),
	.FVRAM_ADDR(FAST_VRAM_ADDR),
	.FVRAM_DATA_IN(FAST_VRAM_DATA_IN), .FVRAM_DATA_OUT(FAST_VRAM_DATA_OUT),
	.CWE(CWE),
	.VMODE(video_mode),
	.FIXMAP_ADDR(FIXMAP_ADDR)	// Extracted for NEO-CMC
);

wire nRESET_WD;
wire DOGE = SYSTEM_CDx ? ~CD_UPLOAD_EN : 1'b1; // UPLOAD_EN disables Watchdog?

neo_b1 B1(
	.CLK(CLK_48M),	.CLK_EN_6MB(CLK_EN_6MB), .CLK_EN_1HB(CLK_EN_1HB),
	.S1H1(S1H1),
	.A23I(A23Z), .A22I(A22Z),
	.M68K_ADDR_U(M68K_ADDR[21:17]), .M68K_ADDR_L(M68K_ADDR[12:1]),
	.nLDS(nLDS), .RW(M68K_RW), .nAS(nAS),
	.PBUS(PBUS),
	.FIXD(FIXD),
	.PCK1_EN(PCK1_EN_P), .PCK2_EN(PCK2_EN_P),
	.CHBL(CHBL), .BNKB(nBNKB),
	.GAD(GAD), .GBD(GBD),
	.WE(WE), .CK(CK),
	.TMS0(CHG), .LD1(LD1), .LD2(LD2), .SS1(SS1), .SS2(SS2),
	.PA(PAL_RAM_ADDR),
	.EN_FIX(FIX_EN),
	.DOGE(DOGE),
	.nRST(nRESET),
	.nRESET(nRESET_WD)
);

spram #(13,16) PALRAM(
	.clock(CLK_48M), 	// Was CLK_12M
	.address({PALBNK, PAL_RAM_ADDR}),
	.data(M68K_DATA),
	.wren(~nPAL_WE),
	.q(PAL_RAM_DATA)
);

// DAC latches
reg ce_pix;
reg [2:0] HBlank;
reg HBlank304;
always @(posedge CLK_VIDEO) begin
	reg [9:0] pxcnt;

	ce_pix <= 0;
	if(CLK_EN_6MB) begin
		ce_pix <= 1;
		PAL_RAM_REG <= (nRESET && VIDEO_EN && ((pxcnt >= 7 && pxcnt < 311) || ~status[16])) ? PAL_RAM_DATA : 16'h8000;
	end

	if(ce_pix) begin
		HBlank <= (HBlank<<1) | CHBL;
		
		pxcnt <= pxcnt + 1'b1;
		if(HBlank[1:0] == 2'b10) pxcnt <= 0;
	end
end

//Re-create VSync as original one is barely equals to VBlank
reg VSync;
reg RFSH;
always @(posedge CLK_VIDEO) begin
	reg       old_hs;
	reg       old_vbl;
	reg [2:0] vbl;
	reg [7:0] vblcnt, vspos, rfsh_cnt;
	
	if(ce_pix) begin
		old_hs <= HSync;
		if(~old_hs & HSync) begin
			old_vbl <= nBNKB;
			
			if(~nBNKB) vblcnt <= vblcnt+1'd1;
			if(old_vbl & ~nBNKB) vblcnt <= 0;
			if(~old_vbl & nBNKB) begin
				vspos <= (vblcnt>>1) - 8'd7;
				rfsh_cnt <= vblcnt-2'd2;
			end

			{VSync,vbl} <= {vbl,1'b0};
			if(vblcnt == vspos) {VSync,vbl} <= '1;
		end
		
		RFSH <= (vblcnt < rfsh_cnt);
	end
end

assign VGA_SL = scale ? scale[1:0] - 1'd1 : 2'd0;
assign VGA_F1 = 0;

wire [2:0] scale = status[20:18];

wire [6:0] R6 = {1'b0, PAL_RAM_REG[11:8], PAL_RAM_REG[14], PAL_RAM_REG[11]} - PAL_RAM_REG[15];
wire [6:0] G6 = {1'b0, PAL_RAM_REG[7:4],  PAL_RAM_REG[13], PAL_RAM_REG[7] } - PAL_RAM_REG[15];
wire [6:0] B6 = {1'b0, PAL_RAM_REG[3:0],  PAL_RAM_REG[12], PAL_RAM_REG[3] } - PAL_RAM_REG[15];

wire [7:0] R8 = R6[6] ? 8'd0 : {R6[5:0],  R6[4:3]};
wire [7:0] G8 = G6[6] ? 8'd0 : {G6[5:0],  G6[4:3]};
wire [7:0] B8 = B6[6] ? 8'd0 : {B6[5:0],  B6[4:3]};

wire [7:0] r,g,b;
wire hs,vs,hblank,vblank;
video_cleaner video_cleaner
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_pix),

	.R(~SHADOW ? R8 : {1'b0, R8[7:1]}),
	.G(~SHADOW ? G8 : {1'b0, G8[7:1]}),
	.B(~SHADOW ? B8 : {1'b0, B8[7:1]}),

	.HSync(HSync),
	.VSync(VSync),
	.HBlank(HBlank[0]),
	.VBlank(~nBNKB),

	.VGA_R(r),
	.VGA_G(g),
	.VGA_B(b),
	.VGA_VS(vs),
	.VGA_HS(hs),
	.HBlank_out(hblank),
	.VBlank_out(vblank)
);

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),

	.VGA_DE(vga_de),
	.R(r),
	.G(g),
	.B(b),

	// Positive pulses.
	.HSync(hs),
	.VSync(vs),
	.HBlank(hblank),
	.VBlank(vblank)
);

endmodule
