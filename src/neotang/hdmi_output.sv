// NeoGeo Core for Tang 138K - HDMI Module Integration
// This file integrates the hdl-util HDMI module with our video scaler

module hdmi_output (
    input wire clk_pixel,      // 74.25 MHz pixel clock
    input wire clk_pixel_x5,   // 371.25 MHz (5x pixel clock)
    input wire clk_audio,      // 24.576 MHz audio clock
    input wire reset,          // System reset
    
    // Video input (scaled to 1280x720)
    input wire [7:0] in_r,
    input wire [7:0] in_g,
    input wire [7:0] in_b,
    input wire in_hs,
    input wire in_vs,
    input wire in_de,
    
    // Audio input
    input wire [15:0] audio_l,
    input wire [15:0] audio_r,
    
    // HDMI output
    output wire [3:0] tmds_p,
    output wire [3:0] tmds_n
);
    // Pack RGB data
    wire [23:0] rgb = {in_r, in_g, in_b};
    
    // Audio integration
    // Properly connect audio inputs to the audio integration module
    // and ensure correct sample word format for HDMI
    wire [31:0] audio_sample_word;
    wire audio_sample_valid;
    
    // Explicitly connect the audio inputs from the top module
    // to ensure proper audio path through the system
    hdmi_audio_integration audio_integration (
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .reset(reset),
        .audio_l(audio_l),     // Left channel from NeoGeo core
        .audio_r(audio_r),     // Right channel from NeoGeo core
        .audio_sample_word(audio_sample_word),  // 32-bit word {left, right}
        .audio_sample_valid(audio_sample_valid)
    );
    
    // HDMI module instance
    hdmi #(
        .VIDEO_ID_CODE(4),         // 1280x720 @ 60Hz
        .DVI_OUTPUT(0),            // HDMI output (not DVI)
        .VIDEO_REFRESH_RATE(60),
        .AUDIO_RATE(48000),
        .AUDIO_BIT_WIDTH(16)
    ) hdmi_inst (
        .clk_pixel_x5(clk_pixel_x5),
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .reset(reset),
        .rgb(rgb),
        .audio_sample_word(audio_sample_word),
        .audio_sample_valid(audio_sample_valid),
        .tmds(tmds_p),
        .tmds_n(tmds_n),
        .cx(),
        .cy(),
        .frame_width(),
        .frame_height(),
        .hsync(in_hs),
        .vsync(in_vs),
        .data_enable(in_de)
    );

endmodule
