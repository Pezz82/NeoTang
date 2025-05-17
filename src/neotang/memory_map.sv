// NeoGeo Core for Tang 138K - Memory Map Module
// This module maps between NeoGeo memory addresses and SDRAM addresses

module memory_map (
    input wire clk,            // System clock
    input wire reset,          // System reset
    
    // Interface to NeoGeo core
    input wire [23:0] neo_addr,  // Address from NeoGeo core
    input wire [15:0] neo_din,   // Data input from NeoGeo core
    output reg [15:0] neo_dout,  // Data output to NeoGeo core
    input wire neo_rd,           // Read enable from NeoGeo core
    input wire neo_wr,           // Write enable from NeoGeo core
    output reg neo_ready,        // Data ready signal to NeoGeo core
    
    // Interface to SDRAM controller
    output reg [24:0] sdram_addr, // Address to SDRAM controller
    output reg [15:0] sdram_din,  // Data to SDRAM controller
    input wire [15:0] sdram_dout, // Data from SDRAM controller
    output reg sdram_rd,          // Read enable to SDRAM controller
    output reg sdram_wr,          // Write enable to SDRAM controller
    input wire sdram_ready        // Data ready from SDRAM controller
);
    // Memory map base addresses (aligned with Darksoft cartridge map)
    localparam ADDR_BIOS = 25'h0000000;  // BIOS ROM at 0x0000000
    localparam ADDR_P = 25'h0020000;     // P ROM at 0x0020000
    localparam ADDR_S = 25'h0300000;     // S ROM at 0x0300000
    localparam ADDR_M = 25'h0280000;     // M ROM at 0x0280000
    localparam ADDR_V = 25'h0200000;     // V ROM at 0x0200000
    localparam ADDR_C = 25'h0100000;     // C ROM at 0x0100000
    
    // NeoGeo memory map regions
    localparam NEO_BIOS     = 24'h000000; // 0x000000-0x01FFFF: BIOS ROM
    localparam NEO_SROM     = 24'h100000; // 0x100000-0x1FFFFF: S ROM (sound data)
    localparam NEO_PROM     = 24'h200000; // 0x200000-0x2FFFFF: P ROM (program data)
    localparam NEO_CROM     = 24'h300000; // 0x300000-0x3FFFFF: C ROM (sprites)
    localparam NEO_VROM     = 24'h400000; // 0x400000-0x4FFFFF: V ROM (fix tiles)
    localparam NEO_MROM     = 24'h500000; // 0x500000-0x5FFFFF: M ROM (Z80 program)
    localparam NEO_WRAM     = 24'h600000; // 0x600000-0x6FFFFF: Work RAM
    localparam NEO_BACKUP   = 24'h700000; // 0x700000-0x7FFFFF: Backup RAM
    
    // State machine states
    localparam STATE_IDLE = 0;
    localparam STATE_READ = 1;
    localparam STATE_WRITE = 2;
    localparam STATE_WAIT = 3;
    
    // State and registers
    reg [1:0] state = STATE_IDLE;
    reg [24:0] mapped_addr;
    
    // Memory mapping logic
    always @(*) begin
        // Default mapping
        mapped_addr = {1'b0, neo_addr};
        
        // Map NeoGeo addresses to SDRAM addresses
        if (neo_addr >= NEO_BIOS && neo_addr < NEO_SROM) begin
            // BIOS ROM: 0x000000-0x01FFFF -> 0x0000000-0x001FFFF
            mapped_addr = ADDR_BIOS + (neo_addr - NEO_BIOS);
        end else if (neo_addr >= NEO_SROM && neo_addr < NEO_PROM) begin
            // S ROM: 0x100000-0x1FFFFF -> 0x0300000-0x03FFFFF
            mapped_addr = ADDR_S + (neo_addr - NEO_SROM);
        end else if (neo_addr >= NEO_PROM && neo_addr < NEO_CROM) begin
            // P ROM: 0x200000-0x2FFFFF -> 0x0020000-0x011FFFF
            mapped_addr = ADDR_P + (neo_addr - NEO_PROM);
        end else if (neo_addr >= NEO_CROM && neo_addr < NEO_VROM) begin
            // C ROM: 0x300000-0x3FFFFF -> 0x0100000-0x01FFFFF
            mapped_addr = ADDR_C + (neo_addr - NEO_CROM);
        end else if (neo_addr >= NEO_VROM && neo_addr < NEO_MROM) begin
            // V ROM: 0x400000-0x4FFFFF -> 0x0200000-0x02FFFFF
            mapped_addr = ADDR_V + (neo_addr - NEO_VROM);
        end else if (neo_addr >= NEO_MROM && neo_addr < NEO_WRAM) begin
            // M ROM: 0x500000-0x5FFFFF -> 0x0280000-0x037FFFF
            mapped_addr = ADDR_M + (neo_addr - NEO_MROM);
        end else if (neo_addr >= NEO_WRAM && neo_addr < NEO_BACKUP) begin
            // Work RAM: 0x600000-0x6FFFFF -> 0x0800000-0x08FFFFF
            mapped_addr = 25'h0800000 + (neo_addr - NEO_WRAM);
        end else if (neo_addr >= NEO_BACKUP) begin
            // Backup RAM: 0x700000-0x7FFFFF -> 0x0900000-0x09FFFFF
            mapped_addr = 25'h0900000 + (neo_addr - NEO_BACKUP);
        end
    end
    
    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            neo_ready <= 0;
            sdram_rd <= 0;
            sdram_wr <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    neo_ready <= 0;
                    sdram_rd <= 0;
                    sdram_wr <= 0;
                    
                    if (neo_rd) begin
                        // Start read operation
                        sdram_addr <= mapped_addr;
                        sdram_rd <= 1;
                        state <= STATE_READ;
                    end else if (neo_wr) begin
                        // Start write operation
                        sdram_addr <= mapped_addr;
                        sdram_din <= neo_din;
                        sdram_wr <= 1;
                        state <= STATE_WRITE;
                    end
                end
                
                STATE_READ: begin
                    sdram_rd <= 0;
                    
                    if (sdram_ready) begin
                        // Read complete
                        neo_dout <= sdram_dout;
                        neo_ready <= 1;
                        state <= STATE_WAIT;
                    end
                end
                
                STATE_WRITE: begin
                    sdram_wr <= 0;
                    
                    if (sdram_ready) begin
                        // Write complete
                        neo_ready <= 1;
                        state <= STATE_WAIT;
                    end
                end
                
                STATE_WAIT: begin
                    // Wait one cycle for neo_ready to be seen
                    neo_ready <= 0;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
