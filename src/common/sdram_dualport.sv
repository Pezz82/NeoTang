module sdram_dualport (
    input  wire        clk,
    input  wire        rst_n,
    
    // Port A (P/S/M ROM)
    input  wire [24:0] addr_a,
    input  wire        we_a,
    input  wire [15:0] data_a_in,
    output wire [15:0] data_a_out,
    input  wire        req_a,
    output wire        ack_a,
    
    // Port B (C-ROM)
    input  wire [24:0] addr_b,
    input  wire        we_b,
    input  wire [15:0] data_b_in,
    output wire [15:0] data_b_out,
    input  wire        req_b,
    output wire        ack_b,
    
    // SDRAM interface
    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire        sdram_cs_n,
    output wire        sdram_ras_n,
    output wire        sdram_cas_n,
    output wire        sdram_we_n,
    output wire [1:0]  sdram_ba,
    output wire [12:0] sdram_addr,
    inout  wire [15:0] sdram_data,
    output wire [1:0]  sdram_dqm
);

    // SDRAM timing parameters
    parameter tRP  = 2;  // Precharge to active
    parameter tRCD = 2;  // Active to read/write
    parameter tCAS = 2;  // CAS latency
    parameter tWR  = 2;  // Write recovery

    // State machine states
    typedef enum logic [3:0] {
        INIT,
        IDLE,
        ACTIVE_A,
        READ_A,
        WRITE_A,
        ACTIVE_B,
        READ_B,
        WRITE_B,
        PRECHARGE
    } state_t;

    state_t state, next_state;
    
    // SDRAM control signals
    reg        sdram_cke_reg;
    reg        sdram_cs_n_reg;
    reg        sdram_ras_n_reg;
    reg        sdram_cas_n_reg;
    reg        sdram_we_n_reg;
    reg [1:0]  sdram_ba_reg;
    reg [12:0] sdram_addr_reg;
    reg [15:0] sdram_data_out;
    reg        sdram_data_oe;
    reg [1:0]  sdram_dqm_reg;

    // Output assignments
    assign sdram_clk   = clk;
    assign sdram_cke   = sdram_cke_reg;
    assign sdram_cs_n  = sdram_cs_n_reg;
    assign sdram_ras_n = sdram_ras_n_reg;
    assign sdram_cas_n = sdram_cas_n_reg;
    assign sdram_we_n  = sdram_we_n_reg;
    assign sdram_ba    = sdram_ba_reg;
    assign sdram_addr  = sdram_addr_reg;
    assign sdram_data  = sdram_data_oe ? sdram_data_out : 16'bz;
    assign sdram_dqm   = sdram_dqm_reg;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= INIT;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            INIT: next_state = IDLE;
            IDLE: begin
                if (req_a)
                    next_state = ACTIVE_A;
                else if (req_b)
                    next_state = ACTIVE_B;
            end
            ACTIVE_A: next_state = we_a ? WRITE_A : READ_A;
            READ_A: next_state = PRECHARGE;
            WRITE_A: next_state = PRECHARGE;
            ACTIVE_B: next_state = we_b ? WRITE_B : READ_B;
            READ_B: next_state = PRECHARGE;
            WRITE_B: next_state = PRECHARGE;
            PRECHARGE: next_state = IDLE;
        endcase
    end

    // Output logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdram_cke_reg   <= 1'b0;
            sdram_cs_n_reg  <= 1'b1;
            sdram_ras_n_reg <= 1'b1;
            sdram_cas_n_reg <= 1'b1;
            sdram_we_n_reg  <= 1'b1;
            sdram_ba_reg    <= 2'b00;
            sdram_addr_reg  <= 13'b0;
            sdram_data_out  <= 16'b0;
            sdram_data_oe   <= 1'b0;
            sdram_dqm_reg   <= 2'b11;
        end else begin
            case (state)
                INIT: begin
                    sdram_cke_reg   <= 1'b1;
                    sdram_cs_n_reg  <= 1'b0;
                    sdram_ras_n_reg <= 1'b1;
                    sdram_cas_n_reg <= 1'b1;
                    sdram_we_n_reg  <= 1'b1;
                end
                IDLE: begin
                    sdram_cs_n_reg  <= 1'b0;
                    sdram_ras_n_reg <= 1'b1;
                    sdram_cas_n_reg <= 1'b1;
                    sdram_we_n_reg  <= 1'b1;
                end
                ACTIVE_A: begin
                    sdram_ras_n_reg <= 1'b0;
                    sdram_cas_n_reg <= 1'b1;
                    sdram_we_n_reg  <= 1'b1;
                    sdram_ba_reg    <= addr_a[24:23];
                    sdram_addr_reg  <= addr_a[22:10];
                end
                READ_A: begin
                    sdram_ras_n_reg <= 1'b1;
                    sdram_cas_n_reg <= 1'b0;
                    sdram_we_n_reg  <= 1'b1;
                    sdram_addr_reg  <= {4'b0000, addr_a[9:0]};
                    sdram_dqm_reg   <= 2'b00;
                end
                WRITE_A: begin
                    sdram_ras_n_reg <= 1'b1;
                    sdram_cas_n_reg <= 1'b0;
                    sdram_we_n_reg  <= 1'b0;
                    sdram_addr_reg  <= {4'b0000, addr_a[9:0]};
                    sdram_data_out  <= data_a_in;
                    sdram_data_oe   <= 1'b1;
                    sdram_dqm_reg   <= 2'b00;
                end
                // Similar logic for Port B...
            endcase
        end
    end

    // Data output registers
    reg [15:0] data_a_out_reg;
    reg [15:0] data_b_out_reg;
    
    always_ff @(posedge clk) begin
        if (state == READ_A)
            data_a_out_reg <= sdram_data;
        if (state == READ_B)
            data_b_out_reg <= sdram_data;
    end

    assign data_a_out = data_a_out_reg;
    assign data_b_out = data_b_out_reg;

    // Acknowledge signals
    reg ack_a_reg, ack_b_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_a_reg <= 1'b0;
            ack_b_reg <= 1'b0;
        end else begin
            ack_a_reg <= (state == READ_A) || (state == WRITE_A);
            ack_b_reg <= (state == READ_B) || (state == WRITE_B);
        end
    end

    assign ack_a = ack_a_reg;
    assign ack_b = ack_b_reg;

endmodule 