// NeoGeo Core for Tang 138K - SDRAM Controller
// This module interfaces with the external SDRAM chip on the Tang 138K

module sdram_controller (
    input wire clk,            // System clock (96 MHz)
    input wire reset,          // System reset
    
    // Interface to NeoGeo core
    input wire [24:0] addr,    // Memory address
    input wire [15:0] din,     // Data input (to SDRAM)
    output reg [15:0] dout,    // Data output (from SDRAM)
    input wire rd,             // Read enable
    input wire wr,             // Write enable
    output reg ready,          // Data ready / operation complete
    
    // ROM loading interface
    input wire [24:0] rom_addr, // ROM address from BL616
    input wire [7:0] rom_data,  // ROM data from BL616
    input wire rom_wr,          // ROM write enable
    
    // Interface to SDRAM chip
    output reg sdram_clk,      // SDRAM clock
    output reg sdram_cke,      // SDRAM clock enable
    output reg sdram_cs_n,     // SDRAM chip select
    output reg sdram_ras_n,    // SDRAM row address strobe
    output reg sdram_cas_n,    // SDRAM column address strobe
    output reg sdram_we_n,     // SDRAM write enable
    output reg [1:0] sdram_ba, // SDRAM bank address
    output reg [12:0] sdram_a, // SDRAM address
    inout wire [15:0] sdram_dq,// SDRAM data
    output reg sdram_dqml,     // SDRAM data mask low
    output reg sdram_dqmh      // SDRAM data mask high
);
    // SDRAM timing parameters (for 96 MHz clock, ~10.4ns cycle)
    localparam tRP = 2;    // Precharge to Activate delay (20ns)
    localparam tRCD = 2;   // Activate to Read/Write delay (20ns)
    localparam tCAS = 2;   // CAS latency (20ns)
    localparam tWR = 2;    // Write recovery time (20ns)
    localparam tREF = 1536; // Refresh period (64ms / 8192 rows = ~7.8us)
    
    // SDRAM commands (CS_N, RAS_N, CAS_N, WE_N)
    localparam CMD_NOP      = 4'b0111;
    localparam CMD_ACTIVE   = 4'b0011;
    localparam CMD_READ     = 4'b0101;
    localparam CMD_WRITE    = 4'b0100;
    localparam CMD_PRECHARGE= 4'b0010;
    localparam CMD_REFRESH  = 4'b0001;
    localparam CMD_LOAD_MODE= 4'b0000;
    
    // SDRAM mode register
    // [12:10] - Reserved (0)
    // [9]     - Write Burst (0 = Programmed length, 1 = Single location)
    // [8:7]   - Test Mode (0 = Normal)
    // [6:4]   - CAS Latency (2 or 3)
    // [3]     - Burst Type (0 = Sequential, 1 = Interleaved)
    // [2:0]   - Burst Length (0 = 1, 1 = 2, 2 = 4, 3 = 8, 7 = Full page)
    localparam MODE_REG = 13'b000_0_00_010_0_000; // CAS=2, Sequential, Burst=1
    
    // State machine states
    localparam STATE_INIT = 0;
    localparam STATE_IDLE = 1;
    localparam STATE_REFRESH = 2;
    localparam STATE_ACTIVATE = 3;
    localparam STATE_READ = 4;
    localparam STATE_READ_DATA = 5;
    localparam STATE_WRITE = 6;
    localparam STATE_PRECHARGE = 7;
    localparam STATE_ROM_WRITE = 8;
    
    // State and counters
    reg [3:0] state = STATE_INIT;
    reg [3:0] next_state = STATE_INIT;
    reg [15:0] init_counter = 0;
    reg [10:0] refresh_counter = 0;
    reg [3:0] delay_counter = 0;
    
    // Internal signals
    reg [24:0] active_addr;
    reg [15:0] write_data;
    reg [15:0] read_data;
    reg data_ready;
    reg [1:0] active_bank;
    reg [12:0] active_row;
    reg [9:0] active_col;
    reg row_open;
    
    // SDRAM data bus control
    reg sdram_dq_oe;
    reg [15:0] sdram_dq_out;
    assign sdram_dq = sdram_dq_oe ? sdram_dq_out : 16'hZZZZ;
    
    // Command output
    reg [3:0] cmd;
    always @(*) begin
        {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = cmd;
    end
    
    // SDRAM clock output
    always @(*) begin
        sdram_clk = ~clk; // Inverted clock to ensure proper timing
        sdram_cke = 1'b1; // Always enabled after initialization
    end
    
    // Main state machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_INIT;
            init_counter <= 0;
            refresh_counter <= 0;
            delay_counter <= 0;
            row_open <= 0;
            ready <= 0;
            dout <= 0;
            cmd <= CMD_NOP;
            sdram_dq_oe <= 0;
            sdram_dqml <= 1;
            sdram_dqmh <= 1;
        end else begin
            // Default values
            cmd <= CMD_NOP;
            ready <= 0;
            
            // Increment refresh counter
            if (refresh_counter < tREF)
                refresh_counter <= refresh_counter + 1;
                
            // State machine
            case (state)
                STATE_INIT: begin
                    // SDRAM initialization sequence
                    if (init_counter < 20000) begin
                        // Wait for 200us (19200 cycles at 96MHz)
                        init_counter <= init_counter + 1;
                        cmd <= CMD_NOP;
                    end else if (init_counter == 20000) begin
                        // Precharge all banks
                        cmd <= CMD_PRECHARGE;
                        sdram_a[10] <= 1; // All banks
                        init_counter <= init_counter + 1;
                    end else if (init_counter == 20000 + tRP) begin
                        // Auto refresh
                        cmd <= CMD_REFRESH;
                        init_counter <= init_counter + 1;
                    end else if (init_counter == 20000 + tRP + tREF) begin
                        // Auto refresh again
                        cmd <= CMD_REFRESH;
                        init_counter <= init_counter + 1;
                    end else if (init_counter == 20000 + tRP + 2*tREF) begin
                        // Load mode register
                        cmd <= CMD_LOAD_MODE;
                        sdram_a <= MODE_REG;
                        sdram_ba <= 2'b00;
                        init_counter <= init_counter + 1;
                    end else begin
                        // Initialization complete
                        state <= STATE_IDLE;
                        refresh_counter <= 0;
                    end
                end
                
                STATE_IDLE: begin
                    // Check if refresh is needed
                    if (refresh_counter >= tREF) begin
                        if (row_open) begin
                            // Need to precharge before refresh
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 1; // All banks
                            sdram_ba <= active_bank;
                            state <= STATE_REFRESH;
                            delay_counter <= tRP;
                        end else begin
                            // Can refresh immediately
                            cmd <= CMD_REFRESH;
                            state <= STATE_IDLE;
                            refresh_counter <= 0;
                            delay_counter <= tREF;
                        end
                    end
                    // Check for ROM write from BL616
                    else if (rom_wr) begin
                        active_addr <= rom_addr;
                        write_data <= {rom_data, rom_data}; // Duplicate byte to both halves
                        state <= STATE_ROM_WRITE;
                        
                        // Parse address into bank, row, column
                        active_bank <= rom_addr[24:23];
                        active_row <= rom_addr[22:10];
                        active_col <= rom_addr[9:0];
                        
                        if (row_open && (active_bank != rom_addr[24:23] || active_row != rom_addr[22:10])) begin
                            // Different row/bank is open, need to precharge first
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 0; // Current bank only
                            sdram_ba <= active_bank;
                            state <= STATE_ACTIVATE;
                            next_state <= STATE_ROM_WRITE;
                            delay_counter <= tRP;
                            row_open <= 0;
                        end else if (!row_open) begin
                            // No row open, activate the row
                            cmd <= CMD_ACTIVE;
                            sdram_a <= rom_addr[22:10]; // Row address
                            sdram_ba <= rom_addr[24:23]; // Bank
                            state <= STATE_ROM_WRITE;
                            delay_counter <= tRCD;
                            row_open <= 1;
                        end
                    end
                    // Check for read request
                    else if (rd) begin
                        active_addr <= addr;
                        state <= STATE_ACTIVATE;
                        next_state <= STATE_READ;
                        
                        // Parse address into bank, row, column
                        active_bank <= addr[24:23];
                        active_row <= addr[22:10];
                        active_col <= addr[9:0];
                        
                        if (row_open && (active_bank != addr[24:23] || active_row != addr[22:10])) begin
                            // Different row/bank is open, need to precharge first
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 0; // Current bank only
                            sdram_ba <= active_bank;
                            delay_counter <= tRP;
                            row_open <= 0;
                        end else if (!row_open) begin
                            // No row open, activate the row
                            cmd <= CMD_ACTIVE;
                            sdram_a <= addr[22:10]; // Row address
                            sdram_ba <= addr[24:23]; // Bank
                            delay_counter <= tRCD;
                            row_open <= 1;
                            state <= STATE_READ;
                        end else begin
                            // Row already open, go directly to read
                            state <= STATE_READ;
                        end
                    end
                    // Check for write request
                    else if (wr) begin
                        active_addr <= addr;
                        write_data <= din;
                        state <= STATE_ACTIVATE;
                        next_state <= STATE_WRITE;
                        
                        // Parse address into bank, row, column
                        active_bank <= addr[24:23];
                        active_row <= addr[22:10];
                        active_col <= addr[9:0];
                        
                        if (row_open && (active_bank != addr[24:23] || active_row != addr[22:10])) begin
                            // Different row/bank is open, need to precharge first
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 0; // Current bank only
                            sdram_ba <= active_bank;
                            delay_counter <= tRP;
                            row_open <= 0;
                        end else if (!row_open) begin
                            // No row open, activate the row
                            cmd <= CMD_ACTIVE;
                            sdram_a <= addr[22:10]; // Row address
                            sdram_ba <= addr[24:23]; // Bank
                            delay_counter <= tRCD;
                            row_open <= 1;
                            state <= STATE_WRITE;
                        end else begin
                            // Row already open, go directly to write
                            state <= STATE_WRITE;
                        end
                    end
                end
                
                STATE_REFRESH: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_REFRESH;
                        state <= STATE_IDLE;
                        refresh_counter <= 0;
                        delay_counter <= tREF;
                        row_open <= 0;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_ACTIVATE: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_ACTIVE;
                        sdram_a <= active_row;
                        sdram_ba <= active_bank;
                        state <= next_state;
                        delay_counter <= tRCD;
                        row_open <= 1;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_READ: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_READ;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_ba <= active_bank;
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        state <= STATE_READ_DATA;
                        delay_counter <= tCAS;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_READ_DATA: begin
                    if (delay_counter == 0) begin
                        // Data is available on sdram_dq
                        dout <= sdram_dq;
                        ready <= 1;
                        state <= STATE_IDLE;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_WRITE: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_WRITE;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_ba <= active_bank;
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        sdram_dq_oe <= 1;
                        sdram_dq_out <= write_data;
                        state <= STATE_PRECHARGE;
                        delay_counter <= tWR;
                        ready <= 1;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_ROM_WRITE: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_WRITE;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_ba <= active_bank;
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        sdram_dq_oe <= 1;
                        sdram_dq_out <= write_data;
                        state <= STATE_IDLE;
                        delay_counter <= tWR;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                STATE_PRECHARGE: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_PRECHARGE;
                        sdram_a[10] <= 0; // Current bank only
                        sdram_ba <= active_bank;
                        state <= STATE_IDLE;
                        delay_counter <= tRP;
                        sdram_dq_oe <= 0;
                        row_open <= 0;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
