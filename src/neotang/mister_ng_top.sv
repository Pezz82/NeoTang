// MiSTer Neo-Geo top module for Tang 138K
// This is a wrapper around the MiSTer Neo-Geo core

module mister_ng_top (
    // Clock and reset
    input wire clk_sys,        // System clock (48 MHz)
    input wire reset,          // System reset
    
    // Video output
    output wire [7:0] VIDEO_R,
    output wire [7:0] VIDEO_G,
    output wire [7:0] VIDEO_B,
    output wire HSYNC,
    output wire VSYNC,
    output wire HBLANK,
    output wire VBLANK,
    output wire HDMI_DE,       // HDMI data enable
    
    // Audio output
    output wire [15:0] AUDIO_L,
    output wire [15:0] AUDIO_R,
    
    // SDRAM interface - Port A (P-ROM, S-ROM, M-ROM)
    output wire [24:0] sdram_addr,
    input wire [15:0] sdram_dq,
    output wire sdram_we,
    output wire sdram_oe,
    
    // SDRAM interface - Port B (C-ROM)
    output wire [24:0] sdram2_addr,
    input wire [15:0] sdram2_dq,
    output wire sdram2_we,
    output wire sdram2_oe,
    
    // Controller inputs
    input wire [7:0] JOYSTICK_1,
    input wire [7:0] JOYSTICK_2,
    input wire [7:0] SYSTEM
);

    // Generate 24 MHz clock enable signals from 48 MHz
    reg CLK_EN_24M_N, CLK_EN_24M_P;
    always @(posedge clk_sys) begin
        CLK_EN_24M_N <= ~CLK_EN_24M_N;
        CLK_EN_24M_P <= CLK_EN_24M_N;
    end

    // Stub for HPS_BUS
    wire [48:0] HPS_BUS = 49'd0;
    
    // Video signals
    wire CE_PIXEL;
    wire [12:0] VIDEO_ARX, VIDEO_ARY;
    wire VGA_DE;
    wire VGA_F1;
    wire [1:0] VGA_SL;
    wire VGA_SCALER;
    wire VGA_DISABLE;
    wire [11:0] HDMI_WIDTH, HDMI_HEIGHT;
    wire HDMI_FREEZE;
    wire HDMI_BLACKOUT;
    wire VIDEO_DE;
    
    // Audio signals
    wire [1:0] AUDIO_MIX;
    wire AUDIO_S;
    
    // Memory signals
    wire DDRAM_CLK;
    wire DDRAM_BUSY;
    wire [7:0] DDRAM_BURSTCNT;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DOUT;
    wire DDRAM_DOUT_READY;
    wire DDRAM_RD;
    wire [63:0] DDRAM_DIN;
    wire [7:0] DDRAM_BE;
    wire DDRAM_WE;
    
    wire SDRAM_CLK;
    wire SDRAM_CKE;
    wire [12:0] SDRAM_A;
    wire [1:0] SDRAM_BA;
    wire [15:0] SDRAM_DQ;
    wire SDRAM_DQML;
    wire SDRAM_DQMH;
    wire SDRAM_nCS;
    wire SDRAM_nCAS;
    wire SDRAM_nRAS;
    wire SDRAM_nWE;
    
    // Proper address mapping from MiSTer core to Tang SDRAM controller
    // MiSTer uses: BA[1:0], A[12:0], and internal column addressing
    // Tang needs: [24:23]=bank, [22:10]=row, [9:0]=column
    wire [24:0] SDRAM_ADDR_24;
    wire [24:0] SDRAM2_ADDR_24;
    
    // Extract column address from SDRAM_A - MiSTer typically uses A[9:0] for column
    // when SDRAM_A[10] is used for auto-precharge
    wire [9:0] SDRAM_COL = {SDRAM_A[9:0]};
    wire [9:0] SDRAM2_COL = {SDRAM2_A[9:0]};
    
    // Construct proper 25-bit address with bank, row, and column components
    assign SDRAM_ADDR_24 = {SDRAM_BA, SDRAM_A[12:0], SDRAM_COL};
    assign SDRAM2_ADDR_24 = {SDRAM2_BA, SDRAM2_A[12:0], SDRAM2_COL};
    
    // Secondary SDRAM
    wire SDRAM2_EN = 1'b1;
    wire SDRAM2_CLK;
    wire [12:0] SDRAM2_A;
    wire [1:0] SDRAM2_BA;
    wire [15:0] SDRAM2_DQ;
    wire SDRAM2_nCS;
    wire SDRAM2_nCAS;
    wire SDRAM2_nRAS;
    wire SDRAM2_nWE;
    
    // Other signals
    wire [1:0] LED_POWER;
    wire [1:0] LED_DISK;
    wire [1:0] BUTTONS;
    wire [6:0] USER_OUT;
    wire LED_USER;
    
    // ADC
    wire [3:0] ADC_BUS;
    
    // SD-SPI
    wire SD_SCK;
    wire SD_MOSI;
    wire SD_MISO = 1'b0;
    wire SD_CS;
    wire SD_CD = 1'b0;
    
    // UART
    wire UART_CTS = 1'b0;
    wire UART_RTS;
    wire UART_RXD = 1'b0;
    wire UART_TXD;
    wire UART_DTR;
    wire UART_DSR = 1'b0;
    
    // USER
    wire [6:0] USER_IN = 7'd0;
    
    // OSD
    wire OSD_STATUS = 1'b0;
    
    // Instantiate the MiSTer Neo-Geo core
    emu neogeo_core (
        .CLK_50M(clk_sys),
        .RESET(reset),
        .HPS_BUS(HPS_BUS),
        
        // Video
        .CLK_VIDEO(CLK_VIDEO),
        .CE_PIXEL(CE_PIXEL),
        .VIDEO_ARX(VIDEO_ARX),
        .VIDEO_ARY(VIDEO_ARY),
        .VGA_R(VIDEO_R),
        .VGA_G(VIDEO_G),
        .VGA_B(VIDEO_B),
        .VGA_HS(HSYNC),
        .VGA_VS(VSYNC),
        .VGA_DE(VGA_DE),
        .VGA_F1(VGA_F1),
        .VGA_SL(VGA_SL),
        .VGA_SCALER(VGA_SCALER),
        .VGA_DISABLE(VGA_DISABLE),
        .HDMI_WIDTH(HDMI_WIDTH),
        .HDMI_HEIGHT(HDMI_HEIGHT),
        .HDMI_FREEZE(HDMI_FREEZE),
        .HDMI_BLACKOUT(HDMI_BLACKOUT),
        
        // Audio
        .CLK_AUDIO(clk_sys),
        .AUDIO_L(AUDIO_L),
        .AUDIO_R(AUDIO_R),
        .AUDIO_S(AUDIO_S),
        .AUDIO_MIX(AUDIO_MIX),
        
        // DDRAM
        .DDRAM_CLK(DDRAM_CLK),
        .DDRAM_BUSY(DDRAM_BUSY),
        .DDRAM_BURSTCNT(DDRAM_BURSTCNT),
        .DDRAM_ADDR(DDRAM_ADDR),
        .DDRAM_DOUT(DDRAM_DOUT),
        .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
        .DDRAM_RD(DDRAM_RD),
        .DDRAM_DIN(DDRAM_DIN),
        .DDRAM_BE(DDRAM_BE),
        .DDRAM_WE(DDRAM_WE),
        
        // SDRAM
        .SDRAM_CLK(SDRAM_CLK),
        .SDRAM_CKE(SDRAM_CKE),
        .SDRAM_A(SDRAM_A),
        .SDRAM_BA(SDRAM_BA),
        .SDRAM_DQ(SDRAM_DQ),
        .SDRAM_DQML(SDRAM_DQML),
        .SDRAM_DQMH(SDRAM_DQMH),
        .SDRAM_nCS(SDRAM_nCS),
        .SDRAM_nCAS(SDRAM_nCAS),
        .SDRAM_nRAS(SDRAM_nRAS),
        .SDRAM_nWE(SDRAM_nWE),
        
        // SDRAM2
        .SDRAM2_EN(SDRAM2_EN),
        .SDRAM2_CLK(SDRAM2_CLK),
        .SDRAM2_A(SDRAM2_A),
        .SDRAM2_BA(SDRAM2_BA),
        .SDRAM2_DQ(SDRAM2_DQ),
        .SDRAM2_nCS(SDRAM2_nCS),
        .SDRAM2_nCAS(SDRAM2_nCAS),
        .SDRAM2_nRAS(SDRAM2_nRAS),
        .SDRAM2_nWE(SDRAM2_nWE),
        
        // LEDs and buttons
        .LED_USER(LED_USER),
        .LED_POWER(LED_POWER),
        .LED_DISK(LED_DISK),
        .BUTTONS(BUTTONS),
        
        // ADC
        .ADC_BUS(ADC_BUS),
        
        // SD
        .SD_SCK(SD_SCK),
        .SD_MOSI(SD_MOSI),
        .SD_MISO(SD_MISO),
        .SD_CS(SD_CS),
        .SD_CD(SD_CD),
        
        // UART
        .UART_CTS(UART_CTS),
        .UART_RTS(UART_RTS),
        .UART_RXD(UART_RXD),
        .UART_TXD(UART_TXD),
        .UART_DTR(UART_DTR),
        .UART_DSR(UART_DSR),
        
        // USER
        .USER_IN(USER_IN),
        .USER_OUT(USER_OUT),
        
        // OSD
        .OSD_STATUS(OSD_STATUS)
    );
    
    // Connect SDRAM signals to our dual-port SDRAM controller
    // Port A handles P-ROM, S-ROM, M-ROM (primary port)
    assign sdram_addr = {1'b0, SDRAM_ADDR_24};  // pad MSB to make 25-bit address
    assign sdram_we = ~SDRAM_nWE & ~SDRAM_nCS;
    assign sdram_oe = SDRAM_nWE & ~SDRAM_nCS;
    assign SDRAM_DQ = sdram_dq; // Connect the bidirectional data bus
    
    // Port B handles C-ROM (secondary port for sprites)
    assign sdram2_addr = {1'b0, SDRAM2_ADDR_24};  // pad MSB to make 25-bit address
    assign sdram2_we = ~SDRAM2_nWE & ~SDRAM2_nCS;
    assign sdram2_oe = SDRAM2_nWE & ~SDRAM2_nCS;
    assign SDRAM2_DQ = sdram2_dq; // Connect the bidirectional data bus
    
    // Connect blanking signals - properly separate H and V blanking
    // The MiSTer core likely generates separate HBlank and VBlank internally
    // We need to extract these from the core's timing signals
    reg hblank_reg, vblank_reg;
    
    // Detect horizontal blanking from HSYNC transitions
    // NeoGeo has active high sync, so falling edge indicates start of blanking
    reg hsync_prev;
    always @(posedge clk_sys) begin
        hsync_prev <= HSYNC;
        if (reset) begin
            hblank_reg <= 1'b1;  // Start in blanking state
        end else if (hsync_prev && !HSYNC) begin
            // Falling edge of HSYNC - start of horizontal blanking
            hblank_reg <= 1'b1;
        end else if (!hsync_prev && HSYNC) begin
            // Rising edge of HSYNC - end of horizontal blanking
            hblank_reg <= 1'b0;
        end
    end
    
    // Detect vertical blanking from VSYNC transitions
    reg vsync_prev;
    always @(posedge clk_sys) begin
        vsync_prev <= VSYNC;
        if (reset) begin
            vblank_reg <= 1'b1;  // Start in blanking state
        end else if (vsync_prev && !VSYNC) begin
            // Falling edge of VSYNC - start of vertical blanking
            vblank_reg <= 1'b1;
        end else if (!vsync_prev && VSYNC) begin
            // Rising edge of VSYNC - end of vertical blanking
            vblank_reg <= 1'b0;
        end
    end
    
    // Assign blanking outputs
    assign HBLANK = hblank_reg;
    assign VBLANK = vblank_reg;
    assign VIDEO_DE = ~(hblank_reg | vblank_reg);  // DE is active when not in blanking

    assign HDMI_DE = VIDEO_DE;

endmodule
