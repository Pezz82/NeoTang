module neogeo_top (
    // Clock and reset
    input wire clk_sys,        // 96 MHz system clock
    input wire reset,          // Active high reset
    
    // Wishbone bus interface
    input wire wb_clk_i,
    output wire [31:0] wb_adr_o,
    input wire [31:0] wb_dat_i,
    output wire [31:0] wb_dat_o,
    output wire [3:0] wb_sel_o,
    output wire wb_we_o,
    output wire wb_stb_o,
    output wire wb_cyc_o,
    input wire wb_ack_i,
    
    // Video output
    output wire [7:0] VIDEO_R,
    output wire [7:0] VIDEO_G,
    output wire [7:0] VIDEO_B,
    output wire HSYNC,
    output wire VSYNC,
    output wire HBLANK,
    output wire VBLANK,
    
    // Audio output
    output wire [15:0] AUDIO_L,
    output wire [15:0] AUDIO_R,
    
    // Input from MCU mailbox
    input wire [31:0] input_reg,    // Current input state
    input wire [31:0] command_reg   // Command FIFO
);

    // ========================================================================
    // MiSTer NeoGeo Core Instance
    // ========================================================================
    
    // Instantiate the MiSTer NeoGeo core
    mister_ng_top uut (
        // Clock and reset
        .clk_sys(clk_sys),
        .reset(reset),
        
        // Video output
        .VIDEO_R(VIDEO_R),
        .VIDEO_G(VIDEO_G),
        .VIDEO_B(VIDEO_B),
        .HSYNC(HSYNC),
        .VSYNC(VSYNC),
        .HBLANK(HBLANK),
        .VBLANK(VBLANK),
        
        // Audio output
        .AUDIO_L(AUDIO_L),
        .AUDIO_R(AUDIO_R),
        
        // SDRAM interface - Port A
        .sdram_addr(neo_sdram_a_addr),
        .sdram_dq(neo_sdram_a_dout),
        .sdram_we(neo_sdram_a_wr),
        .sdram_oe(neo_sdram_a_rd),
        
        // SDRAM interface - Port B (C-ROM)
        .sdram2_addr(neo_sdram_b_addr),
        .sdram2_dq(neo_sdram_b_dout),
        .sdram2_we(neo_sdram_b_wr),
        .sdram2_oe(neo_sdram_b_rd),
        
        // Controller inputs from MCU mailbox
        .JOYSTICK_1(input_reg[7:0]),    // Player 1 controls
        .JOYSTICK_2(input_reg[15:8]),   // Player 2 controls
        .SYSTEM(input_reg[23:16])       // System controls
    );
    
    // ========================================================================
    // Wishbone Bus Interface
    // ========================================================================
    
    // SDRAM interface signals
    wire [24:0] neo_sdram_a_addr;
    wire [15:0] neo_sdram_a_dout;
    wire neo_sdram_a_wr;
    wire neo_sdram_a_rd;
    
    wire [24:0] neo_sdram_b_addr;
    wire [15:0] neo_sdram_b_dout;
    wire neo_sdram_b_wr;
    wire neo_sdram_b_rd;
    
    // Wishbone bus state machine
    reg [1:0] wb_state;
    reg [31:0] wb_addr;
    reg [31:0] wb_data;
    reg wb_we;
    
    localparam WB_IDLE = 2'b00;
    localparam WB_READ = 2'b01;
    localparam WB_WRITE = 2'b10;
    
    // Wishbone bus control
    always @(posedge wb_clk_i) begin
        if (reset) begin
            wb_state <= WB_IDLE;
            wb_addr <= 32'h0;
            wb_data <= 32'h0;
            wb_we <= 1'b0;
        end else begin
            case (wb_state)
                WB_IDLE: begin
                    if (neo_sdram_a_rd || neo_sdram_b_rd) begin
                        wb_state <= WB_READ;
                        wb_addr <= neo_sdram_a_rd ? {7'h0, neo_sdram_a_addr} : {7'h0, neo_sdram_b_addr};
                        wb_we <= 1'b0;
                    end else if (neo_sdram_a_wr || neo_sdram_b_wr) begin
                        wb_state <= WB_WRITE;
                        wb_addr <= neo_sdram_a_wr ? {7'h0, neo_sdram_a_addr} : {7'h0, neo_sdram_b_addr};
                        wb_data <= neo_sdram_a_wr ? {16'h0, neo_sdram_a_dout} : {16'h0, neo_sdram_b_dout};
                        wb_we <= 1'b1;
                    end
                end
                
                WB_READ: begin
                    if (wb_ack_i) begin
                        wb_state <= WB_IDLE;
                    end
                end
                
                WB_WRITE: begin
                    if (wb_ack_i) begin
                        wb_state <= WB_IDLE;
                    end
                end
            endcase
        end
    end
    
    // Wishbone bus outputs
    assign wb_adr_o = wb_addr;
    assign wb_dat_o = wb_data;
    assign wb_sel_o = 4'hF;  // Always 32-bit access
    assign wb_we_o = wb_we;
    assign wb_stb_o = (wb_state != WB_IDLE);
    assign wb_cyc_o = (wb_state != WB_IDLE);

endmodule 