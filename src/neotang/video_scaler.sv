// NeoGeo Core for Tang 138K - Video Scaler Module
// This module scales the NeoGeo 320x224 output to 1280x720 for HDMI using integer scaling

module video_scaler (
    input wire clk_in,         // Input clock domain (96 MHz)
    input wire clk_out,        // Output clock domain (74.25 MHz)
    input wire reset,          // System reset
    
    // Input video (320x224)
    input wire [7:0] in_r,
    input wire [7:0] in_g,
    input wire [7:0] in_b,
    input wire in_hs,
    input wire in_vs,
    input wire in_de,
    
    // Output video (1280x720)
    output reg [7:0] out_r,
    output reg [7:0] out_g,
    output reg [7:0] out_b,
    output reg out_hs,
    output reg out_vs,
    output reg out_de
);
    // Integer scaling parameters:
    // - Horizontal: 3x (320 -> 960)
    // - Vertical: 3x (224 -> 672)
    // - Horizontal centering: (1280-960)/2 = 160 pixels left and right borders (pillar boxes)
    // - Vertical centering: (720-672)/2 = 24 pixels top and bottom borders
    
    // Constants for 720p timing (74.25 MHz pixel clock)
    localparam H_ACTIVE = 1280;
    localparam H_FRONT_PORCH = 110;
    localparam H_SYNC = 40;
    localparam H_BACK_PORCH = 220;
    localparam H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH; // 1650
    
    localparam V_ACTIVE = 720;
    localparam V_FRONT_PORCH = 5;
    localparam V_SYNC = 5;
    localparam V_BACK_PORCH = 20;
    localparam V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH; // 750
    
    // NeoGeo scaled dimensions
    localparam NEO_WIDTH = 320;
    localparam NEO_HEIGHT = 224;
    localparam NEO_SCALED_WIDTH = NEO_WIDTH * 3;  // 960
    localparam NEO_SCALED_HEIGHT = NEO_HEIGHT * 3; // 672
    
    // Centering offsets
    localparam H_OFFSET = (H_ACTIVE - NEO_SCALED_WIDTH) / 2;  // 160
    localparam V_OFFSET = (V_ACTIVE - NEO_SCALED_HEIGHT) / 2; // 24
    
    // Counters for 720p timing generation
    reg [10:0] h_count = 0;
    reg [9:0] v_count = 0;
    
    // Signals for 720p timing
    wire h_active = (h_count < H_ACTIVE);
    wire v_active = (v_count < V_ACTIVE);
    wire display_active = h_active && v_active;
    
    // Generate 720p timing
    always @(posedge clk_out) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL-1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end
    
    // Generate 720p sync signals with corrected porch timing
    // Fix off-by-one issue in porch boundaries
    always @(posedge clk_out) begin
        // Horizontal sync - active low
        // Correct exact boundaries for H_SYNC pulse
        out_hs <= ~((h_count >= (H_ACTIVE + H_FRONT_PORCH - 1)) && 
                   (h_count < (H_ACTIVE + H_FRONT_PORCH + H_SYNC - 1)));
        
        // Vertical sync - active low
        // Correct exact boundaries for V_SYNC pulse
        out_vs <= ~((v_count >= (V_ACTIVE + V_FRONT_PORCH - 1)) && 
                   (v_count < (V_ACTIVE + V_FRONT_PORCH + V_SYNC - 1)));
    end
    
    // Frame buffer implementation using Gowin DPRAM primitives
    // For proper clock domain crossing between NeoGeo core and HDMI output
    
    // Line buffer for NeoGeo video lines
    // In actual implementation, this would use Gowin DPRAM primitives
    (* ram_style = "block" *) reg [23:0] line_buffers [0:1][0:NEO_WIDTH-1];
    reg current_write_buffer = 0;
    reg current_read_buffer = 0;
    reg [8:0] write_addr = 0;
    reg [8:0] read_addr = 0;
    reg [1:0] h_scale_count = 0;
    reg [1:0] v_scale_count = 0;
    reg [8:0] neo_h_count = 0;
    reg [8:0] neo_v_count = 0;
    
    // Input side (NeoGeo clock domain)
    reg prev_hs = 0;
    reg prev_vs = 0;
    reg in_active_area = 0;
    
    always @(posedge clk_in) begin
        if (reset) begin
            write_addr <= 0;
            prev_hs <= 0;
            prev_vs <= 0;
            in_active_area <= 0;
            neo_h_count <= 0;
            neo_v_count <= 0;
            current_write_buffer <= 0;
        end else begin
            // Detect horizontal sync falling edge to reset line counters
            if (prev_hs && !in_hs) begin
                write_addr <= 0;
                neo_h_count <= 0;
                
                // Switch buffers at the end of each line
                if (in_active_area) begin
                    current_write_buffer <= ~current_write_buffer;
                }
                
                if (neo_v_count == NEO_HEIGHT-1)
                    neo_v_count <= 0;
                else if (in_active_area)
                    neo_v_count <= neo_v_count + 1;
            end
            
            // Detect vertical sync to reset frame
            if (!prev_vs && in_vs) begin
                neo_v_count <= 0;
                in_active_area <= 1;
                current_write_buffer <= 0;
            end
            
            // Store pixel data when in active display area
            if (in_de) begin
                line_buffers[current_write_buffer][write_addr] <= {in_r, in_g, in_b};
                if (write_addr < NEO_WIDTH-1)
                    write_addr <= write_addr + 1;
                neo_h_count <= neo_h_count + 1;
            end
            
            prev_hs <= in_hs;
            prev_vs <= in_vs;
        end
    end
    
    // Output side (HDMI clock domain)
    reg [23:0] current_pixel;
    reg in_neo_area = 0;
    reg buffer_ready = 0;
    reg line_complete = 0;
    
    always @(posedge clk_out) begin
        if (reset) begin
            read_addr <= 0;
            h_scale_count <= 0;
            v_scale_count <= 0;
            out_de <= 0;
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
            in_neo_area <= 0;
            current_read_buffer <= 0;
            buffer_ready <= 0;
            line_complete <= 0;
        end else begin
            // Determine if we're in the NeoGeo display area (with scaling)
            in_neo_area <= (h_count >= H_OFFSET) && 
                          (h_count < H_OFFSET + NEO_SCALED_WIDTH) && 
                          (v_count >= V_OFFSET) && 
                          (v_count < V_OFFSET + NEO_SCALED_HEIGHT);
            
            // Set display enable
            out_de <= display_active;
            
            // Handle pixel data
            if (display_active) begin
                if (in_neo_area) begin
                    // We're in the NeoGeo display area - output scaled pixel
                    current_pixel <= line_buffers[current_read_buffer][read_addr];
                    out_r <= current_pixel[23:16];
                    out_g <= current_pixel[15:8];
                    out_b <= current_pixel[7:0];
                    
                    // Handle horizontal scaling (3x)
                    h_scale_count <= h_scale_count + 1;
                    if (h_scale_count == 2) begin
                        h_scale_count <= 0;
                        if (read_addr < NEO_WIDTH-1)
                            read_addr <= read_addr + 1;
                        else begin
                            read_addr <= 0;
                            line_complete <= 1;
                        end
                    end
                    
                    // Handle vertical scaling (3x) and line reset
                    if (h_count == H_TOTAL-1) begin
                        if (v_count >= V_OFFSET && v_count < V_OFFSET + NEO_SCALED_HEIGHT) begin
                            v_scale_count <= v_scale_count + 1;
                            if (v_scale_count == 2) begin
                                v_scale_count <= 0;
                                // We've displayed this line 3 times, move to next line
                                current_read_buffer <= ~current_read_buffer;
                                read_addr <= 0;
                            end else begin
                                // Reset to beginning of current line
                                read_addr <= 0;
                            end
                        end
                    end
                end else begin
                    // Outside NeoGeo area - output black (pillar boxes)
                    out_r <= 8'h00;
                    out_g <= 8'h00;
                    out_b <= 8'h00;
                }
            end else begin
                // Outside active display area - output black
                out_r <= 8'h00;
                out_g <= 8'h00;
                out_b <= 8'h00;
                
                // Reset line read at start of horizontal blanking
                if (h_count == H_TOTAL) begin
                    line_complete <= 0;
                    if (v_count == 0) begin
                        // Reset at start of frame
                        read_addr <= 0;
                        h_scale_count <= 0;
                        v_scale_count <= 0;
                        current_read_buffer <= 0;
                    end
                end
            end
        end
    end

    // Note: In the actual implementation, the line_buffers would be replaced with
    // Gowin DPRAM primitives for proper clock domain crossing:
    /*
    // Example of Gowin DPRAM instantiation (would be used in actual implementation)
    Gowin_DPB line_buffer_inst (
        .douta(),              // Not used
        .doutb(pixel_data),    // Output data (HDMI domain)
        .clka(clk_in),         // Input clock (NeoGeo domain)
        .ocea(1'b0),           // Not used
        .cea(1'b1),            // Clock enable
        .reseta(reset),        // Reset
        .wrea(write_enable),   // Write enable
        .clkb(clk_out),        // Output clock (HDMI domain)
        .oceb(1'b1),           // Output clock enable
        .ceb(1'b1),            // Clock enable
        .resetb(reset),        // Reset
        .wreb(1'b0),           // No writing from output side
        .ada(write_addr),      // Write address
        .dina(pixel_in),       // Input data
        .adb(read_addr)        // Read address
    );
    */

endmodule
