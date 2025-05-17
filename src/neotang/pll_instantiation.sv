// NeoGeo Core for Tang 138K - PLL Instantiation Module
// This module instantiates the Gowin rPLL primitives for clock generation

module pll_instantiation (
    input wire clk_27m,        // 27 MHz input clock
    input wire reset_n,        // Active low reset
    
    output wire clk_74m25,     // 74.25 MHz pixel clock for HDMI
    output wire clk_371m25,    // 371.25 MHz (5x pixel clock) for HDMI serializer
    output wire clk_96m,       // 96 MHz system clock for NeoGeo core
    output wire clk_24m576,    // 24.576 MHz audio clock (48kHz * 512)
    output wire clk_133m,      // 133 MHz SDRAM clock
    
    output wire pll_locked     // PLL locked signal
);
    // PLL lock signals
    wire pll_video_locked;
    wire pll_video_x5_locked;
    wire pll_system_locked;
    wire pll_audio_locked;
    wire pll_sdram_locked;
    
    // Combined lock signal
    assign pll_locked = pll_video_locked & pll_video_x5_locked & pll_system_locked & pll_audio_locked & pll_sdram_locked;
    
    // Video PLL for HDMI pixel clock (74.25 MHz)
    Gowin_rPLL video_pll (
        .clkout(clk_74m25),    // 74.25 MHz
        .lock(pll_video_locked),
        .reset(~reset_n),
        .clkin(clk_27m)        // 27 MHz input
    );
    
    // HDMI serializer PLL (5x pixel clock = 371.25 MHz)
    Gowin_rPLL_x5 video_x5_pll (
        .clkout(clk_371m25),   // 371.25 MHz
        .lock(pll_video_x5_locked),
        .reset(~reset_n),
        .clkin(clk_74m25)      // 74.25 MHz input
    );
    
    // System PLL for NeoGeo core (96 MHz)
    Gowin_rPLL_sys system_pll (
        .clkout(clk_96m),      // 96 MHz
        .lock(pll_system_locked),
        .reset(~reset_n),
        .clkin(clk_27m)        // 27 MHz input
    );
    
    // Audio PLL for 48kHz audio (24.576 MHz = 48kHz * 512)
    Gowin_rPLL_audio audio_pll (
        .clkout(clk_24m576),   // 24.576 MHz
        .lock(pll_audio_locked),
        .reset(~reset_n),
        .clkin(clk_27m)        // 27 MHz input
    );
    
    // SDRAM PLL for memory controller (133 MHz)
    Gowin_rPLL_sdram sdram_pll (
        .clkout(clk_133m),     // 133 MHz
        .lock(pll_sdram_locked),
        .reset(~reset_n),
        .clkin(clk_27m)        // 27 MHz input
    );
    
endmodule

// Gowin rPLL primitive for 74.25 MHz (HDMI pixel clock)
module Gowin_rPLL (
    output wire clkout,
    output wire lock,
    input wire reset,
    input wire clkin
);
    // PLL parameters for 74.25 MHz from 27 MHz
    // FBDIV = 22, IDIV = 8, ODIV = 1
    // Fout = Fin * (FBDIV+1) / (IDIV+1) / (ODIV+1)
    // 74.25 MHz = 27 MHz * 22 / 8 / 1
    
    rPLL #(
        .FCLKIN("27"),         // Input clock frequency (MHz)
        .IDIV_SEL(7),          // IDIV = 8 (value is IDIV-1)
        .FBDIV_SEL(21),        // FBDIV = 22 (value is FBDIV-1)
        .ODIV_SEL(1),          // ODIV = 1 (value is ODIV)
        .DYN_SDIV_SEL(2),      // Dynamic SDIV
        .PSDA_SEL("0000")      // Phase shift
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(reset),
        .RESET_P(1'b0),
        .CLKIN(clkin),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );
endmodule

// Gowin rPLL primitive for 371.25 MHz (HDMI serializer clock)
module Gowin_rPLL_x5 (
    output wire clkout,
    output wire lock,
    input wire reset,
    input wire clkin
);
    // PLL parameters for 371.25 MHz from 74.25 MHz
    // FBDIV = 4, IDIV = 0, ODIV = 1
    // Fout = Fin * (FBDIV+1) / (IDIV+1) / (ODIV+1)
    // 371.25 MHz = 74.25 MHz * 5 / 1 / 1
    
    rPLL #(
        .FCLKIN("74.25"),      // Input clock frequency (MHz)
        .IDIV_SEL(0),          // IDIV = 1 (value is IDIV-1)
        .FBDIV_SEL(4),         // FBDIV = 5 (value is FBDIV-1)
        .ODIV_SEL(1),          // ODIV = 1 (value is ODIV)
        .DYN_SDIV_SEL(2),      // Dynamic SDIV
        .PSDA_SEL("0000")      // Phase shift
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(reset),
        .RESET_P(1'b0),
        .CLKIN(clkin),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );
endmodule

// Gowin rPLL primitive for 96 MHz (system clock)
module Gowin_rPLL_sys (
    output wire clkout,
    output wire lock,
    input wire reset,
    input wire clkin
);
    // PLL parameters for 96 MHz from 27 MHz
    // FBDIV = 31, IDIV = 8, ODIV = 1
    // Fout = Fin * (FBDIV+1) / (IDIV+1) / (ODIV+1)
    // 96.75 MHz = 27 MHz * 32 / 9 / 1
    
    rPLL #(
        .FCLKIN("27"),         // Input clock frequency (MHz)
        .IDIV_SEL(8),          // IDIV = 9 (value is IDIV-1)
        .FBDIV_SEL(31),        // FBDIV = 32 (value is FBDIV-1)
        .ODIV_SEL(1),          // ODIV = 1 (value is ODIV)
        .DYN_SDIV_SEL(2),      // Dynamic SDIV
        .PSDA_SEL("0000")      // Phase shift
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(reset),
        .RESET_P(1'b0),
        .CLKIN(clkin),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );
endmodule

// Gowin rPLL primitive for 24.576 MHz (audio clock)
module Gowin_rPLL_audio (
    output wire clkout,
    output wire lock,
    input wire reset,
    input wire clkin
);
    // PLL parameters for 24.576 MHz from 27 MHz
    // FBDIV = 36, IDIV = 39, ODIV = 1
    // Fout = Fin * (FBDIV+1) / (IDIV+1) / (ODIV+1)
    // 24.576 MHz = 27 MHz * 37 / 40 / 1
    
    rPLL #(
        .FCLKIN("27"),         // Input clock frequency (MHz)
        .IDIV_SEL(39),         // IDIV = 40 (value is IDIV-1)
        .FBDIV_SEL(36),        // FBDIV = 37 (value is FBDIV-1)
        .ODIV_SEL(1),          // ODIV = 1 (value is ODIV)
        .DYN_SDIV_SEL(2),      // Dynamic SDIV
        .PSDA_SEL("0000")      // Phase shift
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(reset),
        .RESET_P(1'b0),
        .CLKIN(clkin),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );
endmodule

// Gowin rPLL primitive for 133 MHz (SDRAM clock)
module Gowin_rPLL_sdram (
    output wire clkout,
    output wire lock,
    input wire reset,
    input wire clkin
);
    // PLL parameters for 133 MHz from 27 MHz
    // FBDIV = 39, IDIV = 7, ODIV = 1
    // Fout = Fin * (FBDIV+1) / (IDIV+1) / (ODIV+1)
    // 135 MHz = 27 MHz * 40 / 8 / 1
    
    rPLL #(
        .FCLKIN("27"),         // Input clock frequency (MHz)
        .IDIV_SEL(7),          // IDIV = 8 (value is IDIV-1)
        .FBDIV_SEL(39),        // FBDIV = 40 (value is FBDIV-1)
        .ODIV_SEL(1),          // ODIV = 1 (value is ODIV)
        .DYN_SDIV_SEL(2),      // Dynamic SDIV
        .PSDA_SEL("0000")      // Phase shift
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(reset),
        .RESET_P(1'b0),
        .CLKIN(clkin),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );
endmodule
