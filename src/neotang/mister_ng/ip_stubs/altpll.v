// Generic stub for altpll
// This is a replacement for the Quartus-specific primitive
// with an identical port list but empty body

module altpll (
    inclk,
    clk,
    locked,
    activeclock,
    areset,
    clkbad,
    clkena,
    clkloss,
    clkswitch,
    configupdate,
    enable0,
    enable1,
    extclk,
    extclkena,
    fbin,
    fbmimicbidir,
    fbout,
    fref,
    icdrclk,
    pfdena,
    phasecounterselect,
    phasedone,
    phasestep,
    phaseupdown,
    scanclk,
    scanclkena,
    scandata,
    scandataout,
    scandone,
    sclkout0,
    sclkout1,
    vcooverrange,
    vcounderrange
);

    // Parameters
    parameter bandwidth_type = "AUTO";
    parameter clk0_divide_by = 1;
    parameter clk0_duty_cycle = 50;
    parameter clk0_multiply_by = 1;
    parameter clk0_phase_shift = "0";
    parameter clk1_divide_by = 1;
    parameter clk1_duty_cycle = 50;
    parameter clk1_multiply_by = 1;
    parameter clk1_phase_shift = "0";
    parameter clk2_divide_by = 1;
    parameter clk2_duty_cycle = 50;
    parameter clk2_multiply_by = 1;
    parameter clk2_phase_shift = "0";
    parameter clk3_divide_by = 1;
    parameter clk3_duty_cycle = 50;
    parameter clk3_multiply_by = 1;
    parameter clk3_phase_shift = "0";
    parameter clk4_divide_by = 1;
    parameter clk4_duty_cycle = 50;
    parameter clk4_multiply_by = 1;
    parameter clk4_phase_shift = "0";
    parameter compensate_clock = "CLK0";
    parameter inclk0_input_frequency = 10000;
    parameter intended_device_family = "Cyclone V";
    parameter lpm_hint = "CBX_MODULE_PREFIX=pll";
    parameter lpm_type = "altpll";
    parameter operation_mode = "NORMAL";
    parameter pll_type = "AUTO";
    parameter port_activeclock = "PORT_UNUSED";
    parameter port_areset = "PORT_UNUSED";
    parameter port_clkbad0 = "PORT_UNUSED";
    parameter port_clkbad1 = "PORT_UNUSED";
    parameter port_clkloss = "PORT_UNUSED";
    parameter port_clkswitch = "PORT_UNUSED";
    parameter port_configupdate = "PORT_UNUSED";
    parameter port_fbin = "PORT_UNUSED";
    parameter port_inclk0 = "PORT_USED";
    parameter port_inclk1 = "PORT_UNUSED";
    parameter port_locked = "PORT_USED";
    parameter port_pfdena = "PORT_UNUSED";
    parameter port_phasecounterselect = "PORT_UNUSED";
    parameter port_phasedone = "PORT_UNUSED";
    parameter port_phasestep = "PORT_UNUSED";
    parameter port_phaseupdown = "PORT_UNUSED";
    parameter port_pllena = "PORT_UNUSED";
    parameter port_scanaclr = "PORT_UNUSED";
    parameter port_scanclk = "PORT_UNUSED";
    parameter port_scanclkena = "PORT_UNUSED";
    parameter port_scandata = "PORT_UNUSED";
    parameter port_scandataout = "PORT_UNUSED";
    parameter port_scandone = "PORT_UNUSED";
    parameter port_scanread = "PORT_UNUSED";
    parameter port_scanwrite = "PORT_UNUSED";
    parameter port_clk0 = "PORT_USED";
    parameter port_clk1 = "PORT_USED";
    parameter port_clk2 = "PORT_USED";
    parameter port_clk3 = "PORT_USED";
    parameter port_clk4 = "PORT_USED";
    parameter port_clk5 = "PORT_UNUSED";
    parameter port_clkena0 = "PORT_UNUSED";
    parameter port_clkena1 = "PORT_UNUSED";
    parameter port_clkena2 = "PORT_UNUSED";
    parameter port_clkena3 = "PORT_UNUSED";
    parameter port_clkena4 = "PORT_UNUSED";
    parameter port_clkena5 = "PORT_UNUSED";
    parameter port_extclk0 = "PORT_UNUSED";
    parameter port_extclk1 = "PORT_UNUSED";
    parameter port_extclk2 = "PORT_UNUSED";
    parameter port_extclk3 = "PORT_UNUSED";
    parameter self_reset_on_loss_lock = "OFF";
    parameter width_clock = 5;
    parameter width_phasecounterselect = 3;

    // Input ports
    input [1:0] inclk;
    input areset;
    input clkswitch;
    input [width_clock-1:0] clkena;
    input configupdate;
    input enable0;
    input enable1;
    input [width_clock-1:0] extclkena;
    input fbin;
    input [width_phasecounterselect-1:0] phasecounterselect;
    input phasestep;
    input phaseupdown;
    input pfdena;
    input scanclk;
    input scanclkena;
    input scandata;
    
    // Output ports
    output [width_clock-1:0] clk;
    output [width_clock-1:0] extclk;
    output [1:0] clkbad;
    output activeclock;
    output locked;
    output clkloss;
    output phasedone;
    output scandataout;
    output scandone;
    output sclkout0;
    output sclkout1;
    output fbmimicbidir;
    output fbout;
    output fref;
    output icdrclk;
    output vcooverrange;
    output vcounderrange;

    // Simple implementation for Tang FPGA
    // Just pass through the reference clock to all outputs
    assign clk[0] = inclk[0];
    assign clk[1] = inclk[0];
    assign clk[2] = inclk[0];
    assign clk[3] = inclk[0];
    assign clk[4] = inclk[0];
    assign locked = ~areset;
    assign extclk = 0;
    assign clkbad = 0;
    assign activeclock = 0;
    assign clkloss = 0;
    assign phasedone = 0;
    assign scandataout = 0;
    assign scandone = 0;
    assign sclkout0 = 0;
    assign sclkout1 = 0;
    assign fbmimicbidir = 0;
    assign fbout = 0;
    assign fref = 0;
    assign icdrclk = 0;
    assign vcooverrange = 0;
    assign vcounderrange = 0;

endmodule
