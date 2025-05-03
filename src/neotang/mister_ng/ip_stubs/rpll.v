// Stub for Gowin rPLL primitive
module rPLL (
    input wire clkin,      // Input clock
    output wire clkout,    // Output clock
    output wire clkout0,   // Output clock 0 (optional)
    output wire clkout1,   // Output clock 1 (optional)
    output wire lock       // PLL lock indicator
);
    // Simple pass-through for simulation
    assign clkout = clkin;
    assign clkout0 = clkin;
    assign clkout1 = clkin;
    assign lock = 1'b1;
endmodule 