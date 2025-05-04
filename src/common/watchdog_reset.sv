module watchdog_reset #(
    parameter TIME_500MS = 1
)(
    input  wire clk,
    input  wire vsync,
    input  wire ext_reset,
    output wire sys_reset
);

    // Counter for 500ms timeout
    localparam TIMEOUT = TIME_500MS ? 27'd13_500_000 : 27'd1_350_000;  // 500ms or 50ms at 27MHz
    
    reg [26:0] counter;
    reg vsync_prev;
    wire vsync_edge;
    
    // Detect vsync edge
    assign vsync_edge = vsync && !vsync_prev;
    
    always_ff @(posedge clk) begin
        vsync_prev <= vsync;
        
        if (vsync_edge)
            counter <= 0;
        else if (counter < TIMEOUT)
            counter <= counter + 1;
    end
    
    // Generate reset
    assign sys_reset = ext_reset || (counter >= TIMEOUT);

endmodule 