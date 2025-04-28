// NeoGeo Core for Tang 138K - Input Adapter Module
// This module adapts controller inputs to NeoGeo format

module input_adapter (
    input wire clk,            // System clock (96 MHz)
    input wire reset,          // System reset
    
    // Controller inputs from BL616
    input wire [15:0] joy1,    // Joystick 1 data
    input wire [15:0] joy2,    // Joystick 2 data
    
    // NeoGeo controller outputs
    output reg [7:0] neo_p1,   // Player 1 controls
    output reg [7:0] neo_p2,   // Player 2 controls
    output reg [7:0] neo_system // System controls
);
    // NeoGeo controller bit mapping
    // P1/P2: [7:0] = {Button D, Button C, Button B, Button A, Right, Left, Down, Up}
    // System: [7:0] = {Test, Service, Coin 2, Coin 1, P2 Start, P1 Start, Dipswitch 2, Dipswitch 1}
    
    // Tang controller bit mapping (standard)
    // [15:0] = {L3, R3, Select, Start, R2, L2, R1, L1, Right, Left, Down, Up, Triangle, Circle, Cross, Square}
    // Map to NeoGeo as follows:
    // Square (0) -> Button A
    // Cross (1) -> Button B
    // Circle (2) -> Button C
    // Triangle (3) -> Button D
    // D-pad -> D-pad
    // Start -> Start
    // Select -> Coin
    // L1 -> Test
    // R1 -> Service
    
    always @(posedge clk) begin
        if (reset) begin
            neo_p1 <= 8'hFF;  // Active low
            neo_p2 <= 8'hFF;  // Active low
            neo_system <= 8'hFF;  // Active low
        end else begin
            // Player 1 controls (active low)
            neo_p1[0] <= ~joy1[4];  // Up
            neo_p1[1] <= ~joy1[5];  // Down
            neo_p1[2] <= ~joy1[6];  // Left
            neo_p1[3] <= ~joy1[7];  // Right
            neo_p1[4] <= ~joy1[0];  // Button A (Square)
            neo_p1[5] <= ~joy1[1];  // Button B (Cross)
            neo_p1[6] <= ~joy1[2];  // Button C (Circle)
            neo_p1[7] <= ~joy1[3];  // Button D (Triangle)
            
            // Player 2 controls (active low)
            neo_p2[0] <= ~joy2[4];  // Up
            neo_p2[1] <= ~joy2[5];  // Down
            neo_p2[2] <= ~joy2[6];  // Left
            neo_p2[3] <= ~joy2[7];  // Right
            neo_p2[4] <= ~joy2[0];  // Button A (Square)
            neo_p2[5] <= ~joy2[1];  // Button B (Cross)
            neo_p2[6] <= ~joy2[2];  // Button C (Circle)
            neo_p2[7] <= ~joy2[3];  // Button D (Triangle)
            
            // System controls (active low)
            neo_system[0] <= 1'b0;  // Dipswitch 1 (always on)
            neo_system[1] <= 1'b0;  // Dipswitch 2 (always on)
            neo_system[2] <= ~joy1[9];  // P1 Start
            neo_system[3] <= ~joy2[9];  // P2 Start
            neo_system[4] <= ~joy1[8];  // Coin 1 (P1 Select)
            neo_system[5] <= ~joy2[8];  // Coin 2 (P2 Select)
            neo_system[6] <= ~joy1[11]; // Service (P1 R1)
            neo_system[7] <= ~joy1[10]; // Test (P1 L1)
        end
    end

endmodule
