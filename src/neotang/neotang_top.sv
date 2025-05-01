// Modified neotang_top.sv to use MiSTer Neo-Geo core
// Based on MiSTer NeoGeo Core by Sean 'Furrtek' Gonsalves
// Tang port by Manus AI

module neotang_top (
    // Clock inputs
    input wire clk_27m,        // 27 MHz system clock
    
    // Reset
    input wire reset_n,        // Active low reset
    
    // HDMI output
    output wire [3:0] tmds_p,  // TMDS positive signals (RGB + Clock)
    output wire [3:0] tmds_n,  // TMDS negative signals (RGB + Clock)
    
    // SDRAM interface
    output wire sdram_clk,     // SDRAM clock
    output wire sdram_cke,     // SDRAM clock enable
    output wire sdram_cs_n,    // SDRAM chip select
    output wire sdram_ras_n,   // SDRAM row address strobe
    output wire sdram_cas_n,   // SDRAM column address strobe
    output wire sdram_we_n,    // SDRAM write enable
    output wire [1:0] sdram_ba,// SDRAM bank address
    output wire [12:0] sdram_a,// SDRAM address
    inout wire [15:0] sdram_dq,// SDRAM data
    output wire sdram_dqml,    // SDRAM data mask low
    output wire sdram_dqmh,    // SDRAM data mask high
    
    // BL616 MCU interface
    input wire uart_rx,        // UART RX from BL616
    output wire uart_tx,       // UART TX to BL616
    
    // Debug LEDs
    output wire [1:0] leds     // Debug LEDs
);

    // ========================================================================
    // Clock Generation
    // ========================================================================
    
    // We need several clocks:
    // - 74.25 MHz for HDMI 720p output
    // - 371.25 MHz (5x 74.25 MHz) for HDMI serializer
    // - 96 MHz for core (clk_sys in MiSTer)
    // - 24.576 MHz for audio (48kHz * 512)
    
    wire clk_74m25;    // 74.25 MHz for HDMI
    wire clk_371m25;   // 371.25 MHz for HDMI serializer (5x pixel clock)
    wire clk_96m;      // 96 MHz for core (clk_sys)
    wire clk_48m;      // 48 MHz for core (clk_sys in MiSTer)
    wire clk_24m576;   // 24.576 MHz for audio
    wire pll_locked;   // PLL lock indicator
    wire pll_x5_locked; // PLL lock indicator for 5x clock
    
    // Instantiate Gowin PLL for clock generation
    // Note: Actual implementation will use Gowin's rPLL primitives
    pll_hdmi pll_hdmi_inst (
        .clkin(clk_27m),
        .clkout(clk_74m25),
        .lock(pll_locked)
    );
    
    pll_hdmi_x5 pll_hdmi_x5_inst (
        .clkin(clk_27m),
        .clkout(clk_371m25),
        .lock(pll_x5_locked)
    );
    
    pll_core pll_core_inst (
        .clkin(clk_27m),
        .clkout0(clk_96m),
        .clkout1(clk_48m),
        .lock()
    );
    
    pll_audio pll_audio_inst (
        .clkin(clk_27m),
        .clkout(clk_24m576),
        .lock()
    );
    
    // Reset generation
    wire sys_reset_n = reset_n & pll_locked & pll_x5_locked;
    wire core_reset = ~sys_reset_n | rom_loading;
    
    // ========================================================================
    // BL616 I/O System Interface
    // ========================================================================
    
    // Signals for controller input
    wire [15:0] joystick_1;
    wire [15:0] joystick_2;
    
    // Signals for ROM loading
    wire [24:0] rom_addr;
    wire [7:0] rom_data;
    wire rom_wr;
    wire [2:0] rom_type;
    wire rom_start;
    wire rom_busy;
    wire rom_done;
    wire rom_loading;
    
    // UART signals
    wire [7:0] uart_data;
    wire uart_valid;
    wire uart_ready;
    
    // Signals for OSD overlay
    wire osd_enable;
    wire [7:0] osd_r, osd_g, osd_b;
    
    // Instantiate BL616 I/O system
    iosys_bl616 iosys (
        .clk(clk_48m),
        .reset(core_reset),
        
        // UART connection to BL616
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        
        // Controller data
        .joy1(joystick_1),
        .joy2(joystick_2),
        
        // ROM loading interface
        .uart_data(uart_data),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready),
        .rom_type(rom_type),
        .rom_addr(rom_addr),
        .rom_start(rom_start),
        .rom_busy(rom_busy),
        .rom_done(rom_done),
        
        // OSD overlay
        .osd_enable(osd_enable),
        .osd_r(osd_r),
        .osd_g(osd_g),
        .osd_b(osd_b)
    );
    
    // ROM loader
    rom_loader rom_load (
        .clk(clk_48m),
        .reset(core_reset),
        
        // Interface from BL616
        .uart_data(uart_data),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready),
        
        // ROM type and addressing
        .rom_type(rom_type),
        .rom_addr(rom_addr[23:0]),
        .rom_start(rom_start),
        .rom_busy(rom_busy),
        .rom_done(rom_done),
        .rom_loading(rom_loading),
        
        // Interface to SDRAM controller
        .sdram_addr(rom_sdram_addr),
        .sdram_data(rom_sdram_data),
        .sdram_wr(rom_sdram_wr)
    );
    
    // ========================================================================
    // Video Processing
    // ========================================================================
    
    // NeoGeo core video signals (320x224)
    wire [7:0] core_rgb_r, core_rgb_g, core_rgb_b;
    wire core_hs, core_vs;
    wire core_hblank, core_vblank;
    wire core_de = ~(core_hblank | core_vblank);
    
    // OSD overlay signals
    wire [7:0] osd_out_r, osd_out_g, osd_out_b;
    wire osd_out_hs, osd_out_vs, osd_out_de;
    
    // HDMI signals (1280x720)
    wire [7:0] hdmi_r, hdmi_g, hdmi_b;
    wire hdmi_de, hdmi_hs, hdmi_vs;
    
    // OSD overlay
    osd_overlay osd (
        .clk(clk_48m),
        .reset(core_reset),
        
        // Video input from NeoGeo core
        .video_r(core_rgb_r),
        .video_g(core_rgb_g),
        .video_b(core_rgb_b),
        .video_hs(core_hs),
        .video_vs(core_vs),
        .video_de(core_de),
        
        // OSD control from BL616
        .osd_enable(osd_enable),
        .osd_r(osd_r),
        .osd_g(osd_g),
        .osd_b(osd_b),
        
        // Video output with OSD
        .out_r(osd_out_r),
        .out_g(osd_out_g),
        .out_b(osd_out_b),
        .out_hs(osd_out_hs),
        .out_vs(osd_out_vs),
        .out_de(osd_out_de)
    );
    
    // Video scaler to convert 320x224 to 720p with integer scaling (3x)
    video_scaler scaler (
        .clk_in(clk_48m),
        .clk_out(clk_74m25),
        .reset(core_reset),
        
        .in_r(osd_out_r),
        .in_g(osd_out_g),
        .in_b(osd_out_b),
        .in_hs(osd_out_hs),
        .in_vs(osd_out_vs),
        .in_de(hdmi_de),
        
        .out_r(hdmi_r),
        .out_g(hdmi_g),
        .out_b(hdmi_b),
        .out_hs(hdmi_hs),
        .out_vs(hdmi_vs),
        .out_de(hdmi_de)
    );
    
    // HDMI output module
    hdmi_output hdmi_out (
        .clk_pixel(clk_74m25),
        .clk_pixel_x5(clk_371m25),
        .clk_audio(clk_24m576),
        .reset(core_reset),
        
        .in_r(hdmi_r),
        .in_g(hdmi_g),
        .in_b(hdmi_b),
        .in_hs(hdmi_hs),
        .in_vs(hdmi_vs),
        .in_de(hdmi_de),
        
        .audio_l(core_audio_l),
        .audio_r(core_audio_r),
        
        .tmds_p(tmds_p),
        .tmds_n(tmds_n)
    );
    
    // ========================================================================
    // Audio Processing
    // ========================================================================
    
    // Audio signals from NeoGeo core
    wire [15:0] core_audio_l, core_audio_r;
    
    // ========================================================================
    // Memory Interface
    // ========================================================================
    
    // Memory signals from NeoGeo core - Port A (P-ROM, S-ROM)
    wire [24:0] neo_sdram_a_addr;
    wire [15:0] neo_sdram_a_din;
    wire [15:0] neo_sdram_a_dout;
    wire neo_sdram_a_rd, neo_sdram_a_wr;
    wire neo_sdram_a_ready;
    
    // Memory signals from NeoGeo core - Port B (C-ROM)
    wire [24:0] neo_sdram_b_addr;
    wire [15:0] neo_sdram_b_din;
    wire [15:0] neo_sdram_b_dout;
    wire neo_sdram_b_rd, neo_sdram_b_wr;
    wire neo_sdram_b_ready;
    
    // ROM loading signals
    wire [24:0] rom_sdram_addr;
    wire [7:0] rom_sdram_data;
    wire rom_sdram_wr;
    
    // Dual-port SDRAM controller with bank interleaving
    sdram_controller_dual sdram_inst (
        .clk(clk_48m),
        .reset(core_reset),
        
        // Port A interface (primarily for P-ROM, S-ROM)
        .a_addr(neo_sdram_a_addr),
        .a_din(neo_sdram_a_din),
        .a_dout(neo_sdram_a_dout),
        .a_rd(neo_sdram_a_rd),
        .a_wr(neo_sdram_a_wr),
        .a_ready(neo_sdram_a_ready),
        
        // Port B interface (primarily for C-ROM)
        .b_addr(neo_sdram_b_addr),
        .b_din(neo_sdram_b_din),
        .b_dout(neo_sdram_b_dout),
        .b_rd(neo_sdram_b_rd),
        .b_wr(neo_sdram_b_wr),
        .b_ready(neo_sdram_b_ready),
        
        // ROM loading interface
        .rom_addr(rom_sdram_addr),
        .rom_data(rom_sdram_data),
        .rom_wr(rom_sdram_wr),
        
        // Interface to SDRAM chip
        .sdram_clk(sdram_clk),
        .sdram_cke(sdram_cke),
        .sdram_cs_n(sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .sdram_we_n(sdram_we_n),
        .sdram_ba(sdram_ba),
        .sdram_a(sdram_a),
        .sdram_dq(sdram_dq),
        .sdram_dqml(sdram_dqml),
        .sdram_dqmh(sdram_dqmh)
    );
    
    // ========================================================================
    // Input Handling
    // ========================================================================
    
    // NeoGeo controller signals
    wire [7:0] neo_p1;
    wire [7:0] neo_p2;
    wire [7:0] neo_system;
    
    // Input adapter
    input_adapter input_adapt (
        .clk(clk_48m),
        .reset(core_reset),
        
        // Controller inputs from BL616
        .joy1(joystick_1),
        .joy2(joystick_2),
        
        // NeoGeo controller outputs
        .neo_p1(neo_p1),
        .neo_p2(neo_p2),
        .neo_system(neo_system)
    );
    
    // ========================================================================
    // NeoGeo Core Instance
    // ========================================================================
    
    // Replace the placeholder neogeo_core with the actual MiSTer NeoGeo core
    mister_ng_top uut (
        // Clock and reset
        .clk_sys(clk_48m),
        .reset(core_reset),
        
        // Video output
        .VIDEO_R(core_rgb_r),
        .VIDEO_G(core_rgb_g),
        .VIDEO_B(core_rgb_b),
        .HSYNC(core_hs),
        .VSYNC(core_vs),
        .HBLANK(core_hblank),
        .VBLANK(core_vblank),
        .HDMI_DE(hdmi_de),
        
        // Audio output
        .AUDIO_L(core_audio_l),
        .AUDIO_R(core_audio_r),
        
        // SDRAM interface - Port A
        .sdram_addr(neo_sdram_a_addr),
        .sdram_dq(neo_sdram_a_dout),
        .sdram_we(neo_sdram_a_wr),
        .sdram_oe(neo_sdram_a_rd),
        
        // SDRAM interface - Port B (C-ROM)
        .sdram2_addr(neo_sdram_b_addr),
        .sdram2_dq(neo_sdram_b_dout),
        .sdram2_we(neo_sdram_b_wr),
        .sdram2_oe(neo_sdram_b_rd),
        
        // Controller inputs
        .JOYSTICK_1(neo_p1),
        .JOYSTICK_2(neo_p2),
        .SYSTEM(neo_system)
    );
    
    // ========================================================================
    // Debug
    // ========================================================================
    
    // Debug LEDs
    assign leds[0] = pll_locked & pll_x5_locked;
    assign leds[1] = rom_busy;

endmodule
