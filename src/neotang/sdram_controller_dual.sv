// NeoGeo Core for Tang 138K - Dual-Port SDRAM Controller with Bank Interleaving
// This module provides dual 16-bit ports for the NeoGeo core with bank interleaving

module sdram_controller_dual (
    input wire clk,            // System clock (133 MHz)
    input wire reset,          // System reset
    
    // Port A interface (primarily for P-ROM, S-ROM)
    input wire [24:0] a_addr,  // Memory address for port A
    input wire [15:0] a_din,   // Data input for port A (to SDRAM)
    output reg [15:0] a_dout,  // Data output for port A (from SDRAM)
    input wire a_rd,           // Read enable for port A
    input wire a_wr,           // Write enable for port A
    output reg a_ready,        // Data ready / operation complete for port A
    
    // Port B interface (primarily for C-ROM)
    input wire [24:0] b_addr,  // Memory address for port B
    input wire [15:0] b_din,   // Data input for port B (to SDRAM)
    output reg [15:0] b_dout,  // Data output for port B (from SDRAM)
    input wire b_rd,           // Read enable for port B
    input wire b_wr,           // Write enable for port B
    output reg b_ready,        // Data ready / operation complete for port B
    
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
    // SDRAM timing parameters (for 133 MHz clock, ~7.5ns cycle)
    localparam tRP = 3;    // Precharge to Activate delay (20ns)
    localparam tRCD = 3;   // Activate to Read/Write delay (20ns)
    localparam tCAS = 3;   // CAS latency (22.5ns)
    localparam tWR = 2;    // Write recovery time (15ns)
    localparam tREF = 1560; // Refresh period (64ms / 8192 rows = ~7.8us)
    
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
    // [6:4]   - CAS Latency (3)
    // [3]     - Burst Type (0 = Sequential, 1 = Interleaved)
    // [2:0]   - Burst Length (0 = 1, 1 = 2, 2 = 4, 3 = 8, 7 = Full page)
    localparam MODE_REG = 13'b000_1_00_011_0_000; // CAS=3, Sequential, Burst=1, Single location write
    
    // State machine states
    localparam STATE_INIT = 0;
    localparam STATE_IDLE = 1;
    localparam STATE_REFRESH = 2;
    localparam STATE_ACTIVATE_A = 3;
    localparam STATE_READ_A = 4;
    localparam STATE_READ_DATA_A = 5;
    localparam STATE_WRITE_A = 6;
    localparam STATE_PRECHARGE_A = 7;
    localparam STATE_ACTIVATE_B = 8;
    localparam STATE_READ_B = 9;
    localparam STATE_READ_DATA_B = 10;
    localparam STATE_WRITE_B = 11;
    localparam STATE_PRECHARGE_B = 12;
    localparam STATE_ROM_WRITE = 13;
    localparam STATE_PRECHARGE_ALL = 14;
    
    // State and counters
    reg [4:0] state = STATE_INIT;
    reg [4:0] next_state = STATE_INIT;
    reg [15:0] init_counter = 0;
    reg [11:0] refresh_counter = 0;
    reg [3:0] delay_counter = 0;
    
    // Bank status tracking (for bank interleaving)
    reg [3:0] bank_status [0:3]; // 0=closed, 1=port A, 2=port B
    reg [12:0] open_rows [0:3];  // Currently open row in each bank
    
    // Internal signals
    reg [24:0] active_addr;
    reg [15:0] write_data;
    reg [15:0] read_data;
    reg data_ready;
    reg [1:0] active_bank;
    reg [12:0] active_row;
    reg [9:0] active_col;
    
    // Port arbitration
    reg port_select; // 0 = Port A, 1 = Port B
    reg a_pending, b_pending;
    
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
    
    // Bank status initialization
    integer i;
    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            bank_status[i] = 0;
            open_rows[i] = 0;
        end
    end
    
    // Main state machine
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_INIT;
            init_counter <= 0;
            refresh_counter <= 0;
            delay_counter <= 0;
            a_ready <= 0;
            b_ready <= 0;
            a_dout <= 0;
            b_dout <= 0;
            cmd <= CMD_NOP;
            sdram_dq_oe <= 0;
            sdram_dqml <= 1;
            sdram_dqmh <= 1;
            port_select <= 0;
            a_pending <= 0;
            b_pending <= 0;
            
            // Reset bank status
            for (i = 0; i < 4; i = i + 1) begin
                bank_status[i] <= 0;
                open_rows[i] <= 0;
            end
        end else begin
            // Default values
            cmd <= CMD_NOP;
            a_ready <= 0;
            b_ready <= 0;
            
            // Increment refresh counter
            if (refresh_counter < tREF)
                refresh_counter <= refresh_counter + 1;
                
            // Track pending requests
            if (a_rd || a_wr) a_pending <= 1;
            if (b_rd || b_wr) b_pending <= 1;
            
            // Decrement delay counter if active
            if (delay_counter > 0)
                delay_counter <= delay_counter - 1;
                
            // State machine
            case (state)
                STATE_INIT: begin
                    // SDRAM initialization sequence
                    if (init_counter < 20000) begin
                        // Wait for 150us (19950 cycles at 133MHz)
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
                    // Default - no data bus drive
                    sdram_dq_oe <= 0;
                    
                    // Check if refresh is needed
                    if (refresh_counter >= tREF) begin
                        // Need to precharge any open banks before refresh
                        if (|bank_status) begin
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 1; // All banks
                            state <= STATE_REFRESH;
                            delay_counter <= tRP;
                            
                            // Mark all banks as closed
                            for (i = 0; i < 4; i = i + 1) begin
                                bank_status[i] <= 0;
                            end
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
                        active_bank <= rom_addr[24:23];
                        active_row <= rom_addr[22:10];
                        active_col <= rom_addr[9:0];
                        
                        // Check if bank is open with different row
                        if (bank_status[rom_addr[24:23]] && open_rows[rom_addr[24:23]] != rom_addr[22:10]) begin
                            // Need to precharge first
                            cmd <= CMD_PRECHARGE;
                            sdram_a[10] <= 0; // Current bank only
                            sdram_ba <= rom_addr[24:23];
                            state <= STATE_ACTIVATE_A; // Reuse port A path for ROM
                            next_state <= STATE_ROM_WRITE;
                            delay_counter <= tRP;
                            bank_status[rom_addr[24:23]] <= 0;
                        end else if (!bank_status[rom_addr[24:23]]) begin
                            // Bank closed, activate row
                            cmd <= CMD_ACTIVE;
                            sdram_a <= rom_addr[22:10]; // Row address
                            sdram_ba <= rom_addr[24:23]; // Bank
                            state <= STATE_ROM_WRITE;
                            delay_counter <= tRCD;
                            bank_status[rom_addr[24:23]] <= 1; // Mark as used by port A
                            open_rows[rom_addr[24:23]] <= rom_addr[22:10];
                        end else begin
                            // Bank already open with correct row
                            state <= STATE_ROM_WRITE;
                        end
                    end
                    // Process port A request (if pending and not waiting for delay)
                    else if (a_pending && delay_counter == 0) begin
                        a_pending <= 0;
                        if (a_rd) begin
                            active_addr <= a_addr;
                            active_bank <= a_addr[24:23];
                            active_row <= a_addr[22:10];
                            active_col <= a_addr[9:0];
                            
                            // Check bank status
                            if (bank_status[a_addr[24:23]] == 2) begin
                                // Bank used by port B, need to precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= a_addr[24:23];
                                state <= STATE_ACTIVATE_A;
                                delay_counter <= tRP;
                                bank_status[a_addr[24:23]] <= 0;
                            end else if (bank_status[a_addr[24:23]] == 1 && open_rows[a_addr[24:23]] != a_addr[22:10]) begin
                                // Bank used by port A but different row, precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= a_addr[24:23];
                                state <= STATE_ACTIVATE_A;
                                delay_counter <= tRP;
                                bank_status[a_addr[24:23]] <= 0;
                            end else if (!bank_status[a_addr[24:23]]) begin
                                // Bank closed, activate row
                                cmd <= CMD_ACTIVE;
                                sdram_a <= a_addr[22:10]; // Row address
                                sdram_ba <= a_addr[24:23]; // Bank
                                state <= STATE_READ_A;
                                delay_counter <= tRCD;
                                bank_status[a_addr[24:23]] <= 1; // Mark as used by port A
                                open_rows[a_addr[24:23]] <= a_addr[22:10];
                            end else begin
                                // Bank already open with correct row for port A
                                state <= STATE_READ_A;
                            end
                        end else if (a_wr) begin
                            // Similar logic for write operations
                            active_addr <= a_addr;
                            write_data <= a_din;
                            active_bank <= a_addr[24:23];
                            active_row <= a_addr[22:10];
                            active_col <= a_addr[9:0];
                            
                            // Check bank status
                            if (bank_status[a_addr[24:23]] == 2) begin
                                // Bank used by port B, need to precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= a_addr[24:23];
                                state <= STATE_ACTIVATE_A;
                                delay_counter <= tRP;
                                bank_status[a_addr[24:23]] <= 0;
                            end else if (bank_status[a_addr[24:23]] == 1 && open_rows[a_addr[24:23]] != a_addr[22:10]) begin
                                // Bank used by port A but different row, precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= a_addr[24:23];
                                state <= STATE_ACTIVATE_A;
                                delay_counter <= tRP;
                                bank_status[a_addr[24:23]] <= 0;
                            end else if (!bank_status[a_addr[24:23]]) begin
                                // Bank closed, activate row
                                cmd <= CMD_ACTIVE;
                                sdram_a <= a_addr[22:10]; // Row address
                                sdram_ba <= a_addr[24:23]; // Bank
                                state <= STATE_WRITE_A;
                                delay_counter <= tRCD;
                                bank_status[a_addr[24:23]] <= 1; // Mark as used by port A
                                open_rows[a_addr[24:23]] <= a_addr[22:10];
                            end else begin
                                // Bank already open with correct row for port A
                                state <= STATE_WRITE_A;
                            end
                        end
                    end
                    // Process port B request (if pending and not waiting for delay)
                    else if (b_pending && delay_counter == 0) begin
                        b_pending <= 0;
                        if (b_rd) begin
                            active_addr <= b_addr;
                            active_bank <= b_addr[24:23];
                            active_row <= b_addr[22:10];
                            active_col <= b_addr[9:0];
                            
                            // Check bank status
                            if (bank_status[b_addr[24:23]] == 1) begin
                                // Bank used by port A, need to precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= b_addr[24:23];
                                state <= STATE_ACTIVATE_B;
                                delay_counter <= tRP;
                                bank_status[b_addr[24:23]] <= 0;
                            end else if (bank_status[b_addr[24:23]] == 2 && open_rows[b_addr[24:23]] != b_addr[22:10]) begin
                                // Bank used by port B but different row, precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= b_addr[24:23];
                                state <= STATE_ACTIVATE_B;
                                delay_counter <= tRP;
                                bank_status[b_addr[24:23]] <= 0;
                            end else if (!bank_status[b_addr[24:23]]) begin
                                // Bank closed, activate row
                                cmd <= CMD_ACTIVE;
                                sdram_a <= b_addr[22:10]; // Row address
                                sdram_ba <= b_addr[24:23]; // Bank
                                state <= STATE_READ_B;
                                delay_counter <= tRCD;
                                bank_status[b_addr[24:23]] <= 2; // Mark as used by port B
                                open_rows[b_addr[24:23]] <= b_addr[22:10];
                            end else begin
                                // Bank already open with correct row for port B
                                state <= STATE_READ_B;
                            end
                        end else if (b_wr) begin
                            // Similar logic for write operations
                            active_addr <= b_addr;
                            write_data <= b_din;
                            active_bank <= b_addr[24:23];
                            active_row <= b_addr[22:10];
                            active_col <= b_addr[9:0];
                            
                            // Check bank status
                            if (bank_status[b_addr[24:23]] == 1) begin
                                // Bank used by port A, need to precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= b_addr[24:23];
                                state <= STATE_ACTIVATE_B;
                                delay_counter <= tRP;
                                bank_status[b_addr[24:23]] <= 0;
                            end else if (bank_status[b_addr[24:23]] == 2 && open_rows[b_addr[24:23]] != b_addr[22:10]) begin
                                // Bank used by port B but different row, precharge
                                cmd <= CMD_PRECHARGE;
                                sdram_a[10] <= 0; // Current bank only
                                sdram_ba <= b_addr[24:23];
                                state <= STATE_ACTIVATE_B;
                                delay_counter <= tRP;
                                bank_status[b_addr[24:23]] <= 0;
                            end else if (!bank_status[b_addr[24:23]]) begin
                                // Bank closed, activate row
                                cmd <= CMD_ACTIVE;
                                sdram_a <= b_addr[22:10]; // Row address
                                sdram_ba <= b_addr[24:23]; // Bank
                                state <= STATE_WRITE_B;
                                delay_counter <= tRCD;
                                bank_status[b_addr[24:23]] <= 2; // Mark as used by port B
                                open_rows[b_addr[24:23]] <= b_addr[22:10];
                            end else begin
                                // Bank already open with correct row for port B
                                state <= STATE_WRITE_B;
                            end
                        end
                    end
                end
                
                STATE_REFRESH: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_REFRESH;
                        state <= STATE_IDLE;
                        refresh_counter <= 0;
                        delay_counter <= 8; // tRFC
                    end
                end
                
                STATE_ACTIVATE_A: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_ACTIVE;
                        sdram_a <= active_row;
                        sdram_ba <= active_bank;
                        bank_status[active_bank] <= 1; // Mark as used by port A
                        open_rows[active_bank] <= active_row;
                        
                        if (next_state != 0) begin
                            state <= next_state;
                            next_state <= 0;
                        end else if (a_rd) begin
                            state <= STATE_READ_A;
                        end else begin
                            state <= STATE_WRITE_A;
                        end
                        
                        delay_counter <= tRCD;
                    end
                end
                
                STATE_READ_A: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_READ;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_ba <= active_bank;
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        state <= STATE_READ_DATA_A;
                        delay_counter <= tCAS;
                    end
                end
                
                STATE_READ_DATA_A: begin
                    if (delay_counter == 0) begin
                        // Data is available on sdram_dq
                        a_dout <= sdram_dq;
                        a_ready <= 1;
                        state <= STATE_IDLE;
                    end
                end
                
                STATE_WRITE_A: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_WRITE;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_ba <= active_bank;
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        
                        // Drive data bus
                        sdram_dq_oe <= 1;
                        sdram_dq_out <= write_data;
                        
                        state <= STATE_PRECHARGE_A;
                        delay_counter <= tWR;
                    end
                end
                
                STATE_PRECHARGE_A: begin
                    // Stop driving data bus
                    sdram_dq_oe <= 0;
                    
                    if (delay_counter == 0) begin
                        cmd <= CMD_PRECHARGE;
                        sdram_a[10] <= 0; // Current bank only
                        sdram_ba <= active_bank;
                        bank_status[active_bank] <= 0; // Mark bank as closed
                        
                        a_ready <= 1;
                        state <= STATE_IDLE;
                        delay_counter <= tRP;
                    end
                end
                
                STATE_ACTIVATE_B: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_ACTIVE;
                        sdram_a <= active_row;
                        sdram_ba <= active_bank;
                        bank_status[active_bank] <= 2; // Mark as used by port B
                        open_rows[active_bank] <= active_row;
                        
                        if (b_rd) begin
                            state <= STATE_READ_B;
                        end else begin
                            state <= STATE_WRITE_B;
                        end
                        
                        delay_counter <= tRCD;
                    end
                end
                
                STATE_READ_B: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_READ;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_ba <= active_bank;
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        state <= STATE_READ_DATA_B;
                        delay_counter <= tCAS;
                    end
                end
                
                STATE_READ_DATA_B: begin
                    if (delay_counter == 0) begin
                        // Data is available on sdram_dq
                        b_dout <= sdram_dq;
                        b_ready <= 1;
                        state <= STATE_IDLE;
                    end
                end
                
                STATE_WRITE_B: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_WRITE;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_ba <= active_bank;
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        
                        // Drive data bus
                        sdram_dq_oe <= 1;
                        sdram_dq_out <= write_data;
                        
                        state <= STATE_PRECHARGE_B;
                        delay_counter <= tWR;
                    end
                end
                
                STATE_PRECHARGE_B: begin
                    // Stop driving data bus
                    sdram_dq_oe <= 0;
                    
                    if (delay_counter == 0) begin
                        cmd <= CMD_PRECHARGE;
                        sdram_a[10] <= 0; // Current bank only
                        sdram_ba <= active_bank;
                        bank_status[active_bank] <= 0; // Mark bank as closed
                        
                        b_ready <= 1;
                        state <= STATE_IDLE;
                        delay_counter <= tRP;
                    end
                end
                
                STATE_ROM_WRITE: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_WRITE;
                        sdram_a <= {3'b000, active_col}; // Column address
                        sdram_ba <= active_bank;
                        sdram_a[10] <= 0; // No auto-precharge
                        sdram_dqml <= 0; // Enable both bytes
                        sdram_dqmh <= 0;
                        
                        // Drive data bus
                        sdram_dq_oe <= 1;
                        sdram_dq_out <= write_data;
                        
                        state <= STATE_IDLE;
                        delay_counter <= tWR;
                    end
                end
                
                STATE_PRECHARGE_ALL: begin
                    if (delay_counter == 0) begin
                        cmd <= CMD_PRECHARGE;
                        sdram_a[10] <= 1; // All banks
                        
                        // Mark all banks as closed
                        for (i = 0; i < 4; i = i + 1) begin
                            bank_status[i] <= 0;
                        end
                        
                        state <= STATE_IDLE;
                        delay_counter <= tRP;
                    end
                end
                
                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
