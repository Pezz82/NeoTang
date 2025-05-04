module video_scaler_3x #(
    parameter NATIVE_WIDTH  = 320,
    parameter NATIVE_HEIGHT = 224
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Native resolution input
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    
    // Scaled output (3x)
    output wire [7:0]  r_out,
    output wire [7:0]  g_out,
    output wire [7:0]  b_out,
    output wire        hs_out,
    output wire        vs_out,
    output wire        de_out
);

    // Line buffers for scaling
    reg [23:0] line_buffer_0 [0:NATIVE_WIDTH-1];
    reg [23:0] line_buffer_1 [0:NATIVE_WIDTH-1];
    reg [23:0] line_buffer_2 [0:NATIVE_WIDTH-1];
    
    // Write pointer
    reg [$clog2(NATIVE_WIDTH)-1:0] write_ptr;
    
    // Read pointers for 3x scaling
    reg [$clog2(NATIVE_WIDTH)-1:0] read_ptr_0;
    reg [$clog2(NATIVE_WIDTH)-1:0] read_ptr_1;
    reg [$clog2(NATIVE_WIDTH)-1:0] read_ptr_2;
    
    // Line counter
    reg [$clog2(NATIVE_HEIGHT)-1:0] line_count;
    
    // State machine
    typedef enum logic [1:0] {
        IDLE,
        WRITE_LINE,
        READ_LINE
    } state_t;
    
    state_t state, next_state;
    
    // Input pixel register
    reg [23:0] pixel_in;
    assign pixel_in = {r_in, g_in, b_in};
    
    // Output pixel register
    reg [23:0] pixel_out;
    assign {r_out, g_out, b_out} = pixel_out;
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (de_in) next_state = WRITE_LINE;
            WRITE_LINE: if (!de_in) next_state = READ_LINE;
            READ_LINE: if (line_count == NATIVE_HEIGHT-1) next_state = IDLE;
        endcase
    end
    
    // Write pointer logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            write_ptr <= 0;
        else if (state == WRITE_LINE && de_in)
            write_ptr <= write_ptr + 1;
    end
    
    // Line buffer write
    always_ff @(posedge clk) begin
        if (state == WRITE_LINE && de_in) begin
            case (line_count[1:0])
                2'b00: line_buffer_0[write_ptr] <= pixel_in;
                2'b01: line_buffer_1[write_ptr] <= pixel_in;
                2'b10: line_buffer_2[write_ptr] <= pixel_in;
            endcase
        end
    end
    
    // Read pointer logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr_0 <= 0;
            read_ptr_1 <= 0;
            read_ptr_2 <= 0;
        end else if (state == READ_LINE) begin
            read_ptr_0 <= read_ptr_0 + 1;
            if (read_ptr_0 == NATIVE_WIDTH-1) begin
                read_ptr_1 <= read_ptr_1 + 1;
                if (read_ptr_1 == NATIVE_WIDTH-1)
                    read_ptr_2 <= read_ptr_2 + 1;
            end
        end
    end
    
    // Line counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            line_count <= 0;
        else if (state == READ_LINE && read_ptr_2 == NATIVE_WIDTH-1)
            line_count <= line_count + 1;
    end
    
    // Output pixel selection
    always_comb begin
        case (line_count[1:0])
            2'b00: pixel_out = line_buffer_0[read_ptr_0];
            2'b01: pixel_out = line_buffer_1[read_ptr_1];
            2'b10: pixel_out = line_buffer_2[read_ptr_2];
            default: pixel_out = 24'h000000;
        endcase
    end
    
    // Output control signals
    reg hs_out_reg, vs_out_reg, de_out_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hs_out_reg <= 0;
            vs_out_reg <= 0;
            de_out_reg <= 0;
        end else begin
            hs_out_reg <= hs_in;
            vs_out_reg <= vs_in;
            de_out_reg <= (state == READ_LINE);
        end
    end
    
    assign hs_out = hs_out_reg;
    assign vs_out = vs_out_reg;
    assign de_out = de_out_reg;

endmodule 