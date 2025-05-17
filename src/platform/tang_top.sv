/* 
 * Top level for snestang
 * nand2mario, 2023.6
 */

//`define STEP_TRACE

`ifndef CONFIG_V
`error "config.v must be read before snestang_top.v"
`endif

import configPackage::*;

module snestang_top (
    input sys_clk,
    input s0,

    // UART
    input UART_RXD,
    output UART_TXD,

    // HDMI TX
    output       tmds_clk_p,
    output       tmds_clk_n,
    output [2:0] tmds_d_p,
    output [2:0] tmds_d_n,

    // LED
    output [7:0] led,

    // MicroSD
    // output sd_clk,
    // inout  sd_cmd,      // MOSI
    // input  sd_dat0,     // MISO
    // output sd_dat1,
    // output sd_dat2,
    // output sd_dat3,

    // SPI flash
    // output flash_spi_cs_n,          // chip select
    // input flash_spi_miso,           // master in slave out
    // output flash_spi_mosi,          // mster out slave in
    // output flash_spi_clk,           // spi clock
    // output flash_spi_wp_n,          // write protect
    // output flash_spi_hold_n,        // hold operations

`ifdef CONTROLLER_SNES
    // snes controllers
    output joy1_strb,
    output joy1_clk,
    input joy1_data,
    output joy2_strb,
    output joy2_clk,
    input joy2_data,
`endif

`ifdef CONTROLLER_DS2
    // dualshock controllers
    output ds_clk,
    input ds_miso,
    output ds_mosi,
    output ds_cs,
    output ds_clk2,
    input ds_miso2,
    output ds_mosi2,
    output ds_cs2,
`endif

    // USB1 and USB2
`ifdef USB1
    inout usb1_dp,
    inout usb1_dn,
`endif
`ifdef USB2
    inout usb2_dp,
    inout usb2_dn,
`endif
    // I2S Audio Output
    output logic I2S_SD,  // Serial Data (Target PA17)
    output logic I2S_SCK, // Serial Clock (Target PA18)
    output logic I2S_LRCK,// Optional: Left/Right Clock (If needed and pin available)
    // SDRAM
    output O_sdram_clk,
    output O_sdram_cke,
    output O_sdram_cs_n,            // chip select
    output O_sdram_cas_n,           // columns address select
    output O_sdram_ras_n,           // row address select
    output O_sdram_wen_n,           // write enable
    inout [SDRAM_DATA_WIDTH-1:0] IO_sdram_dq,       // 31 bit bidirectional data bus
    output [SDRAM_ROW_WIDTH-1:0] O_sdram_addr,     // 11 bit multiplexed address bus
    output [SDRAM_DATA_WIDTH/8-1:0] O_sdram_dqm,       // 
    output [1:0] O_sdram_ba         // 4 banks
);

// Clock signals
wire clk_sys; // From PLL
wire clk_pix; // From PLL
wire clk_cpu; // From PLL
wire pll_locked;
// wire mclk; // Old SNES clock - remove or repurpose if needed
// wire fclk; // Old SNES clock - remove or repurpose if needed
// wire fclk_p; // Old SNES clock - remove or repurpose if needed
// wire clk27; // Input clock now goes directly to PLL
// wire hclk5, hclk; // Old HDMI clocks - replace with clk_pix, clk_sys

// Reset logic - Now depends on PLL lock
// reg resetn = 1'b0; // Old reset logic
wire rst_n; // Active low reset for system
assign rst_n = ~s0 & pll_locked; // Assuming s0 is the reset button (active high?), inverted.
                                // Check polarity of s0 button.

// reg [15:0] resetcnt = 16'hffff; // Old reset logic
// always @(posedge mclk) begin // Old reset logic
//    resetcnt <= resetcnt == 0 ? 0 : resetcnt - 1;
//     if (resetcnt == 0)
//        resetn <= 1'b1;
// end

// Instantiate the Gowin PLL
gen_pll_rpll u_pll (
    .clkin     (sys_clk),   // Assuming top-level sys_clk is the 27MHz oscillator
    .clk_sys   (clk_sys),   // 148.5 MHz
    .clk_pix   (clk_pix),   //  74.25 MHz
    .clk_cpu   (clk_cpu),   //  12.00 MHz
    .locked    (pll_locked)
);

wire [23:0] ROM_ADDR;
wire ROM_CE_N, ROM_OE_N, ROM_WE_N, ROM_WORD;
wire [15:0] ROM_D;
wire [15:0] ROM_Q;
assign      ROM_Q = (ROM_WORD || ~ROM_ADDR[0]) ? cpu_port0 : { cpu_port0[7:0], cpu_port0[15:8] };

wire [16:0] WRAM_ADDR;
wire        WRAM_CE_N;
wire        WRAM_OE_N;
wire        WRAM_RD_N;
wire        WRAM_WE_N;
wire  [7:0] WRAM_SD_Q = WRAM_ADDR[0] ? cpu_port1[15:8] : cpu_port1[7:0];
wire  [7:0] WRAM_Q;
wire  [7:0] WRAM_D;
wire        wram_rd = ~WRAM_CE_N & ~WRAM_RD_N;
wire        wram_wr = ~WRAM_CE_N & ~WRAM_WE_N;

wire [19:0] BSRAM_ADDR;
wire        BSRAM_CE_N;
wire        BSRAM_OE_N;
wire        BSRAM_WE_N;
wire        BSRAM_RD_N;
wire  [7:0] BSRAM_Q = bsram_dout;
wire  [7:0] BSRAM_D;

wire [15:0] VRAM1_ADDR;
wire        VRAM1_WE_N;
wire  [7:0] VRAM1_D, VRAM1_Q;
wire [15:0] VRAM2_ADDR;
wire        VRAM2_WE_N;
wire  [7:0] VRAM2_D, VRAM2_Q;
wire        VRAM_OE_N;

wire [15:0] ARAM_ADDR;
wire        ARAM_CE_N;
wire        ARAM_OE_N;
wire        ARAM_WE_N;
wire [15:0] aram_dout;
wire  [7:0] ARAM_Q = ARAM_ADDR[0] ? aram_dout[15:8] : aram_dout[7:0];
wire  [7:0] ARAM_D;
wire        aram_16 = 0;

wire BLEND = 1'b0;
reg        PAL;
wire       dotclk  /*verilator public*/;
wire [14:0] rgb_out  /*verilator public*/;
wire [8:0] x_out /*verilator public*/, y_out /*verilator public*/;
wire       hblankn,vblankn;

wire [15:0] audio_l /*verilator public*/, audio_r /*verilator public*/;
wire audio_ready /*verilator public*/;
wire audio_en /*XXX synthesis syn_keep=1 */;

wire snes_joy_strb;
wire snes_joy1_clk, snes_joy2_clk;
wire [1:0] snes_joy1_di, snes_joy2_di;

// OR together when both SNES and DS2 controllers are connected (right now only nano20k supports both simultaneously)
wire [11:0] joy1_btns_ds2, joy2_btns_ds2;
wire [11:0] joy1_btns_snes, joy2_btns_snes;
wire [11:0] joy1_usb, joy2_usb;
wire [11:0] hid1, hid2;

wire [5:0] ph;
reg snes_start = 1'b0;
wire pause_snes_for_frame_sync;

wire [7:0] loader_do;
wire loader_do_valid, loading, header_finished;

reg [22:0] loader_addr = 0;

reg [7:0] dbg_reg, dbg_sel; 
wire [7:0] dbg_dat_out, dbg_dat_in;
reg dbg_reg_wr = 0;
reg dbg_break = 0;

wire [7:0] rom_type;
wire [3:0] rom_size, ram_size;
wire [23:0] rom_mask, ram_mask;

wire sdram_busy;
wire refresh;
reg enable; // && ~dbg_break && ~pause;
reg loaded;

always @(posedge clk_sys) begin        // wait until memory initialize to start SNES
    if (~sdram_busy && ~pause_snes_for_frame_sync && loaded)
        enable <= 1;
    else 
        enable <= 0;
end

wire sysclkf_ce, sysclkr_ce;
wire overlay;

`ifdef CHIP_DSPn
parameter USE_DSPn=1;
`else
parameter USE_DSPn=0;
`endif
`ifdef CHIP_GSU
parameter USE_GSU=1;
`else
parameter USE_GSU=0;
`endif

// `ifdef VERILATOR
// parameter USE_DSPn=1;
// parameter USE_GSU=1;
// `endif

