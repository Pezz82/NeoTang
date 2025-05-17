// NeoGeo Core for Tang 138K - BL616 I/O System Interface
// This module handles communication with the BL616 microcontroller

module iosys_bl616 (
    input wire clk,            // System clock (96 MHz)
    input wire reset,          // System reset
    
    // UART connection to BL616
    input wire uart_rx,        // UART RX from BL616
    output wire uart_tx,       // UART TX to BL616
    
    // Controller data
    output reg [15:0] joy1,    // Joystick 1 data
    output reg [15:0] joy2,    // Joystick 2 data
    
    // ROM loading interface
    output reg [7:0] uart_data,  // Data from UART
    output reg uart_valid,       // Data valid signal
    input wire uart_ready,       // Ready to receive data
    output reg [2:0] rom_type,   // ROM type
    output reg [24:0] rom_addr,  // ROM address
    output reg rom_start,        // Start loading signal
    input wire rom_busy,         // ROM loading in progress
    
    // OSD overlay
    output reg osd_enable,     // OSD enable
    output reg [7:0] osd_r,    // OSD red component
    output reg [7:0] osd_g,    // OSD green component
    output reg [7:0] osd_b     // OSD blue component
);
    // UART parameters
    parameter UART_CLK_FREQ = 96000000;  // 96 MHz
    parameter UART_BAUD_RATE = 3000000;  // 3 Mbps
    
    // UART signals
    wire [7:0] rx_data;
    wire rx_valid;
    reg rx_ready;
    reg [7:0] tx_data;
    reg tx_valid;
    wire tx_ready;
    
    // Command protocol constants
    localparam CMD_JOY1 = 8'h01;
    localparam CMD_JOY2 = 8'h02;
    localparam CMD_ROM_START = 8'h03;
    localparam CMD_ROM_DATA = 8'h04;
    localparam CMD_ROM_END = 8'h05;
    localparam CMD_OSD_ENABLE = 8'h06;
    localparam CMD_OSD_DISABLE = 8'h07;
    localparam CMD_OSD_DATA = 8'h08;
    
    // State machine states
    localparam STATE_IDLE = 0;
    localparam STATE_CMD = 1;
    localparam STATE_JOY1_L = 2;
    localparam STATE_JOY1_H = 3;
    localparam STATE_JOY2_L = 4;
    localparam STATE_JOY2_H = 5;
    localparam STATE_ROM_TYPE = 6;
    localparam STATE_ROM_ADDR1 = 7;
    localparam STATE_ROM_ADDR2 = 8;
    localparam STATE_ROM_ADDR3 = 9;
    localparam STATE_ROM_DATA = 10;
    localparam STATE_OSD_DATA = 11;
    
    // State and command
    reg [3:0] state = STATE_IDLE;
    reg [7:0] cmd;
    reg [23:0] addr_buffer;
    
    // UART instance
    uart_rx #(
        .CLK_FREQ(UART_CLK_FREQ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid),
        .ready(rx_ready)
    );
    
    uart_tx #(
        .CLK_FREQ(UART_CLK_FREQ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx(uart_tx),
        .data(tx_data),
        .valid(tx_valid),
        .ready(tx_ready)
    );
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            joy1 <= 0;
            joy2 <= 0;
            uart_valid <= 0;
            rom_start <= 0;
            osd_enable <= 0;
            rx_ready <= 1;
            tx_valid <= 0;
        end else begin
            // Default values
            uart_valid <= 0;
            rom_start <= 0;
            rx_ready <= 0;
            tx_valid <= 0;
            
            case (state)
                STATE_IDLE: begin
                    // Wait for command
                    rx_ready <= 1;
                    if (rx_valid) begin
                        cmd <= rx_data;
                        state <= STATE_CMD;
                        rx_ready <= 0;
                    end
                end
                
                STATE_CMD: begin
                    // Process command
                    case (cmd)
                        CMD_JOY1: begin
                            state <= STATE_JOY1_L;
                            rx_ready <= 1;
                        end
                        
                        CMD_JOY2: begin
                            state <= STATE_JOY2_L;
                            rx_ready <= 1;
                        end
                        
                        CMD_ROM_START: begin
                            state <= STATE_ROM_TYPE;
                            rx_ready <= 1;
                        end
                        
                        CMD_ROM_DATA: begin
                            state <= STATE_ROM_DATA;
                            rx_ready <= 1;
                        end
                        
                        CMD_ROM_END: begin
                            // End ROM loading
                            state <= STATE_IDLE;
                        end
                        
                        CMD_OSD_ENABLE: begin
                            // Enable OSD
                            osd_enable <= 1;
                            state <= STATE_IDLE;
                        end
                        
                        CMD_OSD_DISABLE: begin
                            // Disable OSD
                            osd_enable <= 0;
                            state <= STATE_IDLE;
                        end
                        
                        CMD_OSD_DATA: begin
                            state <= STATE_OSD_DATA;
                            rx_ready <= 1;
                        end
                        
                        default: state <= STATE_IDLE;
                    endcase
                end
                
                STATE_JOY1_L: begin
                    // Receive joystick 1 low byte
                    if (rx_valid) begin
                        joy1[7:0] <= rx_data;
                        state <= STATE_JOY1_H;
                        rx_ready <= 1;
                    end
                end
                
                STATE_JOY1_H: begin
                    // Receive joystick 1 high byte
                    if (rx_valid) begin
                        joy1[15:8] <= rx_data;
                        state <= STATE_IDLE;
                        rx_ready <= 1;
                    end
                end
                
                STATE_JOY2_L: begin
                    // Receive joystick 2 low byte
                    if (rx_valid) begin
                        joy2[7:0] <= rx_data;
                        state <= STATE_JOY2_H;
                        rx_ready <= 1;
                    end
                end
                
                STATE_JOY2_H: begin
                    // Receive joystick 2 high byte
                    if (rx_valid) begin
                        joy2[15:8] <= rx_data;
                        state <= STATE_IDLE;
                        rx_ready <= 1;
                    end
                end
                
                STATE_ROM_TYPE: begin
                    // Receive ROM type
                    if (rx_valid) begin
                        rom_type <= rx_data[2:0];
                        state <= STATE_ROM_ADDR1;
                        rx_ready <= 1;
                    end
                end
                
                STATE_ROM_ADDR1: begin
                    // Receive ROM address byte 1 (LSB)
                    if (rx_valid) begin
                        addr_buffer[7:0] <= rx_data;
                        state <= STATE_ROM_ADDR2;
                        rx_ready <= 1;
                    end
                end
                
                STATE_ROM_ADDR2: begin
                    // Receive ROM address byte 2
                    if (rx_valid) begin
                        addr_buffer[15:8] <= rx_data;
                        state <= STATE_ROM_ADDR3;
                        rx_ready <= 1;
                    end
                end
                
                STATE_ROM_ADDR3: begin
                    // Receive ROM address byte 3 (MSB)
                    if (rx_valid) begin
                        addr_buffer[23:16] <= rx_data;
                        rom_addr <= {1'b0, addr_buffer};
                        rom_start <= 1;
                        state <= STATE_IDLE;
                        rx_ready <= 1;
                    end
                end
                
                STATE_ROM_DATA: begin
                    // Receive ROM data
                    if (rx_valid && uart_ready) begin
                        uart_data <= rx_data;
                        uart_valid <= 1;
                        rx_ready <= 1;
                        
                        // Stay in this state to receive more data
                        // The ROM loader will signal when it's done
                        if (!rom_busy) begin
                            state <= STATE_IDLE;
                        end
                    end else if (uart_ready) begin
                        rx_ready <= 1;
                    end
                end
                
                STATE_OSD_DATA: begin
                    // Receive OSD data (RGB values)
                    if (rx_valid) begin
                        osd_r <= rx_data;
                        state <= STATE_OSD_DATA + 1;
                        rx_ready <= 1;
                    end
                end
                
                STATE_OSD_DATA + 1: begin
                    // Receive OSD green component
                    if (rx_valid) begin
                        osd_g <= rx_data;
                        state <= STATE_OSD_DATA + 2;
                        rx_ready <= 1;
                    end
                end
                
                STATE_OSD_DATA + 2: begin
                    // Receive OSD blue component
                    if (rx_valid) begin
                        osd_b <= rx_data;
                        state <= STATE_IDLE;
                        rx_ready <= 1;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

// UART Receiver Module
module uart_rx #(
    parameter CLK_FREQ = 96000000,  // 96 MHz
    parameter BAUD_RATE = 3000000   // 3 Mbps
)(
    input wire clk,
    input wire reset,
    input wire rx,
    output reg [7:0] data,
    output reg valid,
    input wire ready
);
    // Calculate clock cycles per bit
    localparam CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // State machine states
    localparam STATE_IDLE = 0;
    localparam STATE_START = 1;
    localparam STATE_DATA = 2;
    localparam STATE_STOP = 3;
    
    // State and counters
    reg [1:0] state = STATE_IDLE;
    reg [15:0] cycle_counter = 0;
    reg [2:0] bit_counter = 0;
    reg [7:0] rx_shift = 0;
    
    // Synchronize rx input
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            valid <= 0;
            cycle_counter <= 0;
            bit_counter <= 0;
        end else begin
            // Default values
            valid <= 0;
            
            case (state)
                STATE_IDLE: begin
                    // Wait for start bit
                    if (!rx_sync2) begin
                        state <= STATE_START;
                        cycle_counter <= 0;
                    end
                end
                
                STATE_START: begin
                    // Sample middle of start bit
                    if (cycle_counter == CYCLES_PER_BIT/2) begin
                        if (!rx_sync2) begin
                            // Valid start bit
                            state <= STATE_DATA;
                            cycle_counter <= 0;
                            bit_counter <= 0;
                        end else begin
                            // False start
                            state <= STATE_IDLE;
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                STATE_DATA: begin
                    // Sample middle of data bits
                    if (cycle_counter == CYCLES_PER_BIT) begin
                        rx_shift <= {rx_sync2, rx_shift[7:1]};
                        cycle_counter <= 0;
                        
                        if (bit_counter == 7) begin
                            // All bits received
                            state <= STATE_STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                STATE_STOP: begin
                    // Sample middle of stop bit
                    if (cycle_counter == CYCLES_PER_BIT) begin
                        if (rx_sync2) begin
                            // Valid stop bit
                            data <= rx_shift;
                            valid <= 1;
                        end
                        
                        state <= STATE_IDLE;
                        cycle_counter <= 0;
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
            
            // Clear valid when ready is asserted
            if (valid && ready) begin
                valid <= 0;
            end
        end
    end
