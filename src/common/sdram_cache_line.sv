module sdram_cache_line #(
    parameter LINE_BYTES = 128
)(
    input  wire        clk,
    
    // SDRAM interface
    output wire        sdram_rd,
    output wire [24:0] sdram_addr,
    input  wire [15:0] sdram_dout,
    
    // Core interface
    input  wire        core_rd,
    input  wire [24:0] core_addr,
    output wire [15:0] core_dout
);

    // Cache parameters
    localparam LINE_WORDS = LINE_BYTES / 2;
    localparam ADDR_BITS = $clog2(LINE_WORDS);
    
    // Cache memory
    reg [15:0] cache_mem [0:LINE_WORDS-1];
    reg [24:0] cache_tag;
    reg        cache_valid;
    
    // Address decoding
    wire [24:0] line_addr = {core_addr[24:ADDR_BITS], {ADDR_BITS{1'b0}}};
    wire [ADDR_BITS-1:0] word_offset = core_addr[ADDR_BITS-1:0];
    
    // Cache hit detection
    wire cache_hit = cache_valid && (cache_tag == line_addr);
    
    // SDRAM control
    reg [ADDR_BITS-1:0] fill_count;
    reg                 filling;
    
    assign sdram_rd = !cache_hit && !filling;
    assign sdram_addr = filling ? {line_addr[24:ADDR_BITS], fill_count} : core_addr;
    
    // Cache fill
    always_ff @(posedge clk) begin
        if (sdram_rd) begin
            filling <= 1;
            fill_count <= 0;
            cache_tag <= line_addr;
            cache_valid <= 0;
        end else if (filling) begin
            cache_mem[fill_count] <= sdram_dout;
            fill_count <= fill_count + 1;
            
            if (fill_count == LINE_WORDS-1) begin
                filling <= 0;
                cache_valid <= 1;
            end
        end
    end
    
    // Core data output
    assign core_dout = cache_hit ? cache_mem[word_offset] : sdram_dout;

endmodule 