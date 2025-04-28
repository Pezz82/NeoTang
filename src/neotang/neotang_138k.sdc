// NeoGeo Core for Tang 138K - Timing Constraints File
// This file provides timing constraints for the NeoGeo core on Tang 138K

// Clock definitions
create_clock -name clk_27m -period 37.037 [get_ports {clk_27m}]
create_clock -name clk_74m25 -period 13.468 [get_nets {clk_74m25}]
create_clock -name clk_371m25 -period 2.694 [get_nets {clk_371m25}]
create_clock -name clk_133m -period 7.519 [get_nets {clk_133m}]
create_clock -name clk_24m576 -period 40.690 [get_nets {clk_24m576}]

// Clock relationships
set_clock_groups -asynchronous \
    -group {clk_27m} \
    -group {clk_74m25 clk_371m25} \
    -group {clk_133m} \
    -group {clk_24m576}

// HDMI TMDS output constraints
set_output_delay -clock clk_371m25 -max 1.0 [get_ports {hdmi_clk_p hdmi_clk_n hdmi_data_p* hdmi_data_n*}]
set_output_delay -clock clk_371m25 -min 0.5 [get_ports {hdmi_clk_p hdmi_clk_n hdmi_data_p* hdmi_data_n*}]

// SDRAM interface constraints
set_output_delay -clock clk_133m -max 1.5 [get_ports {sdram_*}]
set_output_delay -clock clk_133m -min 0.5 [get_ports {sdram_*}]
set_input_delay -clock clk_133m -max 1.5 [get_ports {sdram_dq*}]
set_input_delay -clock clk_133m -min 0.5 [get_ports {sdram_dq*}]

// UART interface constraints
set_input_delay -clock clk_27m -max 2.0 [get_ports {uart_rx}]
set_output_delay -clock clk_27m -max 2.0 [get_ports {uart_tx}]

// False paths
set_false_path -from [get_clocks {clk_27m}] -to [get_clocks {clk_74m25}]
set_false_path -from [get_clocks {clk_74m25}] -to [get_clocks {clk_27m}]
set_false_path -from [get_clocks {clk_133m}] -to [get_clocks {clk_74m25}]
set_false_path -from [get_clocks {clk_74m25}] -to [get_clocks {clk_133m}]
set_false_path -from [get_clocks {clk_24m576}] -to [get_clocks {clk_74m25}]
set_false_path -from [get_clocks {clk_74m25}] -to [get_clocks {clk_24m576}]
