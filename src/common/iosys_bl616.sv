module iosys_bl616 (
    input  wire        clk,
    input  wire        rst_n,
    
    // BL616 UART interface
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // Core control interface
    output wire        core_reset,
    output wire [7:0]  core_buttons,
    output wire [7:0]  core_dipsw,
    output wire        core_coin,
    output wire        core_service,
    
    // ROM loading interface
    output wire [31:0] rom_addr,
    output wire [15:0] rom_data,
    output wire        rom_wr,
    output wire        rom_rd,
    input  wire [15:0] rom_data_in,
    output wire        rom_loading,
    
    // Status interface
    output wire [7:0]  status,
    input  wire [7:0]  core_status
);

    // UART parameters
    parameter CLKS_PER_BIT = 868;  // 27MHz / 31250 baud
    
    // Command codes
    localparam CMD_RESET     = 8'h01;
    localparam CMD_BUTTONS   = 8'h02;
    localparam CMD_DIPSW     = 8'h03;
    localparam CMD_COIN      = 8'h04;
    localparam CMD_SERVICE   = 8'h05;
    localparam CMD_ROM_ADDR  = 8'h06;
    localparam CMD_ROM_DATA  = 8'h07;
    localparam CMD_STATUS    = 8'h08;
    
    // UART receiver
    reg [7:0] rx_data;
    reg       rx_valid;
    
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid)
    );
    
    // Command parser
    reg [7:0] cmd;
    reg [7:0] cmd_data;
    reg       cmd_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd <= 8'h00;
            cmd_data <= 8'h00;
            cmd_valid <= 1'b0;
        end else if (rx_valid) begin
            if (!cmd_valid) begin
                cmd <= rx_data;
                cmd_valid <= 1'b1;
            end else begin
                cmd_data <= rx_data;
                cmd_valid <= 1'b0;
            end
        end
    end
    
    // Command handlers
    reg        core_reset_reg;
    reg [7:0]  core_buttons_reg;
    reg [7:0]  core_dipsw_reg;
    reg        core_coin_reg;
    reg        core_service_reg;
    reg [31:0] rom_addr_reg;
    reg [15:0] rom_data_reg;
    reg        rom_wr_reg;
    reg        rom_rd_reg;
    reg        rom_loading_reg;
    reg [7:0]  status_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_reset_reg <= 1'b0;
            core_buttons_reg <= 8'h00;
            core_dipsw_reg <= 8'h00;
            core_coin_reg <= 1'b0;
            core_service_reg <= 1'b0;
            rom_addr_reg <= 32'h0;
            rom_data_reg <= 16'h0;
            rom_wr_reg <= 1'b0;
            rom_rd_reg <= 1'b0;
            rom_loading_reg <= 1'b0;
            status_reg <= 8'h00;
        end else if (cmd_valid) begin
            case (cmd)
                CMD_RESET: begin
                    core_reset_reg <= cmd_data[0];
                end
                
                CMD_BUTTONS: begin
                    core_buttons_reg <= cmd_data;
                end
                
                CMD_DIPSW: begin
                    core_dipsw_reg <= cmd_data;
                end
                
                CMD_COIN: begin
                    core_coin_reg <= cmd_data[0];
                end
                
                CMD_SERVICE: begin
                    core_service_reg <= cmd_data[0];
                end
                
                CMD_ROM_ADDR: begin
                    rom_addr_reg <= {rom_addr_reg[31:8], cmd_data};
                end
                
                CMD_ROM_DATA: begin
                    rom_data_reg <= {rom_data_reg[15:8], cmd_data};
                    rom_wr_reg <= 1'b1;
                end
                
                CMD_STATUS: begin
                    status_reg <= cmd_data;
                end
            endcase
        end else begin
            rom_wr_reg <= 1'b0;
            rom_rd_reg <= 1'b0;
        end
    end
    
    // Output assignments
    assign core_reset = core_reset_reg;
    assign core_buttons = core_buttons_reg;
    assign core_dipsw = core_dipsw_reg;
    assign core_coin = core_coin_reg;
    assign core_service = core_service_reg;
    assign rom_addr = rom_addr_reg;
    assign rom_data = rom_data_reg;
    assign rom_wr = rom_wr_reg;
    assign rom_rd = rom_rd_reg;
    assign rom_loading = rom_loading_reg;
    assign status = status_reg;
    
    // UART transmitter
    reg [7:0] tx_data;
    reg       tx_valid;
    wire      tx_ready;
    
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx(uart_tx),
        .data(tx_data),
        .valid(tx_valid),
        .ready(tx_ready)
    );
    
    // Status response
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= 8'h00;
            tx_valid <= 1'b0;
        end else if (tx_ready && !tx_valid) begin
            tx_data <= core_status;
            tx_valid <= 1'b1;
        end else if (tx_valid) begin
            tx_valid <= 1'b0;
        end
    end

endmodule

// UART receiver module
module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        CLEANUP
    } state_t;
    
    state_t state;
    
    // Counter
    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    reg [2:0] bit_index;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            data <= 8'h00;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (rx == 1'b0)  // Start bit detected
                        state <= START_BIT;
                end
                
                START_BIT: begin
                    if (clk_count < (CLKS_PER_BIT-1)/2) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        data[bit_index] <= rx;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        valid <= 1'b1;
                        clk_count <= 0;
                        state <= CLEANUP;
                    end
                end
                
                CLEANUP: begin
                    state <= IDLE;
                    valid <= 1'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// UART transmitter module
module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    output reg        tx,
    input  wire [7:0] data,
    input  wire       valid,
    output reg        ready
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;
    
    state_t state;
    
    // Counter
    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            tx <= 1'b1;
            ready <= 1'b1;
            data_reg <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    ready <= 1'b1;
                    
                    if (valid) begin
                        data_reg <= data;
                        ready <= 1'b0;
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    tx <= 1'b0;
                    ready <= 1'b0;
                    
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    tx <= data_reg[bit_index];
                    ready <= 1'b0;
                    
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    tx <= 1'b1;
                    ready <= 1'b0;
                    
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule 