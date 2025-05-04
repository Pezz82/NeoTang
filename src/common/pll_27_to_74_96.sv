module pll_27_to_74_96 (
    input  wire clk_in,
    output wire clk74,
    output wire clk96,
    output wire locked
);

    // PLL parameters
    parameter CLKIN_PERIOD = 37.037;  // 27MHz
    parameter CLKOUT0_DIVIDE = 4;     // 74.25MHz
    parameter CLKOUT1_DIVIDE = 3;     // 96MHz

    // PLL primitive
    Gowin_PLL pll_inst (
        .clkout0(clk74),
        .clkout1(clk96),
        .lock(locked),
        .clkin(clk_in)
    );

    defparam pll_inst.CLKIN_PERIOD = CLKIN_PERIOD;
    defparam pll_inst.CLKOUT0_DIVIDE = CLKOUT0_DIVIDE;
    defparam pll_inst.CLKOUT1_DIVIDE = CLKOUT1_DIVIDE;

endmodule 