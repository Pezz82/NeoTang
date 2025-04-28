// NeoGeo Core for Tang 138K - Test Bench
// This module provides a test bench for the NeoGeo core port

`timescale 1ns / 1ps

module neotang_tb;
    // Clock and reset
    reg clk_27m = 0;
    reg reset_n = 0;
    
    // UART signals
    reg uart_rx = 1;
    wire uart_tx;
    
    // HDMI signals
    wire hdmi_clk_p, hdmi_clk_n;
    wire [2:0] hdmi_data_p, hdmi_data_n;
    
    // SDRAM signals
    wire sdram_clk;
    wire sdram_cke;
    wire sdram_cs_n;
    wire sdram_ras_n;
    wire sdram_cas_n;
    wire sdram_we_n;
    wire [1:0] sdram_ba;
    wire [12:0] sdram_a;
    wire [15:0] sdram_dq;
    wire sdram_dqml;
    wire sdram_dqmh;
    
    // Generate clock
    always #18.5 clk_27m = ~clk_27m; // 27 MHz clock (period = 37ns)
    
    // Reset sequence
    initial begin
        reset_n = 0;
        #100;
        reset_n = 1;
    end
    
    // Instantiate the top module
    neotang_top dut (
        .clk_27m(clk_27m),
        .reset_n(reset_n),
        
        // UART
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        
        // HDMI
        .hdmi_clk_p(hdmi_clk_p),
        .hdmi_clk_n(hdmi_clk_n),
        .hdmi_data_p(hdmi_data_p),
        .hdmi_data_n(hdmi_data_n),
        
        // SDRAM
        .sdram_clk(sdram_clk),
        .sdram_cke(sdram_cke),
        .sdram_cs_n(sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .sdram_we_n(sdram_we_n),
        .sdram_ba(sdram_ba),
        .sdram_a(sdram_a),
        .sdram_dq(sdram_dq),
        .sdram_dqml(sdram_dqml),
        .sdram_dqmh(sdram_dqmh)
    );
    
    // Test sequence
    initial begin
        // Wait for reset to complete
        #200;
        
        // Simulate UART commands
        // Send controller data
        send_uart_byte(8'h01); // CMD_JOY1
        send_uart_byte(8'h55); // Joy1 low byte
        send_uart_byte(8'hAA); // Joy1 high byte
        
        #1000;
        
        send_uart_byte(8'h02); // CMD_JOY2
        send_uart_byte(8'h33); // Joy2 low byte
        send_uart_byte(8'h77); // Joy2 high byte
        
        #1000;
        
        // Enable OSD
        send_uart_byte(8'h06); // CMD_OSD_ENABLE
        
        #1000;
        
        // Send OSD data
        send_uart_byte(8'h08); // CMD_OSD_DATA
        send_uart_byte(8'hFF); // Red
        send_uart_byte(8'hFF); // Green
        send_uart_byte(8'h00); // Blue
        
        #1000;
        
        // Disable OSD
        send_uart_byte(8'h07); // CMD_OSD_DISABLE
        
        // Run simulation for a while
        #10000;
        
        $finish;
    end
    
    // Task to send a byte over UART
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            uart_rx = 0;
            #3333; // ~3Mbps baud rate (333ns per bit)
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #3333;
            end
            
            // Stop bit
            uart_rx = 1;
            #3333;
        end
    endtask
    
    // Monitor signals
    initial begin
        $monitor("Time=%0t, Reset=%b, UART_TX=%b", $time, reset_n, uart_tx);
    end
    
endmodule
