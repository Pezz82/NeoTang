// ------------------------------------------------------------
// Black-box stub for Gowin PLL (rPLL) – Yosys will ignore implementation
(* blackbox *) module PLL (
    input clkin, 
    output clkout, 
    output lock
    /* + any additional outputs as needed */
);
    parameter FCLKIN = "27";   // e.g. 27 MHz input
    parameter IDIV_SEL = 0, FBDIV_SEL = 0, ODIV_SEL = 0;
    parameter DVRR_SEL = 0, DUTY_SEL = 0, PHASE_SEL = 0;
endmodule 