// NeoGeo Core for Tang 138K - OSD Overlay Module
// This module handles on-screen display overlay

module osd_overlay (
    input wire clk,            // System clock (96 MHz)
    input wire reset,          // System reset
    
    // Video input
    input wire [7:0] video_r,
    input wire [7:0] video_g,
    input wire [7:0] video_b,
    input wire video_hs,
    input wire video_vs,
    input wire video_de,
    
    // OSD control
    input wire osd_enable,
    input wire [7:0] osd_r,
    input wire [7:0] osd_g,
    input wire [7:0] osd_b,
    
    // Video output with OSD
    output reg [7:0] out_r,
    output reg [7:0] out_g,
    output reg [7:0] out_b,
    output reg out_hs,
    output reg out_vs,
    output reg out_de
);
    // OSD position and size
    localparam OSD_X = 160;
    localparam OSD_Y = 120;
    localparam OSD_WIDTH = 320;
    localparam OSD_HEIGHT = 240;
    
    // Counters for position tracking
    reg [10:0] h_count = 0;
    reg [10:0] v_count = 0;
    
    // Sync signals for position tracking
    reg prev_hs = 0;
    reg prev_vs = 0;
    
    // Position tracking
    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
            prev_hs <= 0;
            prev_vs <= 0;
        end else begin
            // Detect horizontal sync falling edge to reset h_count
            if (prev_hs && !video_hs) begin
                h_count <= 0;
                if (v_count < 1023)
                    v_count <= v_count + 1;
            end else if (video_de) begin
                h_count <= h_count + 1;
            end
            
            // Detect vertical sync falling edge to reset v_count
            if (prev_vs && !video_vs) begin
                v_count <= 0;
            end
            
            prev_hs <= video_hs;
            prev_vs <= video_vs;
        end
    end
    
    // OSD overlay
    always @(posedge clk) begin
        if (reset) begin
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
            out_hs <= 0;
            out_vs <= 0;
            out_de <= 0;
        end else begin
            // Pass through sync signals
            out_hs <= video_hs;
            out_vs <= video_vs;
            out_de <= video_de;
            
            // Check if we're in the OSD area
            if (osd_enable && video_de && 
                h_count >= OSD_X && h_count < OSD_X + OSD_WIDTH &&
                v_count >= OSD_Y && v_count < OSD_Y + OSD_HEIGHT) begin
                // In OSD area - use OSD colors
                out_r <= osd_r;
                out_g <= osd_g;
                out_b <= osd_b;
            end else begin
                // Outside OSD area - pass through video
                out_r <= video_r;
                out_g <= video_g;
                out_b <= video_b;
            end
        end
    end

endmodule
