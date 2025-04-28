// NeoGeo Core for Tang 138K - HDMI Audio Integration Module
// This module handles audio integration with HDMI output

module hdmi_audio_integration (
    input wire clk_pixel,      // Pixel clock (74.25 MHz)
    input wire clk_audio,      // Audio clock (24.576 MHz for 48kHz audio)
    input wire reset,          // System reset
    
    // Audio input from NeoGeo core
    input wire signed [15:0] audio_l,  // Left channel audio from core
    input wire signed [15:0] audio_r,  // Right channel audio from core
    
    // Audio output to HDMI module
    output reg [31:0] audio_sample_word, // Combined audio sample for HDMI (L+R)
    output reg audio_sample_valid        // Audio sample valid signal
);
    // Audio sample rate conversion (from NeoGeo to 48kHz)
    reg [15:0] audio_l_buf;
    reg [15:0] audio_r_buf;
    reg [15:0] audio_l_sync;
    reg [15:0] audio_r_sync;
    
    // Audio clock domain crossing
    reg [2:0] audio_sample_count;
    reg audio_sample_ready;
    
    // Synchronize audio from core clock to audio clock domain
    always @(posedge clk_audio) begin
        if (reset) begin
            audio_l_buf <= 0;
            audio_r_buf <= 0;
            audio_l_sync <= 0;
            audio_r_sync <= 0;
        end else begin
            // Double buffer to avoid metastability
            audio_l_buf <= audio_l;
            audio_r_buf <= audio_r;
            audio_l_sync <= audio_l_buf;
            audio_r_sync <= audio_r_buf;
        end
    end
    
    // Generate 48kHz audio samples
    always @(posedge clk_audio) begin
        if (reset) begin
            audio_sample_count <= 0;
            audio_sample_ready <= 0;
        end else begin
            // 24.576 MHz / 512 = 48 kHz
            if (audio_sample_count == 3'd7) begin
                audio_sample_count <= 0;
                audio_sample_ready <= 1;
            end else begin
                audio_sample_count <= audio_sample_count + 1;
                audio_sample_ready <= 0;
            end
        end
    end
    
    // Synchronize audio sample ready to pixel clock domain
    reg audio_ready_buf;
    reg audio_ready_sync;
    
    always @(posedge clk_pixel) begin
        if (reset) begin
            audio_ready_buf <= 0;
            audio_ready_sync <= 0;
        end else begin
            audio_ready_buf <= audio_sample_ready;
            audio_ready_sync <= audio_ready_buf;
        end
    end
    
    // Generate audio sample word for HDMI
    always @(posedge clk_pixel) begin
        if (reset) begin
            audio_sample_word <= 0;
            audio_sample_valid <= 0;
        end else begin
            // When a new audio sample is ready
            if (audio_ready_sync) begin
                // Combine left and right channels into a single 32-bit word
                // Format: {left_channel[15:0], right_channel[15:0]}
                audio_sample_word <= {audio_l_sync, audio_r_sync};
                audio_sample_valid <= 1;
            end else begin
                audio_sample_valid <= 0;
            end
        end
    end
endmodule
