// NeoGeo Core for Tang 138K - Audio I2S Module
// This module handles I2S audio signal generation for HDMI

module audio_i2s (
    input wire clk_audio,      // 24.576 MHz audio clock
    input wire reset,          // System reset
    
    // Audio input
    input wire [15:0] audio_l,
    input wire [15:0] audio_r,
    
    // I2S output
    output reg sdata,          // Serial data
    output reg sclk,           // Serial clock (3.072 MHz)
    output reg lrclk           // Left/right clock (48 kHz)
);
    // I2S parameters
    // Audio clock: 24.576 MHz
    // SCLK: 24.576 MHz / 8 = 3.072 MHz
    // LRCLK: 3.072 MHz / 64 = 48 kHz
    
    localparam SCLK_DIVIDER = 8;
    localparam LRCLK_DIVIDER = 64;
    
    // Counters
    reg [3:0] sclk_counter = 0;
    reg [6:0] lrclk_counter = 0;
    
    // Audio shift registers
    reg [15:0] audio_l_shift;
    reg [15:0] audio_r_shift;
    
    // Generate SCLK (3.072 MHz)
    always @(posedge clk_audio) begin
        if (reset) begin
            sclk_counter <= 0;
            sclk <= 0;
        end else begin
            if (sclk_counter == SCLK_DIVIDER/2 - 1) begin
                sclk <= ~sclk;
                sclk_counter <= 0;
            end else begin
                sclk_counter <= sclk_counter + 1;
            end
        end
    end
    
    // Generate LRCLK (48 kHz) and handle audio data
    always @(posedge sclk) begin
        if (reset) begin
            lrclk_counter <= 0;
            lrclk <= 0;
            audio_l_shift <= 0;
            audio_r_shift <= 0;
            sdata <= 0;
        end else begin
            // Update LRCLK counter
            if (lrclk_counter == LRCLK_DIVIDER - 1) begin
                lrclk_counter <= 0;
                lrclk <= ~lrclk;
                
                // Load new audio samples at the start of each frame
                if (lrclk == 1) begin  // Transition from right to left
                    audio_l_shift <= audio_l;
                    audio_r_shift <= audio_r;
                end
            end else begin
                lrclk_counter <= lrclk_counter + 1;
            end
            
            // Shift out audio data
            if (lrclk == 0) begin  // Left channel
                sdata <= audio_l_shift[15];
                audio_l_shift <= {audio_l_shift[14:0], 1'b0};
            end else begin         // Right channel
                sdata <= audio_r_shift[15];
                audio_r_shift <= {audio_r_shift[14:0], 1'b0};
            end
        end
    end

endmodule
