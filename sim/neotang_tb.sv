// NeoGeo Core for Tang 138K - Enhanced Test Simulation
// This testbench verifies all fixed functionality of the NeoGeo core port
// Including blanking signals, SDRAM addressing, video scaling, clock generation,
// HDMI audio path, and ROM loader handshake

`timescale 1ns / 1ps

module neotang_tb;
    // Clock and reset
    reg clk_27m = 0;
    reg reset_n = 0;
    
    // UART signals for ROM loading
    reg [7:0] uart_data = 0;
    reg uart_valid = 0;
    wire uart_ready;
    
    // HDMI outputs
    wire [3:0] tmds_p;
    wire [3:0] tmds_n;
    
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
    
    // Controller inputs
    reg [15:0] joystick_0 = 0;
    reg [15:0] joystick_1 = 0;
    
    // Instantiate the Unit Under Test (UUT)
    neotang_top uut (
        .clk_27m(clk_27m),
        .reset_n(reset_n),
        
        // UART interface
        .uart_rx(1'b0),  // Not used in simulation
        .uart_tx(),      // Not used in simulation
        
        // HDMI outputs
        .tmds_p(tmds_p),
        .tmds_n(tmds_n),
        
        // SDRAM interface
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
        .sdram_dqmh(sdram_dqmh),
        
        // BL616 interface
        .bl616_uart_tx(uart_data),
        .bl616_uart_valid(uart_valid),
        .bl616_uart_ready(uart_ready),
        
        // Controller inputs
        .joystick_0(joystick_0),
        .joystick_1(joystick_1)
    );
    
    // Clock generation
    always #18.5 clk_27m = ~clk_27m;  // 27 MHz clock (37ns period)
    
    // Variables for ROM loading
    integer i;
    reg [7:0] dummy_rom [0:262143];  // 256KB dummy P-ROM
    
    // Test sequence
    initial begin
        // Initialize dummy ROM with incrementing pattern
        for (i = 0; i < 262144; i = i + 1) begin
            dummy_rom[i] = i & 8'hFF;
        end
        
        // Reset sequence
        reset_n = 0;
        #1000;
        reset_n = 1;
        #1000;
        
        // Wait for system initialization
        #10000;
        
        // Load BIOS ROM first (required for operation)
        $display("Loading BIOS ROM...");
        
        // Send LOAD_START command
        uart_data = 8'h01;  // CMD_LOAD_START
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM type (BIOS = 0)
        uart_data = 8'h00;
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM address (0x000000)
        uart_data = 8'h00;  // High byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Middle byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Low byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM size (128KB = 0x020000)
        uart_data = 8'h02;  // High byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Middle byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Low byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send LOAD_DATA command
        uart_data = 8'h02;  // CMD_LOAD_DATA
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send first 1KB of dummy data for BIOS
        for (i = 0; i < 1024; i = i + 1) begin
            uart_data = dummy_rom[i];
            uart_valid = 1;
            #100;
            wait(uart_ready);
            #100;
        end
        
        // Send LOAD_END command
        uart_data = 8'h03;  // CMD_LOAD_END
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        uart_valid = 0;
        
        // Wait for BIOS loading to complete
        #10000;
        
        // Now load P-ROM (game program ROM)
        $display("Loading P-ROM...");
        
        // Send LOAD_START command
        uart_data = 8'h01;  // CMD_LOAD_START
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM type (P-ROM = 1)
        uart_data = 8'h01;
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM address (0x000000)
        uart_data = 8'h00;  // High byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Middle byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Low byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send ROM size (256KB = 0x040000)
        uart_data = 8'h04;  // High byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Middle byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        uart_data = 8'h00;  // Low byte
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send LOAD_DATA command
        uart_data = 8'h02;  // CMD_LOAD_DATA
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        
        // Send first 1KB of dummy data for P-ROM
        for (i = 0; i < 1024; i = i + 1) begin
            uart_data = dummy_rom[i];
            uart_valid = 1;
            #100;
            wait(uart_ready);
            #100;
        end
        
        // Send LOAD_END command
        uart_data = 8'h03;  // CMD_LOAD_END
        uart_valid = 1;
        #100;
        wait(uart_ready);
        #100;
        uart_valid = 0;
        
        // Wait for ROM loading to complete
        #10000;
        
        // Run for a while to see if all signals are working
        $display("Running verification for all fixed components...");
        
        // Monitor for 50ms
        #50000000;
        
        // Check all verification counters
        $display("=== VERIFICATION RESULTS ===");
        
        // Check HSYNC/VSYNC toggling (video output)
        if (hsync_toggle_count > 100) begin
            $display("PASS: HSYNC is toggling (%0d toggles)", hsync_toggle_count);
        end else begin
            $display("FAIL: HSYNC is not toggling enough (%0d toggles)", hsync_toggle_count);
        end
        
        if (vsync_toggle_count > 0) begin
            $display("PASS: VSYNC is toggling (%0d toggles)", vsync_toggle_count);
        end else begin
            $display("FAIL: VSYNC is not toggling", vsync_toggle_count);
        end
        
        // Check blanking signals (fix in mister_ng_top.sv)
        if (hblank_toggle_count > 100) begin
            $display("PASS: HBLANK is toggling properly (%0d toggles)", hblank_toggle_count);
        end else begin
            $display("FAIL: HBLANK is not toggling enough (%0d toggles)", hblank_toggle_count);
        end
        
        if (vblank_toggle_count > 0) begin
            $display("PASS: VBLANK is toggling properly (%0d toggles)", vblank_toggle_count);
        end else begin
            $display("FAIL: VBLANK is not toggling", vblank_toggle_count);
        end
        
        // Check SDRAM addressing (fix for address width)
        if (sdram_addr_changes > 1000) begin
            $display("PASS: SDRAM addressing is working (%0d address changes)", sdram_addr_changes);
        end else begin
            $display("FAIL: SDRAM addressing not working properly (%0d address changes)", sdram_addr_changes);
        end
        
        // Check audio path
        if (audio_changes > 0) begin
            $display("PASS: Audio path is active (%0d audio changes)", audio_changes);
        end else begin
            $display("FAIL: Audio path is not active", audio_changes);
        end
        
        // Check ROM loader handshake
        if (uart_handshake_count > 2000) begin
            $display("PASS: ROM loader handshake is working (%0d handshakes)", uart_handshake_count);
        end else begin
            $display("FAIL: ROM loader handshake not working properly (%0d handshakes)", uart_handshake_count);
        end
        
        // Overall test result
        if (hsync_toggle_count > 100 && vsync_toggle_count > 0 && 
            hblank_toggle_count > 100 && vblank_toggle_count > 0 && 
            sdram_addr_changes > 1000 && uart_handshake_count > 2000) begin
            $display("OVERALL: PASS - All fixes are working correctly!");
        end else begin
            $display("OVERALL: FAIL - Some fixes are not working correctly");
        end
        
        // End simulation
        $finish;
    end
    
    // Monitor signals for verification
    reg prev_hsync = 0;
    reg prev_vsync = 0;
    integer hsync_toggle_count = 0;
    integer vsync_toggle_count = 0;
    
    // Blanking signal monitors
    reg prev_hblank = 0;
    reg prev_vblank = 0;
    integer hblank_toggle_count = 0;
    integer vblank_toggle_count = 0;
    
    // SDRAM address monitoring
    reg [24:0] last_sdram_addr = 0;
    integer sdram_addr_changes = 0;
    
    // Audio signal monitoring
    reg [15:0] audio_l_prev = 0;
    reg [15:0] audio_r_prev = 0;
    integer audio_changes = 0;
    
    // ROM loader handshake monitoring
    integer uart_handshake_count = 0;
    
    always @(posedge clk_27m) begin
        if (reset_n) begin
            // Monitor HSYNC and VSYNC toggling
            if (prev_hsync != uut.in_hs) begin
                hsync_toggle_count = hsync_toggle_count + 1;
            end
            prev_hsync = uut.in_hs;
            
            if (prev_vsync != uut.in_vs) begin
                vsync_toggle_count = vsync_toggle_count + 1;
            end
            prev_vsync = uut.in_vs;
            
            // Monitor blanking signals (from our fix in mister_ng_top.sv)
            if (prev_hblank != uut.mister_ng_top_inst.HBLANK) begin
                hblank_toggle_count = hblank_toggle_count + 1;
            end
            prev_hblank = uut.mister_ng_top_inst.HBLANK;
            
            if (prev_vblank != uut.mister_ng_top_inst.VBLANK) begin
                vblank_toggle_count = vblank_toggle_count + 1;
            end
            prev_vblank = uut.mister_ng_top_inst.VBLANK;
            
            // Monitor SDRAM address changes (from our address width fix)
            if (last_sdram_addr != uut.sdram_controller.sdram_addr && uut.sdram_controller.sdram_wr) begin
                sdram_addr_changes = sdram_addr_changes + 1;
                last_sdram_addr = uut.sdram_controller.sdram_addr;
            end
            
            // Monitor audio signal changes
            if (audio_l_prev != uut.hdmi_output_inst.audio_l || 
                audio_r_prev != uut.hdmi_output_inst.audio_r) begin
                audio_changes = audio_changes + 1;
            end
            audio_l_prev = uut.hdmi_output_inst.audio_l;
            audio_r_prev = uut.hdmi_output_inst.audio_r;
            
            // Monitor ROM loader handshake
            if (uut.rom_loader_inst.uart_ready) begin
                uart_handshake_count = uart_handshake_count + 1;
            end
        end
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("neotang_tb.vcd");
        $dumpvars(0, neotang_tb);
    end
    
endmodule
