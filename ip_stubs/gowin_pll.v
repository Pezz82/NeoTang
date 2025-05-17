module Gowin_PLL (
    input  wire clkin,
    output wire clkout0,
    output wire clkout1,
    output wire lock
);

    // Stub implementation
    assign clkout0 = clkin;
    assign clkout1 = clkin;
    assign lock = 1'b1;

endmodule 