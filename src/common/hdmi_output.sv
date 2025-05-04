module hdmi_output (
    input  wire        clk_pixel,
    input  wire        clk_5x,
    input  wire        rst_n,
    
    // Video input
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    
    // HDMI output
    output wire        hdmi_clk_p,
    output wire        hdmi_clk_n,
    output wire [2:0]  hdmi_data_p,
    output wire [2:0]  hdmi_data_n
);

    // TMDS encoding
    wire [9:0] tmds_r, tmds_g, tmds_b;
    wire [9:0] tmds_c;
    
    // TMDS encoder instances
    tmds_encoder encoder_r (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(r_in),
        .c(2'b00),
        .de(de_in),
        .q_out(tmds_r)
    );
    
    tmds_encoder encoder_g (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(g_in),
        .c(2'b00),
        .de(de_in),
        .q_out(tmds_g)
    );
    
    tmds_encoder encoder_b (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(b_in),
        .c({vs_in, hs_in}),
        .de(de_in),
        .q_out(tmds_b)
    );
    
    // Control period encoding
    assign tmds_c = {8'b00000000, hs_in, vs_in};
    
    // Serializer instances
    serializer ser_clk (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_n(rst_n),
        .data_in(10'b0000011111),
        .data_out_p(hdmi_clk_p),
        .data_out_n(hdmi_clk_n)
    );
    
    serializer ser_r (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_n(rst_n),
        .data_in(tmds_r),
        .data_out_p(hdmi_data_p[2]),
        .data_out_n(hdmi_data_n[2])
    );
    
    serializer ser_g (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_n(rst_n),
        .data_in(tmds_g),
        .data_out_p(hdmi_data_p[1]),
        .data_out_n(hdmi_data_n[1])
    );
    
    serializer ser_b (
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst_n(rst_n),
        .data_in(tmds_b),
        .data_out_p(hdmi_data_p[0]),
        .data_out_n(hdmi_data_n[0])
    );

endmodule

// TMDS encoder module
module tmds_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire [1:0] c,
    input  wire       de,
    output reg  [9:0] q_out
);

    // TMDS encoding parameters
    parameter CTRL_0 = 10'b1101010100;
    parameter CTRL_1 = 10'b0010101011;
    parameter CTRL_2 = 10'b0101010100;
    parameter CTRL_3 = 10'b1010101011;
    
    // Internal signals
    reg [8:0] q_m;
    reg [3:0] cnt;
    
    // XOR/XNOR encoding
    wire [8:0] q_m_xor;
    wire [8:0] q_m_xnor;
    
    assign q_m_xor[0] = data[0];
    assign q_m_xor[1] = q_m_xor[0] ^ data[1];
    assign q_m_xor[2] = q_m_xor[1] ^ data[2];
    assign q_m_xor[3] = q_m_xor[2] ^ data[3];
    assign q_m_xor[4] = q_m_xor[3] ^ data[4];
    assign q_m_xor[5] = q_m_xor[4] ^ data[5];
    assign q_m_xor[6] = q_m_xor[5] ^ data[6];
    assign q_m_xor[7] = q_m_xor[6] ^ data[7];
    assign q_m_xor[8] = 1'b1;
    
    assign q_m_xnor[0] = data[0];
    assign q_m_xnor[1] = q_m_xnor[0] ~^ data[1];
    assign q_m_xnor[2] = q_m_xnor[1] ~^ data[2];
    assign q_m_xnor[3] = q_m_xnor[2] ~^ data[3];
    assign q_m_xnor[4] = q_m_xnor[3] ~^ data[4];
    assign q_m_xnor[5] = q_m_xnor[4] ~^ data[5];
    assign q_m_xnor[6] = q_m_xnor[5] ~^ data[6];
    assign q_m_xnor[7] = q_m_xnor[6] ~^ data[7];
    assign q_m_xnor[8] = 1'b0;
    
    // Choose between XOR and XNOR based on bit count
    wire [3:0] n1d = data[0] + data[1] + data[2] + data[3] + data[4] + data[5] + data[6] + data[7];
    wire use_xnor = (n1d > 4'd4) || (n1d == 4'd4 && data[0] == 1'b0);
    
    // Final encoding
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_m <= 9'b0;
            cnt <= 4'b0;
            q_out <= 10'b0;
        end else begin
            if (de) begin
                q_m <= use_xnor ? q_m_xnor : q_m_xor;
                
                // Count ones in q_m[7:0]
                cnt <= cnt + (q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]) - 4'd4;
                
                // Final encoding
                if (cnt == 4'b0 || q_m[8] == 1'b1) begin
                    q_out <= {~q_m[8], q_m[7:0]};
                    cnt <= cnt + (q_m[8] ? 4'd0 : 4'd2) - 4'd4;
                end else begin
                    q_out <= {q_m[8], ~q_m[7:0]};
                    cnt <= cnt + (q_m[8] ? 4'd2 : 4'd0) - 4'd4;
                end
            end else begin
                case (c)
                    2'b00: q_out <= CTRL_0;
                    2'b01: q_out <= CTRL_1;
                    2'b10: q_out <= CTRL_2;
                    2'b11: q_out <= CTRL_3;
                endcase
                cnt <= 4'b0;
            end
        end
    end

endmodule

// Serializer module
module serializer (
    input  wire       clk_pixel,
    input  wire       clk_5x,
    input  wire       rst_n,
    input  wire [9:0] data_in,
    output wire       data_out_p,
    output wire       data_out_n
);

    // Shift register
    reg [9:0] shift_reg;
    
    // Output registers
    reg data_out_p_reg;
    reg data_out_n_reg;
    
    // Counter for 5:1 serialization
    reg [2:0] count;
    
    always_ff @(posedge clk_5x or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 10'b0;
            count <= 3'b0;
            data_out_p_reg <= 1'b0;
            data_out_n_reg <= 1'b1;
        end else begin
            if (count == 3'b0)
                shift_reg <= data_in;
            else
                shift_reg <= {1'b0, shift_reg[9:1]};
                
            data_out_p_reg <= shift_reg[0];
            data_out_n_reg <= ~shift_reg[0];
            
            count <= count + 1'b1;
        end
    end
    
    assign data_out_p = data_out_p_reg;
    assign data_out_n = data_out_n_reg;

endmodule 