endmodule

// UART Transmitter Module
module uart_tx #(
    parameter CLK_FREQ = 96000000,  // 96 MHz
    parameter BAUD_RATE = 3000000   // 3 Mbps
)(
    input wire clk,
    input wire reset,
    output reg tx,
    input wire [7:0] data,
    input wire valid,
    output reg ready
);
    // Calculate clock cycles per bit
    localparam CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // State machine states
    localparam STATE_IDLE = 0;
    localparam STATE_START = 1;
    localparam STATE_DATA = 2;
    localparam STATE_STOP = 3;
    
    // State and counters
    reg [1:0] state = STATE_IDLE;
    reg [15:0] cycle_counter = 0;
    reg [2:0] bit_counter = 0;
    reg [7:0] tx_shift = 0;
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            ready <= 1;
            tx <= 1;
            cycle_counter <= 0;
            bit_counter <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    // Wait for data
                    tx <= 1;
                    ready <= 1;
                    
                    if (valid) begin
                        tx_shift <= data;
                        state <= STATE_START;
                        ready <= 0;
                        cycle_counter <= 0;
                    end
                end
                
                STATE_START: begin
                    // Send start bit
                    tx <= 0;
                    
                    if (cycle_counter == CYCLES_PER_BIT - 1) begin
                        state <= STATE_DATA;
                        cycle_counter <= 0;
                        bit_counter <= 0;
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                STATE_DATA: begin
                    // Send data bits
                    tx <= tx_shift[0];
                    
                    if (cycle_counter == CYCLES_PER_BIT - 1) begin
                        cycle_counter <= 0;
                        tx_shift <= {1'b0, tx_shift[7:1]};
                        
                        if (bit_counter == 7) begin
                            // All bits sent
                            state <= STATE_STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                STATE_STOP: begin
                    // Send stop bit
                    tx <= 1;
                    
                    if (cycle_counter == CYCLES_PER_BIT - 1) begin
                        state <= STATE_IDLE;
                        cycle_counter <= 0;
                    end else begin
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule
