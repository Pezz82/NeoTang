// NeoGeo Loader FSM
// Receives data from iosys and writes to DDR via memory bridge.
// Handles handshake (ACK?) and controls core reset.

module neogeo_loader #(
    parameter ADDR_WIDTH = 25,
    parameter DATA_WIDTH = 32 // Assuming loader writes 32-bit words
)(
    input  logic clk,
    input  logic rst_n,

    // --- Interface from IOSys ---
    input  logic [7:0] io_rom_do,
    input  logic       io_rom_do_valid,
    // input  logic [31:0] io_load_cmd, // How to get load address/size?
    output logic       io_ack,          // Acknowledge byte received?

    // --- Master Interface to Memory Bridge (e.g., RV simple interface) ---
    output logic                  mem_valid_o,
    input  logic                  mem_ready_i,
    output logic [ADDR_WIDTH-1:0] mem_addr_o,
    output logic [DATA_WIDTH-1:0] mem_wdata_o,
    output logic [3:0]            mem_be_o,
    output logic                  mem_we_o,      // Assume loader only writes
    input  logic [DATA_WIDTH-1:0] mem_rdata_i, // Read port (unused by loader?)

    // --- Outputs ---
    output logic game_loaded_o, // Pulse when loading complete
    output logic cpu_reset_n_o // Controls the main core's reset (active low)
);

    typedef enum logic [2:0] {
        IDLE,
        WAIT_FOR_CMD,  // How does loading start? Address/size?
        RECEIVE_BYTE,
        WRITE_MEM_REQ, 
        WRITE_MEM_WAIT,
        FINISH
    } state_t;

    state_t current_state, next_state;

    logic [ADDR_WIDTH-1:0] current_addr;
    logic [DATA_WIDTH-1:0] write_buffer;
    logic [1:0]            byte_count; // Count bytes for 32-bit word
    logic [31:0]           total_bytes_loaded; // Need total size
    logic [31:0]           target_load_size; // How to set this?

    // Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_addr <= '0;
            write_buffer <= '0;
            byte_count <= '0;
            total_bytes_loaded <= '0;
            target_load_size <= 32'd128 * 1024; // Default: 128KB BIOS? Needs config.
            cpu_reset_n_o <= 1'b0; // Hold CPU in reset initially
            game_loaded_o <= 1'b0;
        end else begin
            current_state <= next_state;
            if (next_state == RECEIVE_BYTE && io_rom_do_valid) begin
                write_buffer <= {write_buffer[23:0], io_rom_do}; // Shift byte in
                byte_count <= byte_count + 1;
                current_addr <= current_addr + 1; // Increment byte address
                total_bytes_loaded <= total_bytes_loaded + 1;
            end
            if (next_state == WRITE_MEM_WAIT && mem_ready_i) begin
                // Address already incremented
            end
            if (next_state == FINISH) begin
                 game_loaded_o <= 1'b1;
                 cpu_reset_n_o <= 1'b1; // Release reset
            end else begin
                 game_loaded_o <= 1'b0; // Pulse
                 // Keep CPU in reset if not finished
                 if (current_state != FINISH) cpu_reset_n_o <= 1'b0;
            end
             // Update address/counters based on state transitions
        end
    end

    // FSM Logic
    always_comb begin
        next_state = current_state;
        io_ack = 1'b0;
        mem_valid_o = 1'b0;
        mem_addr_o = current_addr;
        mem_wdata_o = write_buffer;
        mem_be_o = 4'b0000;
        mem_we_o = 1'b0;

        case (current_state)
            IDLE: begin
                // How is loading triggered? Wait for a command?
                // Assume loading starts when io_rom_do_valid goes high?
                if (io_rom_do_valid) begin 
                    next_state = RECEIVE_BYTE;
                end
            end

            RECEIVE_BYTE: begin
                 // ACK byte received from iosys?
                 io_ack = io_rom_do_valid; 
                 if (io_rom_do_valid) begin
                     if (byte_count == 2'b11) begin // Got 4 bytes
                         next_state = WRITE_MEM_REQ;
                     end else begin
                         next_state = RECEIVE_BYTE; // Wait for next byte
                     end
                 end else begin
                      next_state = RECEIVE_BYTE; // Stay waiting
                 end
                 // Check if done loading
                 if (total_bytes_loaded >= target_load_size && target_load_size > 0) begin
                     next_state = FINISH;
                 end
            end

            WRITE_MEM_REQ: begin
                mem_valid_o = 1'b1;
                mem_we_o = 1'b1;
                mem_addr_o = current_addr - 4; // Address of the word we just assembled
                mem_wdata_o = write_buffer; // Assembled word
                mem_be_o = 4'b1111; // Write all 4 bytes
                if (mem_ready_i) begin // If bridge accepts immediately
                    next_state = RECEIVE_BYTE; // Go back to get next byte
                    byte_count = 0; // Reset byte count for next word
                    // Check if done loading
                     if (total_bytes_loaded >= target_load_size && target_load_size > 0) begin
                        next_state = FINISH;
                    end
                end else begin
                    next_state = WRITE_MEM_WAIT;
                end
            end
            
            WRITE_MEM_WAIT: begin
                // Keep signals asserted
                mem_valid_o = 1'b1;
                mem_we_o = 1'b1;
                mem_addr_o = current_addr - 4;
                mem_wdata_o = write_buffer;
                mem_be_o = 4'b1111;
                if (mem_ready_i) begin // Bridge accepted
                    next_state = RECEIVE_BYTE;
                    byte_count = 0; // Reset byte count for next word
                    // Check if done loading
                     if (total_bytes_loaded >= target_load_size && target_load_size > 0) begin
                        next_state = FINISH;
                    end
                end
            end

            FINISH: begin
                 // Stay here, game_loaded pulsed, cpu_reset released
                 next_state = FINISH;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule 