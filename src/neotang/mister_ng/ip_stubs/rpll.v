// Black-box stub for Gowin rPLL primitive so Yosys will ignore
// vendor implementation during open-source synthesis.
// ------------------------------------------------------------
(* blackbox *)
module rPLL
#(
    parameter FCLKIN = "27",
    parameter IDIV_SEL = 0,
    parameter FBCLK_SEL = "internal",
    parameter O0_DIV_SEL = 6,
    parameter O0_PHASE_SEL = 0,
    parameter O1_DIV_SEL = 1,
    parameter O1_PHASE_SEL = 0,
    parameter O2_DIV_SEL = 1,
    parameter O2_PHASE_SEL = 0
)
(
    input  wire clkin,
    input  wire reset,
    output wire clkoutp,
    output wire clkoutd,
    output wire clkoutd3,
    output wire lock
);
endmodule 