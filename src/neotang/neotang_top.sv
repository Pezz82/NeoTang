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
    wire clk_96m;      // 96 MHz for core
    wire pll_locked;   // PLL lock indicator
    
    // Use proven PLL module from TangCore
    pll_27_to_74_96 pll_main (
        .clk_in(clk_27m),
        .clk_74m25(clk_74m25),
        .clk_96m(clk_96m),
        .locked(pll_locked)
    );
    
    // Generate 5x clock for HDMI using Gowin PLL
    wire clk_371m25;   // 371.25 MHz for HDMI serializer
    wire pll_x5_locked;
    
    pll_hdmi_x5 pll_hdmi_x5_inst (
        .clkin(clk_74m25),    // Use 74.25MHz as input
        .clkout(clk_371m25),
        .lock(pll_x5_locked)
    );
    
    // Reset generation with watchdog
    wire watchdog_reset;
    watchdog_reset watchdog (
        .clk(clk_96m),
        .rst_n(reset_n),
        .watchdog_rst(watchdog_reset)
    );
    
    wire sys_reset_n = reset_n & pll_locked & pll_x5_locked & ~watchdog_reset;
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
        .clk(clk_96m),
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
    wire [24:0] rom_sdram_addr;
    wire [7:0] rom_sdram_data;
    wire rom_sdram_wr;
    
    rom_loader rom_load (
        .clk(clk_96m),
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
        .clk(clk_96m),
        .reset(core_reset),
        
        // Video input from NeoGeo core
        .video_r(core_rgb_r),
        .video_g(core_rgb_g),
        .video_b(core_rgb_b),
        .video_hs(core_hs),
        .video_vs(core_vs),
        .video_de(core_de),
        
        // OSD overlay input
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
    video_scaler_3x scaler (
        .clk_in(clk_96m),
        .clk_out(clk_74m25),
        .reset(core_reset),
        
        // Input from OSD overlay
        .in_r(osd_out_r),
        .in_g(osd_out_g),
        .in_b(osd_out_b),
        .in_hs(osd_out_hs),
        .in_vs(osd_out_vs),
        .in_de(osd_out_de),
        
        // Output to HDMI
        .out_r(hdmi_r),
        .out_g(hdmi_g),
        .out_b(hdmi_b),
        .out_hs(hdmi_hs),
        .out_vs(hdmi_vs),
        .out_de(hdmi_de)
    );
    
    // HDMI output
    hdmi_output hdmi (
        .clk_pixel(clk_74m25),
        .clk_5x_pixel(clk_371m25),
        .reset(core_reset),
        
        // Video input
        .rgb_in({hdmi_r, hdmi_g, hdmi_b}),
        .hs_in(hdmi_hs),
        .vs_in(hdmi_vs),
        .de_in(hdmi_de),
        
        // TMDS output
        .tmds_p(tmds_p),
        .tmds_n(tmds_n)
    );
    
    // ========================================================================
    // Audio Processing
    // ========================================================================
    
    // Audio signals from NeoGeo core
    wire [15:0] core_audio_l, core_audio_r;
    
    // ========================================================================
    // SDRAM Controller
    // ========================================================================
    
    // SDRAM signals for port A (ROM loading)
    wire [22:0] sdram_addr_a;
    wire [15:0] sdram_data_in_a;
    wire [15:0] sdram_data_out_a;
    wire sdram_req_a;
    wire sdram_ack_a;
    wire sdram_valid_a;
    wire sdram_we_a;
    
    // SDRAM signals for port B (Core access)
    wire [22:0] sdram_addr_b;
    wire [15:0] sdram_data_in_b;
    wire [15:0] sdram_data_out_b;
    wire sdram_req_b;
    wire sdram_ack_b;
    wire sdram_valid_b;
    wire sdram_we_b;
    
    // Cache line for sprite data to prevent tearing
    wire [22:0] cache_addr;
    wire [15:0] cache_data;
    wire cache_req;
    wire cache_ack;
    wire cache_valid;
    
    sdram_cache_line sprite_cache (
        .clk(clk_96m),
        .reset(core_reset),
        
        // Core interface
        .addr_in(sdram_addr_b),
        .data_out(cache_data),
        .req_in(sdram_req_b),
        .ack_out(cache_ack),
        .valid_out(cache_valid),
        
        // SDRAM interface
        .addr_out(cache_addr),
        .data_in(sdram_data_out_b),
        .req_out(cache_req),
        .ack_in(sdram_ack_b),
        .valid_in(sdram_valid_b)
    );
    
    // Dual-port SDRAM controller with bank interleaving
    sdram_dualport sdram_inst (
        .clk(clk_96m),
        .reset(core_reset),
        
        // Port A - ROM loading
        .addr_a(rom_sdram_addr),
        .data_in_a({8'h0, rom_sdram_data}),
        .data_out_a(sdram_data_out_a),
        .req_a(rom_sdram_wr),
        .we_a(rom_sdram_wr),
        .ack_a(sdram_ack_a),
        .valid_a(sdram_valid_a),
        
        // Port B - Core access (through cache)
        .addr_b(cache_addr),
        .data_in_b(sdram_data_in_b),
        .data_out_b(sdram_data_out_b),
        .req_b(cache_req),
        .we_b(sdram_we_b),
        .ack_b(sdram_ack_b),
        .valid_b(sdram_valid_b),
        
        // SDRAM interface
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
        .clk(clk_96m),
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
        .clk_sys(clk_96m),
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
