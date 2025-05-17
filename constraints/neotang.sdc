// NeoGeo Core for Tang 138K - Timing Constraints
// This file contains timing constraints for the NeoGeo core port

// Primary clocks
create_clock -name clk_27m -period 37.037 [get_ports {clk_27m}]
create_clock -name clk_74m25 -period 13.468 [get_nets {clk_74m25}]
create_clock -name clk_371m25 -period 2.694 [get_nets {clk_371m25}]
create_clock -name clk_96m -period 10.417 [get_nets {clk_96m}]
create_clock -name clk_24m576 -period 40.690 [get_nets {clk_24m576}]
create_clock -name clk_133m -period 7.519 [get_nets {clk_133m}]

// Clock domain crossings
set_clock_groups -asynchronous \
    -group {clk_27m} \
    -group {clk_74m25 clk_371m25} \
    -group {clk_96m} \
    -group {clk_24m576} \
    -group {clk_133m}

// SDRAM interface timing
set_output_delay -clock clk_133m -max 1.5 [get_ports {sdram_*}]
set_output_delay -clock clk_133m -min 0.5 [get_ports {sdram_*}]
set_input_delay -clock clk_133m -max 1.5 [get_ports {sdram_dq[*]}]
set_input_delay -clock clk_133m -min 0.5 [get_ports {sdram_dq[*]}]

// HDMI output timing
set_output_delay -clock clk_371m25 -max 1.0 [get_ports {tmds_p[*] tmds_n[*]}]
set_output_delay -clock clk_371m25 -min 0.0 [get_ports {tmds_p[*] tmds_n[*]}]

// False paths
set_false_path -from [get_ports {reset_n}]
set_false_path -from [get_ports {uart_rx}]
set_false_path -to [get_ports {uart_tx}]
set_false_path -from [get_ports {bl616_*}]
set_false_path -to [get_ports {bl616_*}]
set_false_path -from [get_ports {joystick_*}]
