// Generic stub for altsyncram
// This is a replacement for the Quartus-specific primitive
// with an identical port list but empty body

module altsyncram (
    address_a,
    address_b,
    clock0,
    clock1,
    clocken0,
    clocken1,
    data_a,
    data_b,
    wren_a,
    wren_b,
    q_a,
    q_b
);

    // Parameters (these are all the ones found in the MiSTer NeoGeo core)
    parameter address_aclr_a = "NONE";
    parameter address_aclr_b = "NONE";
    parameter address_reg_b = "CLOCK0";
    parameter byte_size = 8;
    parameter byteena_aclr_a = "NONE";
    parameter byteena_aclr_b = "NONE";
    parameter byteena_reg_a = "CLOCK0";
    parameter byteena_reg_b = "CLOCK0";
    parameter clock_enable_core_a = "USE_INPUT_CLKEN";
    parameter clock_enable_core_b = "USE_INPUT_CLKEN";
    parameter clock_enable_input_a = "BYPASS";
    parameter clock_enable_input_b = "BYPASS";
    parameter clock_enable_output_a = "BYPASS";
    parameter clock_enable_output_b = "BYPASS";
    parameter intended_device_family = "Cyclone V";
    parameter lpm_hint = "ENABLE_RUNTIME_MOD=NO";
    parameter lpm_type = "altsyncram";
    parameter numwords_a = 128;
    parameter numwords_b = 512;
    parameter operation_mode = "DUAL_PORT";
    parameter outdata_aclr_a = "NONE";
    parameter outdata_aclr_b = "NONE";
    parameter outdata_reg_a = "UNREGISTERED";
    parameter outdata_reg_b = "UNREGISTERED";
    parameter power_up_uninitialized = "FALSE";
    parameter ram_block_type = "AUTO";
    parameter read_during_write_mode_mixed_ports = "DONT_CARE";
    parameter read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ";
    parameter read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ";
    parameter widthad_a = 7;
    parameter widthad_b = 9;
    parameter width_a = 64;
    parameter width_b = 16;
    parameter width_byteena_a = 1;
    parameter width_byteena_b = 1;
    parameter init_file = "";

    // Ports
    input [widthad_a-1:0] address_a;
    input [widthad_b-1:0] address_b;
    input clock0;
    input clock1;
    input clocken0;
    input clocken1;
    input [width_a-1:0] data_a;
    input [width_b-1:0] data_b;
    input wren_a;
    input wren_b;
    output [width_a-1:0] q_a;
    output [width_b-1:0] q_b;

    // Internal memory
    reg [width_a-1:0] mem_a [0:numwords_a-1];
    reg [width_b-1:0] mem_b [0:numwords_b-1];
    reg [width_a-1:0] q_a_reg;
    reg [width_b-1:0] q_b_reg;

    // Simple implementation for Tang FPGA
    always @(posedge clock0) begin
        if (wren_a) begin
            mem_a[address_a] <= data_a;
        end
        q_a_reg <= mem_a[address_a];
    end

    always @(posedge clock0) begin
        if (wren_b) begin
            mem_b[address_b] <= data_b;
        end
        q_b_reg <= mem_b[address_b];
    end

    assign q_a = q_a_reg;
    assign q_b = q_b_reg;

endmodule
