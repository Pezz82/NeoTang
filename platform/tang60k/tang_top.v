module tang_top (
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
    wire core_reset = ~sys_reset_n;
    
    // ========================================================================
    // Wishbone Bus Interface
    // ========================================================================
    
    // Wishbone signals for core interface
    wire wb_clk_i = clk_96m;
    wire [31:0] wb_adr_o;
    wire [31:0] wb_dat_i;
    wire [31:0] wb_dat_o;
    wire [3:0] wb_sel_o;
    wire wb_we_o;
    wire wb_stb_o;
    wire wb_cyc_o;
    wire wb_ack_i;
    
    // ========================================================================
    // MCU Mailbox Interface
    // ========================================================================
    
    // Mailbox registers
    reg [31:0] input_reg;     // Current input state
    reg [31:0] command_reg;   // Command FIFO
    
    // UART receiver for MCU commands
    wire [7:0] uart_data;
    wire uart_valid;
    wire uart_ready;
    
    uart_rx uart_receiver (
        .clk(clk_96m),
        .reset(core_reset),
        .rx(uart_rx),
        .data(uart_data),
        .valid(uart_valid),
        .ready(uart_ready)
    );
    
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
        .addr_a(sdram_addr_a),
        .data_in_a(sdram_data_in_a),
        .data_out_a(sdram_data_out_a),
        .req_a(sdram_req_a),
        .we_a(sdram_we_a),
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
    // HDMI Output
    // ========================================================================
    
    // Video signals from core
    wire [7:0] core_rgb_r, core_rgb_g, core_rgb_b;
    wire core_hs, core_vs;
    wire core_hblank, core_vblank;
    wire core_de = ~(core_hblank | core_vblank);
    
    // HDMI signals (1280x720)
    wire [7:0] hdmi_r, hdmi_g, hdmi_b;
    wire hdmi_de, hdmi_hs, hdmi_vs;
    
    // Video scaler to convert 320x224 to 720p with integer scaling (3x)
    video_scaler_3x scaler (
        .clk_in(clk_96m),
        .clk_out(clk_74m25),
        .reset(core_reset),
        
        // Input from core
        .in_r(core_rgb_r),
        .in_g(core_rgb_g),
        .in_b(core_rgb_b),
        .in_hs(core_hs),
        .in_vs(core_vs),
        .in_de(core_de),
        
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
    // Debug
    // ========================================================================
    
    // Debug LEDs
    assign leds[0] = pll_locked & pll_x5_locked;
    assign leds[1] = core_reset;

endmodule 