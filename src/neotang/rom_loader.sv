// Enhanced ROM Loader for NeoGeo Core on Tang 138K
// Supports both .neo and Darksoft formats with proper UART protocol

module rom_loader (
    input wire clk,            // System clock (133 MHz)
    input wire reset,          // System reset
    
    // Interface from BL616
    input wire [7:0] uart_data,  // Data from UART
    input wire uart_valid,       // Data valid signal
    output reg uart_ready,       // Ready to receive data
    
    // ROM type and addressing
    input wire [2:0] rom_type,   // 0=BIOS, 1=P, 2=S, 3=M, 4=V, 5=C, 6=NEO
    input wire [23:0] rom_addr,  // Address within ROM
    input wire rom_start,        // Start loading signal
    output reg rom_busy,         // ROM loading in progress
    output reg rom_done,         // ROM loading complete
    
    // Interface to SDRAM controller
    output reg [24:0] sdram_addr, // Address to SDRAM
    output reg [7:0] sdram_data,  // Data to SDRAM
    output reg sdram_wr           // Write enable to SDRAM
);
    // ROM type constants
    localparam ROM_BIOS = 3'd0;
    localparam ROM_P = 3'd1;     // Program ROM (Darksoft format)
    localparam ROM_S = 3'd2;     // Sound ROM (Darksoft format)
    localparam ROM_M = 3'd3;     // M1 ROM (Darksoft format)
    localparam ROM_V = 3'd4;     // Video ROM (Darksoft format)
    localparam ROM_C = 3'd5;     // C ROM (Darksoft format)
    localparam ROM_NEO = 3'd6;   // .NEO format (single file)
    
    // Memory map base addresses (aligned with Darksoft cartridge map)
    localparam ADDR_BIOS = 25'h0000000;  // BIOS ROM at 0x0000000
    localparam ADDR_P = 25'h0020000;     // P ROM at 0x0020000
    localparam ADDR_S = 25'h0300000;     // S ROM at 0x0300000
    localparam ADDR_M = 25'h0280000;     // M ROM at 0x0280000
    localparam ADDR_V = 25'h0200000;     // V ROM at 0x0200000
    localparam ADDR_C = 25'h0100000;     // C ROM at 0x0100000
    
    // UART protocol commands
    localparam CMD_LOAD_START = 8'h01;   // Start loading a ROM
    localparam CMD_LOAD_DATA = 8'h02;    // ROM data follows
    localparam CMD_LOAD_END = 8'h03;     // End of ROM data
    localparam CMD_LOAD_ABORT = 8'h04;   // Abort loading
    localparam CMD_ACK = 8'h11;          // ACK signal
    
    // State machine states
    localparam STATE_IDLE = 0;
    localparam STATE_CMD = 1;
    localparam STATE_TYPE = 2;
    localparam STATE_ADDR_H = 3;
    localparam STATE_ADDR_M = 4;
    localparam STATE_ADDR_L = 5;
    localparam STATE_SIZE_H = 6;
    localparam STATE_SIZE_M = 7;
    localparam STATE_SIZE_L = 8;
    localparam STATE_LOADING = 9;
    localparam STATE_WRITE = 10;
    localparam STATE_END = 11;
    
    // State and counters
    reg [3:0] state = STATE_IDLE;
    reg [24:0] base_addr;
    reg [24:0] current_addr;
    reg [23:0] bytes_remaining;
    reg [7:0] current_cmd;
    reg [2:0] current_type;
    reg [23:0] current_rom_addr;
    reg [23:0] current_rom_size;
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            uart_ready <= 0;
            rom_busy <= 0;
            rom_done <= 0;
            sdram_wr <= 0;
            current_addr <= 0;
            bytes_remaining <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    sdram_wr <= 0;
                    uart_ready <= 1; // Ready to receive commands
                    rom_done <= 0;
                    
                    if (uart_valid) begin
                        // Command received
                        current_cmd <= uart_data;
                        uart_ready <= 0;
                        
                        case (uart_data)
                            CMD_LOAD_START: begin
                                // Start loading a new ROM
                                rom_busy <= 1;
                                state <= STATE_TYPE;
                                uart_ready <= 1;
                            end
                            
                            CMD_LOAD_ABORT: begin
                                // Abort current loading
                                rom_busy <= 0;
                                state <= STATE_IDLE;
                                uart_ready <= 1;
                            end
                            
                            default: begin
                                // Unknown command, stay in IDLE
                                state <= STATE_IDLE;
                                uart_ready <= 1;
                            end
                        endcase
                    end
                    
                    // Legacy direct start method (for backward compatibility)
                    if (rom_start) begin
                        // Start loading ROM
                        rom_busy <= 1;
                        
                        // Set base address based on ROM type
                        case (rom_type)
                            ROM_BIOS: base_addr <= ADDR_BIOS;
                            ROM_P: base_addr <= ADDR_P;
                            ROM_S: base_addr <= ADDR_S;
                            ROM_M: base_addr <= ADDR_M;
                            ROM_V: base_addr <= ADDR_V;
                            ROM_C: base_addr <= ADDR_C;
                            ROM_NEO: begin
                                // For .NEO format, we need to determine the address
                                // based on the ROM address provided
                                if (rom_addr < 24'h100000) begin
                                    // P ROM area
                                    base_addr <= ADDR_P;
                                end else if (rom_addr < 24'h200000) begin
                                    // C ROM area
                                    base_addr <= ADDR_C - 24'h100000;
                                end else if (rom_addr < 24'h300000) begin
                                    // V ROM area
                                    base_addr <= ADDR_V - 24'h200000;
                                end else if (rom_addr < 24'h380000) begin
                                    // M ROM area
                                    base_addr <= ADDR_M - 24'h300000;
                                end else begin
                                    // S ROM area
                                    base_addr <= ADDR_S - 24'h380000;
                                end
                            end
                            default: base_addr <= 0;
                        endcase
                        
                        // Calculate current address
                        if (rom_type == ROM_NEO) begin
                            // For .NEO format, use the base address calculated above
                            current_addr <= base_addr + rom_addr;
                        end else begin
                            // For other formats, add the ROM address to the base address
                            current_addr <= base_addr + rom_addr;
                        end
                        
                        state <= STATE_LOADING;
                        uart_ready <= 1;
                    end
                end
                
                STATE_TYPE: begin
                    if (uart_valid) begin
                        // ROM type received
                        current_type <= uart_data[2:0];
                        uart_ready <= 0;
                        state <= STATE_ADDR_H;
                        uart_ready <= 1;
                    end
                end
                
                STATE_ADDR_H: begin
                    if (uart_valid) begin
                        // High byte of ROM address
                        current_rom_addr[23:16] <= uart_data;
                        uart_ready <= 0;
                        state <= STATE_ADDR_M;
                        uart_ready <= 1;
                    end
                end
                
                STATE_ADDR_M: begin
                    if (uart_valid) begin
                        // Middle byte of ROM address
                        current_rom_addr[15:8] <= uart_data;
                        uart_ready <= 0;
                        state <= STATE_ADDR_L;
                        uart_ready <= 1;
                    end
                end
                
                STATE_ADDR_L: begin
                    if (uart_valid) begin
                        // Low byte of ROM address
                        current_rom_addr[7:0] <= uart_data;
                        uart_ready <= 0;
                        state <= STATE_SIZE_H;
                        uart_ready <= 1;
                    end
                end
                
                STATE_SIZE_H: begin
                    if (uart_valid) begin
                        // High byte of ROM size
                        current_rom_size[23:16] <= uart_data;
                        uart_ready <= 0;
                        state <= STATE_SIZE_M;
                        uart_ready <= 1;
                    end
                end
                
                STATE_SIZE_M: begin
                    if (uart_valid) begin
                        // Middle byte of ROM size
                        current_rom_size[15:8] <= uart_data;
                        uart_ready <= 0;
                        state <= STATE_SIZE_L;
                        uart_ready <= 1;
                    end
                end
                
                STATE_SIZE_L: begin
                    if (uart_valid) begin
                        // Low byte of ROM size
                        current_rom_size[7:0] <= uart_data;
                        uart_ready <= 0;
                        
                        // Set base address based on ROM type
                        case (current_type)
                            ROM_BIOS: base_addr <= ADDR_BIOS;
                            ROM_P: base_addr <= ADDR_P;
                            ROM_S: base_addr <= ADDR_S;
                            ROM_M: base_addr <= ADDR_M;
                            ROM_V: base_addr <= ADDR_V;
                            ROM_C: base_addr <= ADDR_C;
                            ROM_NEO: begin
                                // For .NEO format, we need to determine the address
                                // based on the ROM address provided
                                if (current_rom_addr < 24'h100000) begin
                                    // P ROM area
                                    base_addr <= ADDR_P;
                                end else if (current_rom_addr < 24'h200000) begin
                                    // C ROM area
                                    base_addr <= ADDR_C - 24'h100000;
                                end else if (current_rom_addr < 24'h300000) begin
                                    // V ROM area
                                    base_addr <= ADDR_V - 24'h200000;
                                end else if (current_rom_addr < 24'h380000) begin
                                    // M ROM area
                                    base_addr <= ADDR_M - 24'h300000;
                                end else begin
                                    // S ROM area
                                    base_addr <= ADDR_S - 24'h380000;
                                end
                            end
                            default: base_addr <= 0;
                        endcase
                        
                        // Calculate current address
                        if (current_type == ROM_NEO) begin
                            // For .NEO format, use the base address calculated above
                            current_addr <= base_addr + current_rom_addr;
                        end else begin
                            // For other formats, add the ROM address to the base address
                            current_addr <= base_addr + current_rom_addr;
                        end
                        
                        // Set bytes remaining
                        bytes_remaining <= current_rom_size;
                        
                        // Wait for CMD_LOAD_DATA
                        state <= STATE_CMD;
                        uart_ready <= 1;
                    end
                end
                
                STATE_CMD: begin
                    if (uart_valid) begin
                        // Command received
                        current_cmd <= uart_data;
                        uart_ready <= 0;
                        
                        case (uart_data)
                            CMD_LOAD_DATA: begin
                                // Start receiving data
                                state <= STATE_LOADING;
                                uart_ready <= 1;
                            end
                            
                            CMD_LOAD_END: begin
                                // End of ROM data
                                rom_busy <= 0;
                                rom_done <= 1;
                                state <= STATE_END;
                            end
                            
                            CMD_LOAD_ABORT: begin
                                // Abort current loading
                                rom_busy <= 0;
                                state <= STATE_IDLE;
                                uart_ready <= 1;
                            end
                            
                            default: begin
                                // Unknown command, stay in CMD
                                state <= STATE_CMD;
                                uart_ready <= 1;
                            end
                        endcase
                    end
                end
                
                STATE_LOADING: begin
                    if (uart_valid) begin
                        // Check if it's a command
                        if (uart_data == CMD_LOAD_END || uart_data == CMD_LOAD_ABORT) begin
                            current_cmd <= uart_data;
                            uart_ready <= 0;
                            
                            if (uart_data == CMD_LOAD_END) begin
                                // End of ROM data
                                rom_busy <= 0;
                                rom_done <= 1;
                                state <= STATE_END;
                            end else begin
                                // Abort current loading
                                rom_busy <= 0;
                                state <= STATE_IDLE;
                                uart_ready <= 1;
                            end
                        end else begin
                            // Data received from UART
                            sdram_addr <= current_addr;
                            sdram_data <= uart_data;
                            sdram_wr <= 1;
                            uart_ready <= 0;
                            state <= STATE_WRITE;
                        end
                    end
                end
                
                STATE_WRITE: begin
                    if (uart_valid) begin
                        // Write data to SDRAM
                        sdram_addr <= current_addr;
                        sdram_data <= uart_data;
                        sdram_wr <= 1;
                        
                        // Increment address and decrement counter
                        current_addr <= current_addr + 1;
                        bytes_remaining <= bytes_remaining - 1;
                        
                        // Check if we're done
                        if (bytes_remaining == 1) begin
                            state <= STATE_END;
                            sdram_wr <= 0;
                        end
                        
                        uart_ready <= 1;
                    end

                    // BL616 issues ACK (0x11) at end of each file — release BUSY
                    if (current_cmd == CMD_ACK) begin
                        rom_busy <= 1'b0;
                        rom_done <= 1'b1;
                        state    <= STATE_END;
                    end
                end
                
                STATE_END: begin
                    // ROM loading complete
                    rom_busy <= 0;
                    rom_done <= 1;
                    
                    // Return to IDLE after one cycle
                    state <= STATE_IDLE;
                end
                
                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