`ifndef DISABLE_NEOGEO
neogeo_top core (
    // Clock and reset
    .clk_sys(clk_cpu), 
    .reset(~cpu_reset_n), // Connect reset to loader output (active high)
    
    // Wishbone bus interface (connected to bridge)
    .wb_clk_i(clk_sys), // Use main system clock (148.5MHz?) for Wishbone?
                       // Or clk_cpu (12MHz)? Needs verification.
    .wb_adr_o(wb_adr_o), 
    .wb_dat_i(wb_dat_i),
    .wb_dat_o(wb_dat_o),
    .wb_sel_o(wb_sel_o),
    .wb_we_o(wb_we_o),
    .wb_stb_o(wb_stb_o),
    .wb_cyc_o(wb_cyc_o),
    .wb_ack_i(wb_ack_i),
    
    // Video output (Connect directly, snes2hdmi likely needs replacement/modification later)
    .VIDEO_R(neo_VIDEO_R), // Renamed to avoid conflict with snes2hdmi
    .VIDEO_G(neo_VIDEO_G),
    .VIDEO_B(neo_VIDEO_B),
    .HSYNC(neo_HSYNC),
    .VSYNC(neo_VSYNC),
    .HBLANK(neo_HBLANK), // Note: snes2hdmi uses hblankn/vblankn (active low?)
    .VBLANK(neo_VBLANK),
    .hdmi_de(hdmi_de),        // Connect new DE output
    
    // Audio output (Connect directly, snes2hdmi likely needs replacement/modification later)
    .AUDIO_L(audio_l), // Assuming direct connection is okay for now
    .AUDIO_R(audio_r),
    
    // Input from MCU mailbox (connected to iosys)
    .input_reg(input_reg),   // Provided by iosys
    .command_reg(command_reg) // Provided by iosys
);
`endif // DISABLE_NEOGEO

// SDRAM / Wishbone Interface signals (Need wires for Wishbone connection to iosys)
wire        wb_clk_i; // Clock for Wishbone (driven by mclk?)
wire [31:0] wb_adr_o;
wire [31:0] wb_dat_i; // Data from iosys to core
wire [31:0] wb_dat_o; // Data from core to iosys
wire [3:0]  wb_sel_o;
wire        wb_we_o;
wire        wb_stb_o;
wire        wb_cyc_o;
wire        wb_ack_i; // Ack from iosys to core

// Input signals from iosys
wire [31:0] input_reg;    // Current input state
wire [31:0] command_reg;  // Command FIFO

// Intermediate video signals (renamed)
wire [7:0] neo_VIDEO_R;
wire [7:0] neo_VIDEO_G;
wire [7:0] neo_VIDEO_B;
wire       neo_HSYNC;
wire       neo_VSYNC;
wire       neo_HBLANK;
wire       neo_VBLANK;
wire       hdmi_de;    // Added wire for DE from core

// SDRAM for SNES ROM, WRAM and ARAM
wire [15:0] cpu_port0;
wire [15:0] cpu_port1;
reg         cpu_port;

reg         cpu_req;
reg  [1:0]  cpu_ds;
reg [15:0]  cpu_din;
reg [22:0]  cpu_addr; 
reg         cpu_we;

wire [22:0] rom_addr = loading ? loader_addr : ROM_ADDR[22:0];
reg [22:0]  rom_addr_sd;

reg [16:0]  wram_addr_sd;
reg         wram_wr_r, wram_rd_r;

reg         bsram_req, bsram_we;
reg [19:0]  bsram_addr;
reg [7:0]   bsram_din;
wire [7:0]  bsram_dout;
wire        bsram_rd = ~BSRAM_CE_N & (~BSRAM_RD_N || rom_type[7:4] == 4'hC);
wire        bsram_wr = ~BSRAM_CE_N & ~BSRAM_WE_N;
reg         bsram_rd_r, bsram_wr_r;

wire        aram_rd = ~ARAM_CE_N & ~ARAM_OE_N;
wire        aram_wr = ~ARAM_CE_N & ~ARAM_WE_N;
reg [15:0]  aram_addr_sd;
reg         aram_rd_r, aram_wr_r;
reg         aram_req;

wire        DOT_CLK_CE;
assign      O_sdram_clk = clk_sys;

// Generate SDRAM signals
always @(posedge clk_sys) begin
    if (~rst_n) begin
    end else begin
        
        // ROM read and load
        if (loading && loader_do_valid && header_finished && loader_addr[0] 
            || ~loading && ~ROM_CE_N && rom_addr_sd != rom_addr) begin
            rom_addr_sd <= rom_addr;
            cpu_addr <= rom_addr;
            cpu_req <= ~cpu_req;
            cpu_we <= loading;
            cpu_din <= {loader_do, loader_do_r};    // write 16 bits on odd addresses
            cpu_ds <= 2'b11;
            cpu_port <= 0;
        end
        
        // WRAM read/write
        wram_rd_r <= wram_rd; wram_wr_r <= wram_wr;
        if ((wram_rd && WRAM_ADDR[16:1] != wram_addr_sd[16:1]) || (wram_rd & ~wram_rd_r) || (wram_wr & ~wram_wr_r)) begin
            wram_addr_sd <= WRAM_ADDR;
            cpu_req <= ~cpu_req;
            cpu_addr <= {6'b111_111, WRAM_ADDR[16:0]};  // 7E,7F:0000-FFFF, total 128KB
            cpu_we <= wram_wr;
            cpu_ds <= {WRAM_ADDR[0], ~WRAM_ADDR[0]};
            cpu_din <= {WRAM_D, WRAM_D};        
            cpu_port <= 1;
        end 

        // BSRAM read/write
        bsram_rd_r <= bsram_rd; bsram_wr_r <= bsram_wr;
        if (bsram_rd && BSRAM_ADDR != bsram_addr || (bsram_wr & ~bsram_wr_r) || (bsram_rd & ~bsram_rd_r)) begin
            bsram_addr <= BSRAM_ADDR;
            bsram_req <= ~bsram_req;
            bsram_din <= BSRAM_D;
        end

        // ARAM read/write
        aram_rd_r <= aram_rd; aram_wr_r <= aram_wr;
        if (aram_rd && aram_addr_sd != ARAM_ADDR || (aram_wr && aram_addr_sd != ARAM_ADDR) || (aram_rd & ~aram_rd_r) || (aram_wr & ~aram_wr_r)) begin
            aram_req <= ~aram_req;
            aram_addr_sd <= ARAM_ADDR;
        end
    end
end

localparam RV_IDLE_REQ0 = 3'd0;
localparam RV_WAIT0_REQ1 = 3'd1;
localparam RV_DATA0 = 3'd2;
localparam RV_WAIT1 = 3'd3;
localparam RV_DATA1 = 3'd4;
reg [2:0]   rvst;

wire        rv_valid;
reg         rv_ready;
wire [22:0] rv_addr;
wire [31:0] rv_wdata;
wire [3:0]  rv_wstrb;
reg  [15:0] rv_dout0;
wire [31:0] rv_rdata = {rv_dout, rv_dout0};
reg         rv_valid_r;
reg         rv_word;           // which word
reg         rv_req;
wire        rv_req_ack;
wire [15:0] rv_dout;
reg [1:0]   rv_ds;
reg         rv_new_req;

reg [14:0] vram1_addr_sd, vram2_addr_sd;
reg vram1_we_n_old, vram2_we_n_old;
reg vram1_req /* synthesis syn_keep=1 */; 
reg vram2_req /* synthesis syn_keep=1 */;
reg [7:0] vram1_din, vram2_din;

always @(posedge clk_sys) begin
    vram1_we_n_old <= VRAM1_WE_N;
    if ((~VRAM1_WE_N & vram1_we_n_old) || (VRAM1_ADDR[14:0] != vram1_addr_sd && ~VRAM_OE_N)) begin
        vram1_addr_sd <= VRAM1_ADDR[14:0];
        vram1_din <= VRAM1_D;
        vram1_req <= ~vram1_req;
    end

    vram2_we_n_old <= VRAM2_WE_N;
    if ((~VRAM2_WE_N & vram2_we_n_old) || (VRAM2_ADDR[14:0] != vram2_addr_sd && ~VRAM_OE_N)) begin
        vram2_addr_sd <= VRAM2_ADDR[14:0];
        vram2_din <= VRAM2_D;
        vram2_req <= ~vram2_req;
    end
end

sdram_snes sdram(
    .clk(clk_sys), .mclk(clk_sys), .clkref(DOT_CLK_CE), .resetn(rst_n), .busy(sdram_busy),

    // SDRAM pins
    .SDRAM_DQ(IO_sdram_dq), .SDRAM_A(O_sdram_addr), .SDRAM_BA(O_sdram_ba), 
    .SDRAM_nCS(O_sdram_cs_n), .SDRAM_nWE(O_sdram_wen_n), .SDRAM_nRAS(O_sdram_ras_n), 
    .SDRAM_nCAS(O_sdram_cas_n), .SDRAM_CKE(O_sdram_cke), .SDRAM_DQM(O_sdram_dqm), 

    // CPU accesses
    .cpu_addr(cpu_addr[22:1]), .cpu_din(cpu_din), .cpu_port(cpu_port), 
    .cpu_port0(cpu_port0), .cpu_port1(cpu_port1), .cpu_req(cpu_req), .cpu_req_ack(),
    .cpu_we(cpu_we), .cpu_ds(cpu_ds),

    // BSRAM accesses
    .bsram_addr(bsram_addr), .bsram_dout(bsram_dout), .bsram_din(bsram_din),
    .bsram_req(bsram_req), .bsram_req_ack(), .bsram_we(bsram_wr),

    // ARAM accesses
    .aram_16(aram_16), .aram_addr(ARAM_ADDR), .aram_din({ARAM_D, ARAM_D}), 
    .aram_dout(aram_dout), .aram_req(aram_req), .aram_req_ack(), .aram_we(aram_wr),

`ifdef SDRAM_3CH
    // VRAM accesses
    .vram1_addr(vram1_addr_sd), .vram1_req(vram1_req), .vram1_ack(), 
    .vram1_we(~vram1_we_n_old), .vram1_din(vram1_din), .vram1_dout(VRAM1_Q), 
    .vram2_addr(vram2_addr_sd), .vram2_req(vram2_req), .vram2_ack(),
    .vram2_we(~vram2_we_n_old),  .vram2_din(vram2_din), .vram2_dout(VRAM2_Q),
`endif

`ifdef MCU_BL616
    .rv_addr(), .rv_din(), 
    .rv_ds(), .rv_dout(), .rv_req(), .rv_req_ack(), .rv_we()
`else
    // IOSys risc-v softcore
    .rv_addr({rv_addr[22:2], rv_word}), .rv_din(rv_word ? rv_wdata[31:16] : rv_wdata[15:0]), 
    .rv_ds(rv_ds), .rv_dout(rv_dout), .rv_req(rv_req), .rv_req_ack(rv_req_ack), .rv_we(rv_wstrb != 0)
`endif
);

`ifndef SDRAM_3CH
// FPGA block RAM for SNES VRAM 
vram vram(
    .clk(clk_sys), 
    .vram1_addr(vram1_addr_sd), .vram1_req(vram1_req), .vram1_ack(), 
    .vram1_we(~vram1_we_n_old), .vram1_din(vram1_din), .vram1_dout(VRAM1_Q), 
    .vram2_addr(vram2_addr_sd), .vram2_req(vram2_req), .vram2_ack(),
    .vram2_we(~vram2_we_n_old),  .vram2_din(vram2_din), .vram2_dout(VRAM2_Q)
);
`endif

// Parse 64-byte rom header into rom_type and etc
smc_parser smc (
    .clk(clk_sys), .resetn(rst_n & ~(loading & ~loading_r)),
    .rom_d(loader_do), .rom_strb(loader_do_valid), 
    .rom_type(rom_type), .rom_mask(rom_mask), .ram_mask(ram_mask),
    .rom_size(rom_size), .ram_size(ram_size),
    .header_finished(header_finished)
);

reg [7:0] loader_do_r;
reg loading_r;
always @(posedge clk_sys) begin
    if (~rst_n) begin
        loading_r <= 0;
        loaded <= 0;
    end else begin
        loading_r <= loading;
        if (loader_do_valid && header_finished) begin
            loader_addr <= loader_addr + 23'd1; 
            loader_do_r <= loader_do;
        end
        if (loading & ~loading_r) begin
            loader_addr <= 0;
            loaded <= 0;
        end
        if (~loading & loading_r)
            loaded <= 1;
    end
end

`ifndef VERILATOR

// Controller input
`ifdef CONTROLLER_SNES
controller_snes joy1_snes (
    .clk(clk_sys), .resetn(rst_n), .buttons(joy1_btns_snes),
    .joy_strb(joy1_strb), .joy_clk(joy1_clk), .joy_data(joy1_data)
);
controller_snes joy2_snes (
    .clk(clk_sys), .resetn(rst_n), .buttons(joy2_btns_snes),
    .joy_strb(joy2_strb), .joy_clk(joy2_clk), .joy_data(joy2_data)
);
`else
assign joy1_btns_snes = 12'h0;
assign joy2_btns_snes = 12'h0;
`endif

`ifdef CONTROLLER_DS2
controller_ds2 joy1_ds2 (
    .clk(clk_sys), .snes_buttons(joy1_btns_ds2),
    .ds_clk(ds_clk), .ds_miso(ds_miso), .ds_mosi(ds_mosi), .ds_cs(ds_cs) 
);
controller_ds2 joy2_ds2 (
   .clk(clk_sys), .snes_buttons(joy2_btns_ds2),
   .ds_clk(ds_clk2), .ds_miso(ds_miso2), .ds_mosi(ds_mosi2), .ds_cs(ds_cs2) 
);
`else
assign joy1_btns_ds2 = 12'h0;
assign joy2_btns_ds2 = 12'h0;
`endif

`ifdef USB1
wire clk12;
wire pll_lock_12;
wire usb_conerr;
wire [1:0] usb_type;
pll_12 pll12(.clkin(sys_clk), .clkout0(clk12), .lock(pll_lock_12));
usb_hid_host usb_hid_host (
    .usbclk(clk12), .usbrst_n(pll_lock_12),
    .usb_dm(usb1_dn), .usb_dp(usb1_dp),
    .typ(usb_type), .conerr(usb_conerr),
    .game_snes(joy1_usb)
);
`else
assign joy1_usb = 12'h0;
`endif

`ifdef USB2
wire usb_conerr2;
wire [1:0] usb_type2;   
usb_hid_host usb_hid_host2 (
    .usbclk(clk12), .usbrst_n(pll_lock_12),
    .usb_dm(usb2_dn), .usb_dp(usb2_dp),
    .game_snes(joy2_usb), .typ(usb_type2), .conerr(usb_conerr2)
);
assign led = ~{joy2_usb[1:0], usb_type2, usb_conerr2, usb_type, usb_conerr};
`else
assign joy2_usb = 12'h0;
`endif

// output button presses to SNES
controller_adapter joy1_adapter (
    .clk(clk_sys), .snes_joy_strb(snes_joy_strb), 
    .snes_buttons(joy1_btns_ds2 | joy1_btns_snes | hid1 | joy1_usb), .snes_joy_clk(snes_joy1_clk), .snes_joy_di(snes_joy1_di[0])
);
controller_adapter joy2_adapter (
    .clk(clk_sys), .snes_joy_strb(snes_joy_strb), 
    .snes_buttons(joy2_btns_ds2 | joy2_btns_snes | hid2 | joy2_usb), .snes_joy_clk(snes_joy2_clk), .snes_joy_di(snes_joy2_di[0])
);
assign snes_joy1_di[1] = 0;  // P3
assign snes_joy2_di[1] = 0;  // P4

wire [14:0] overlay_color;
wire [7:0] overlay_x;
wire [7:0] overlay_y;

wire [7:0] dbg_dat_out_loader;

// Wires for NeoGeo Video Output (renamed in previous steps)
// wire [7:0] neo_VIDEO_R;
// wire [7:0] neo_VIDEO_G;
// wire [7:0] neo_VIDEO_B;
// wire       neo_HSYNC;
// wire       neo_VSYNC;
// wire       neo_HBLANK; // From neogeo_top
// wire       neo_VBLANK; // From neogeo_top
// wire       hdmi_de;    // From neogeo_top (Task 4.3 - added later)

// --- HDMI 720p Timing Generation ---
localparam H_ACTIVE     = 1280;
localparam H_FP         = 110;
localparam H_SYNC       = 40;
localparam H_BP         = 220;
localparam H_TOTAL      = H_ACTIVE + H_FP + H_SYNC + H_BP; // 1650

localparam V_ACTIVE     = 720;
localparam V_FP         = 5;
localparam V_SYNC       = 5;
localparam V_BP         = 20;
localparam V_TOTAL      = V_ACTIVE + V_FP + V_SYNC + V_BP; // 750

logic [11:0] h_count = 0;
logic [10:0] v_count = 0;
logic hdmi_hs_gen, hdmi_vs_gen, hdmi_de_gen;

always_ff @(posedge clk_pix or negedge rst_n) begin
    if (!rst_n) begin
        h_count <= 0;
        v_count <= 0;
        hdmi_hs_gen <= 1'b1; // HSync Active Positive
        hdmi_vs_gen <= 1'b1; // VSync Active Positive
        hdmi_de_gen <= 1'b0;
    end else begin
        // Counters
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1) begin
                v_count <= 0;
            end else begin
                v_count <= v_count + 1;
            end
        end else begin
            h_count <= h_count + 1;
        end

        // HSync
        if (h_count >= H_ACTIVE + H_FP && h_count < H_ACTIVE + H_FP + H_SYNC) begin
            hdmi_hs_gen <= 1'b1;
        end else begin
            hdmi_hs_gen <= 1'b0;
        end

        // VSync
        if (v_count >= V_ACTIVE + V_FP && v_count < V_ACTIVE + V_FP + V_SYNC) begin
            hdmi_vs_gen <= 1'b1;
        end else begin
            hdmi_vs_gen <= 1'b0;
        end

        // Data Enable
        if (h_count < H_ACTIVE && v_count < V_ACTIVE) begin
            hdmi_de_gen <= 1'b1;
        end else begin
            hdmi_de_gen <= 1'b0;
        end
    end
end

// --- Fractional Scaler --- 
logic [7:0] scaled_r, scaled_g, scaled_b;
logic scaled_de; // Data enable from scaler

// TODO: Need input video parameters from neogeo_top 
// (e.g., input width, height, maybe blanking signals)
localparam IN_WIDTH  = 320; // Example: NeoGeo typical width
localparam IN_HEIGHT = 224; // Example: NeoGeo typical height

scaler_frac #(
    .IN_WIDTH(IN_WIDTH),
    .IN_HEIGHT(IN_HEIGHT),
    .OUT_WIDTH(H_ACTIVE),
    .OUT_HEIGHT(V_ACTIVE)
) u_scaler (
    .clk(clk_pix), 
    .rst_n(rst_n),

    .i_r(neo_VIDEO_R), 
    .i_g(neo_VIDEO_G),
    .i_b(neo_VIDEO_B),
    .i_hs(neo_HSYNC),    // Assuming NeoGeo outputs syncs
    .i_vs(neo_VSYNC),
    .i_de(hdmi_de),     // Use DE derived from NeoGeo HBLANK/VBLANK (Task 4.3)

    .o_r(scaled_r),
    .o_g(scaled_g),
    .o_b(scaled_b),
    .o_hs(),           // Scaler output HSync (unused? Use generated 720p sync)
    .o_vs(),           // Scaler output VSync (unused? Use generated 720p sync)
    .o_de(scaled_de)   // Use DE from scaler
);

// --- TMDS Output Stage ---
// Using serializer + tmds_channel copied from SNESTang hdmi2
// This likely needs adaptation / replacement with simpler ODDR logic or Gowin ELVDS primitives.

logic [9:0] data_p, data_n; // TMDS data pairs (3 channels)
logic       clk_p, clk_n;  // TMDS clock pair

// Blank pixels outside active area
logic [7:0] final_r, final_g, final_b;
assign final_r = (hdmi_de_gen & scaled_de) ? scaled_r : 8'd0;
assign final_g = (hdmi_de_gen & scaled_de) ? scaled_g : 8'd0;
assign final_b = (hdmi_de_gen & scaled_de) ? scaled_b : 8'd0;

// Instantiation requires understanding the serializer interface
// Placeholder - replace with actual TMDS generation
// serializer #(
//     .VIDEO_RATE(74_250_000) // Example
// ) hdmi_ser (
//     .clk_pixel(clk_pix),
//     .clk_5x_pixel(clk_sys),
//     .locked(pll_locked),
//     .rst_n(rst_n),

//     .red(final_r),
//     .green(final_g),
//     .blue(final_b),
//     .hsync(hdmi_hs_gen),
//     .vsync(hdmi_vs_gen),
//     .de(hdmi_de_gen & scaled_de),

//     .tmds_clk_p(clk_p),
//     .tmds_clk_n(clk_n),
//     .tmds_data_p(data_p[9:0]),
//     .tmds_data_n(data_n[9:0])
// );

// Connect TMDS pairs to top-level outputs
// Example, assuming 3 data channels (0=B, 1=G, 2=R)
// assign tmds_d_p[0] = data_p[?]; // Map correctly
// assign tmds_d_n[0] = data_n[?];
// assign tmds_d_p[1] = data_p[?];
// assign tmds_d_n[1] = data_n[?];
// assign tmds_d_p[2] = data_p[?];
// assign tmds_d_n[2] = data_n[?];
// assign tmds_clk_p = clk_p;
// assign tmds_clk_n = clk_n;

// Placeholder: Directly assign outputs (REMOVE THIS LATER)
 assign tmds_d_p = 3'b0; 
 assign tmds_d_n = 3'b0; 
 assign tmds_clk_p = 1'b0; 
 assign tmds_clk_n = 1'b0;

// IOSys Instantiation (Changed to iosys_picorv32)
`ifdef MCU_PICORV32
iosys_picorv32 #(
    .FREQ(12_000_000), // Use 12MHz clk_cpu frequency
    .COLOR_LOGO(15\'b00000_10101_00000),
    .CORE_ID(CORE_ID_NEOGEO) // Define CORE_ID_NEOGEO
) iosys (
    .clk(clk_cpu), // Use 12MHz clock for IOSys
    .hclk(clk_pix), // Use 74.25MHz pixel clock for HDMI related logic in IOSys?
    .resetn(rst_n),

    // OSD display interface
    .overlay(overlay), 
    .overlay_x(overlay_x), 
    .overlay_y(overlay_y),
    .overlay_color(overlay_color),
    .joy1(joy1_btns_ds2 | joy1_btns_snes | joy1_usb), // Combine inputs as before
    .joy2(joy2_btns_ds2 | joy2_btns_snes | joy2_usb),
    // .hid1(hid1), // iosys_picorv32 doesn't seem to have hid outputs
    // .hid2(hid2),

    // ROM loading interface
    .rom_loading(loading),       // Controlled by loader now? Or still by PicoRV32?
    .rom_do(loader_do),
    .rom_do_valid(loader_do_valid),

    // Memory interface (PicoRV32 master)
    .rv_valid(rv_valid),
    .rv_ready(loader_mem_ready), // Feed bridge ready back to PicoRV32
    .rv_addr(rv_addr[22:0]), 
    .rv_wdata(rv_wdata),
    .rv_wstrb(rv_wstrb),
    .rv_rdata(rv_rdata), // Feed bridge read data back
    .rv_we(rv_we), 
    
    .ram_busy(ddr_busy), 

    // SPI flash
    .flash_spi_cs_n(/* Connect flash_spi_cs_n */),
    .flash_spi_miso(/* Connect flash_spi_miso */),
    .flash_spi_mosi(/* Connect flash_spi_mosi */),
    .flash_spi_clk(/* Connect flash_spi_clk */),
    .flash_spi_wp_n(/* Connect flash_spi_wp_n */),
    .flash_spi_hold_n(/* Connect flash_spi_hold_n */),

    // UART
    .uart_rx(UART_RXD),
    .uart_tx(UART_TXD)

    // SD card - Needs connection if used
    // .sd_clk(sd_clk),
    // .sd_cmd(sd_cmd),
    // .sd_dat0(sd_dat0),
    // .sd_dat1(sd_dat1),
    // .sd_dat2(sd_dat2),
    // .sd_dat3(sd_dat3)
);

// --- I2S Audio Output ---
wire i2s_lrck_wire; // Wire for LRCK output from i2s module
wire audio_ce;      // Clock enable for I2S module (needs generation)

// Generate audio clock enable (e.g., for 48kHz from 12MHz clk_cpu)
// 12,000,000 / (48,000 * 16 * 2) = 12,000,000 / 1,536,000 = 7.8125
// Need a fractional divider or adjust PLL/target sample rate.
// Placeholder: Simple divider (adjust divisor 'N' based on actual clk and target rate)
localparam AUDIO_CLK_DIVISOR = 8; // Example for ~1.5MHz BCLK from 12MHz clk_cpu
reg [$clog2(AUDIO_CLK_DIVISOR)-1:0] audio_clk_count = 0;
always_ff @(posedge clk_cpu or negedge rst_n) begin
    if (!rst_n) begin
        audio_clk_count <= 0;
    end else begin
        if (audio_clk_count == AUDIO_CLK_DIVISOR - 1) begin
            audio_clk_count <= 0;
        end else begin
            audio_clk_count <= audio_clk_count + 1;
        end
    end
end
assign audio_ce = (audio_clk_count == 0); // Enable signal

i2s #(
    .AUDIO_DW(16) // Assuming 16-bit audio
) i2s_tx_inst (
    .reset(~rst_n),       // Active high reset
    .clk(clk_cpu),        // Use clk_cpu (12MHz) - Needs verification!
    .ce(audio_ce),

    .sclk(I2S_SCK),       // Connect to top-level PA18
    .lrclk(i2s_lrck_wire),// Internal wire for now
    .sdata(I2S_SD),       // Connect to top-level PA17

    .left_chan(audio_l),  // From neogeo_top
    .right_chan(audio_r) // From neogeo_top
);
// assign I2S_LRCK = i2s_lrck_wire; // Connect if PA pin is available/needed

// --- NeoGeo Loader ---
wire game_loaded;   // From loader
wire cpu_reset_n; // From loader (active low)
wire loader_mem_valid; // Loader's request to bridge
wire loader_mem_ready; // Bridge's ready to loader
wire [24:0] loader_mem_addr;
wire [31:0] loader_mem_wdata;
wire [3:0]  loader_mem_be;
wire        loader_mem_we;
wire [31:0] loader_mem_rdata; // Read data (unused by loader)
wire        loader_io_ack; // Loader ACK back to iosys?

neogeo_loader #(
    .ADDR_WIDTH(25),
    .DATA_WIDTH(32)
) u_loader (
    .clk(clk_sys),      // Use system clock? Or clk_cpu?
    .rst_n(rst_n),

    // From IOSys
    .io_rom_do(loader_do),       // Data byte from iosys
    .io_rom_do_valid(loader_do_valid), // Valid strobe from iosys
    .io_ack(loader_io_ack),        // ACK back to iosys (if needed)

    // To Memory Bridge (RV Port - assumes loader takes priority over PicoRV32)
    .mem_valid_o(loader_mem_valid),
    .mem_ready_i(loader_mem_ready),
    .mem_addr_o(loader_mem_addr),
    .mem_wdata_o(loader_mem_wdata),
    .mem_be_o(loader_mem_be),
    .mem_we_o(loader_mem_we),
    .mem_rdata_i(loader_mem_rdata),

    // Outputs
    .game_loaded_o(game_loaded),
    .cpu_reset_n_o(cpu_reset_n) 
);

// Update neogeo_top reset connection
neogeo_top core (
    // Clock and reset
    .clk_sys(clk_cpu), 
    .reset(~cpu_reset_n), // Connect reset to loader output (active high)
    
    // Wishbone bus interface (connected to bridge)
    .wb_clk_i(clk_sys), // Use main system clock (148.5MHz?) for Wishbone?
                       // Or clk_cpu (12MHz)? Needs verification.
    .wb_adr_o(wb_adr_o), 
    .wb_dat_i(wb_dat_i),
    .wb_dat_o(wb_dat_o),
    .wb_sel_o(wb_sel_o),
    .wb_we_o(wb_we_o),
    .wb_stb_o(wb_stb_o),
    .wb_cyc_o(wb_cyc_o),
    .wb_ack_i(wb_ack_i),
    
    // Video output (Connect directly, snes2hdmi likely needs replacement/modification later)
    .VIDEO_R(neo_VIDEO_R), // Renamed to avoid conflict with snes2hdmi
    .VIDEO_G(neo_VIDEO_G),
    .VIDEO_B(neo_VIDEO_B),
    .HSYNC(neo_HSYNC),
    .VSYNC(neo_VSYNC),
    .HBLANK(neo_HBLANK), // Note: snes2hdmi uses hblankn/vblankn (active low?)
    .VBLANK(neo_VBLANK),
    .hdmi_de(hdmi_de),        // Connect new DE output
    
    // Audio output (Connect directly, snes2hdmi likely needs replacement/modification later)
    .AUDIO_L(audio_l), // Assuming direct connection is okay for now
    .AUDIO_R(audio_r),
    
    // Input from MCU mailbox (connected to iosys)
    .input_reg(input_reg),   // Provided by iosys
    .command_reg(command_reg) // Provided by iosys
);

// Update Bridge RV Port Connection (Multiplex Loader/PicoRV32 or give Loader priority)
// Simple Loader Priority: Loader request overrides PicoRV32
wire rv_bridge_valid = loader_mem_valid | rv_valid; // Combine valid signals
wire rv_bridge_we    = loader_mem_valid ? loader_mem_we : rv_we;
wire [24:0] rv_bridge_addr = loader_mem_valid ? loader_mem_addr : rv_addr; 
wire [31:0] rv_bridge_wdata= loader_mem_valid ? loader_mem_wdata : rv_wdata;
wire [3:0] rv_bridge_be = loader_mem_valid ? loader_mem_be : rv_wstrb;

rv_ddr3_bridge #(
// ... parameters ...
) u_bridge (
    // Clocks and Reset
    .clk             (clk_sys), 
    .rst_n           (rst_n),

    // Master 0: NeoGeo Wishbone
    // ... WB connections ...

    // Master 1: PicoRV32 / Loader (Loader has priority)
    .rv_addr_i       (rv_bridge_addr),
    .rv_wdata_i      (rv_bridge_wdata),
    .rv_rdata_o      (rv_rdata),      // Read data back to RV/Loader
    .rv_we_i         (rv_bridge_we),
    .rv_be_i         (rv_bridge_be),
    .rv_valid_i      (rv_bridge_valid),
    .rv_ready_o      (loader_mem_ready), // Bridge ready back to Loader/RV
                                         // Need separate readys if simultaneous access needed

    // DDR3 simple‑port Interface
    // ... DDR connections ...
);

// Update IOSys Connections
iosys_picorv32 #(
// ... parameters ...
) iosys (
    // ... other iosys ports ...

    // ROM loading interface
    .rom_loading(loading),       // Controlled by loader now? Or still by PicoRV32?
    .rom_do(loader_do),
    .rom_do_valid(loader_do_valid),
    // .io_ack(loader_io_ack) ?? // Does iosys need ACK?

    // Memory interface (PicoRV32 master)
    .rv_valid(rv_valid),
    .rv_ready(loader_mem_ready), // Feed bridge ready back to PicoRV32
    .rv_addr(rv_addr[22:0]), 
    .rv_wdata(rv_wdata),
    .rv_wstrb(rv_wstrb),
    .rv_rdata(rv_rdata), // Feed bridge read data back
    .rv_we(rv_we), 
    
    .ram_busy(ddr_busy), 
    // ... rest of iosys ports ...
);

`else       // VERILATOR

// test loader with embedded rom
test_loader test_loader (
    .clk(clk_sys), .resetn(rst_n),
    .dout(loader_do), .dout_valid(loader_do_valid),
    .loading(loading), .fail()
);

// test audio sink: FIFO-like rate limiting to sound sample generation
reg [3:0] sample_counter = 0;
always @(posedge clk_sys) begin
    if (audio_ready)
        sample_counter <= 0;
    else
        sample_counter <= sample_counter == 15 ? 15 : sample_counter + 1;
end
assign audio_en = sample_counter == 15;


// test video sync by turning on pause_snes_for_frame_sync periodically
reg test_halt_snes, test_sync_done;
reg [3:0] test_halt_cnt = 0;
assign pause_snes_for_frame_sync = test_halt_snes;

always @(posedge clk_sys) begin    // halt SNES during snes dram refresh on line 2
    if (~rst_n) begin
        test_halt_cnt <= 0;
        test_halt_snes <= 0;
        test_sync_done <= 0;
    end else begin
        if (~test_sync_done) begin
            if (~test_halt_snes) begin
                if (y_out[7:0] == 2 && refresh) begin
                    test_halt_snes <= 1;
                    test_halt_cnt <= 4'd12;        // halt snes for 13 cycles
                end
            end else begin
                if (test_halt_cnt != 0) begin
                    test_halt_cnt <= test_halt_cnt - 4'd1;
                end else begin
                    test_halt_snes <= 0;
                    test_sync_done <= 1;
                end                            
            end
        end else if (y_out[7:0] == 8'd200)
            test_sync_done <= 0;
    end
end

`endif

`ifndef VERILATOR

reg [19:0] timer;           // 21 times per second

// status display on LED

reg [9:0] status;
//assign led = s0 == 1'b0 ? ~status[9:5] : ~status[4:0];        // s0==0 when pressed, for mega138k
// assign led = UART_TXD;
//assign led = joy1_btns[1:0];        // Y and B

always @(posedge clk_sys) begin
    if (loading && ~loading_r)
        status <= 0;
    if (loaded) begin
        case (rom_addr)
        23'h00_000A: status[1] <= 1;
        23'h00_00A1: status[2] <= 1;        // Clear_WRAM
        23'h00_0645: status[3] <= 1;        // Main
        23'h00_0111: status[4] <= 1;        // DMA_Palette
        
        23'h00_06AB: status[5] <= 1;        // Draw_Map
        23'h00_072A: status[6] <= 1;        // Init_Music
        23'h00_075F: status[7] <= 1;        // Infinite_loop
        23'h00_0787: status[8] <= 1;        // left button
        default: ;
        endcase
    end
end

`endif

endmodule
