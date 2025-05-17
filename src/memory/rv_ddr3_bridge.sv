// -----------------------------------------------------------------------------
// Round–robin arbiter + data‑width shim between two 32‑bit masters
// (Wishbone + PicoRV32) and the low‑latency DDR3 "simple" port.
//
// TangConsole‑60K  : DDR_DATA_WIDTH = 16  (2 half‑words per beat)
// TangConsole‑138K : DDR_DATA_WIDTH = 32  (1:1 mapping)
// -----------------------------------------------------------------------------
module rv_ddr3_bridge #(
    parameter   ADDR_WIDTH      = 25,   // byte address into DDR
    parameter   DATA_WIDTH      = 32,   // width of each master
    parameter   DDR_DATA_WIDTH  = 16    // 16 or 32
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // ---------- Master 0 : NeoGeo Wishbone --------------------
    input  logic [ADDR_WIDTH-1:0]       wb_adr_i,
    input  logic [DATA_WIDTH-1:0]       wb_dat_i,
    output logic [DATA_WIDTH-1:0]       wb_dat_o,
    input  logic                        wb_we_i,
    input  logic [3:0]                  wb_sel_i,
    input  logic                        wb_cyc_i,
    input  logic                        wb_stb_i,
    output logic                        wb_ack_o,

    // ---------- Master 1 : PicoRV32 ---------------------------
    input  logic [ADDR_WIDTH-1:0]       rv_addr_i,
    input  logic [DATA_WIDTH-1:0]       rv_wdata_i,
    output logic [DATA_WIDTH-1:0]       rv_rdata_o,
    input  logic                        rv_we_i,
    input  logic [3:0]                  rv_be_i, // Byte enables
    input  logic                        rv_valid_i,
    output logic                        rv_ready_o,

    // ---------- DDR3 "simple" port ----------------------------
    output logic [ADDR_WIDTH-1:0]       ddr_addr_o,
    output logic [DDR_DATA_WIDTH-1:0]   ddr_wdata_o,
    input  logic [DDR_DATA_WIDTH-1:0]   ddr_rdata_i,
    output logic                        ddr_we_o,
    output logic                        ddr_req_o,
    input  logic                        ddr_ack_i
);

    // ---------------------------------------------------------
    // Simple round‑robin arbiter: 0 → 1 → 0 → 1 …
    // ---------------------------------------------------------
    typedef enum logic {M0, M1} owner_t;
    owner_t owner_q, owner_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) owner_q <= M0;
        else        owner_q <= owner_d;
    end

    // next owner when current request completes
    logic req_m0, req_m1;
    assign req_m0 = wb_cyc_i & wb_stb_i;
    assign req_m1 = rv_valid_i;

    logic grant_m0, grant_m1;
    assign grant_m0 = (owner_q == M0) && req_m0;
    assign grant_m1 = (owner_q == M1) && req_m1;

    logic ddr_done; // Signal indicating DDR transaction completion

    always_comb begin
        owner_d = owner_q;
        // Switch owner only if the other master is requesting AND the current DDR transaction is done
        if (ddr_done) begin
             if (owner_q == M0 && req_m1) owner_d = M1;
        else if (owner_q == M1 && req_m0) owner_d = M0;
        // If only one is requesting, grant it if possible
        else if (req_m0 && !req_m1) owner_d = M0;
        else if (req_m1 && !req_m0) owner_d = M1;
        end
    end

    // ---------------------------------------------------------
    // Capture current transaction fields based on grant
    // ---------------------------------------------------------
    logic [ADDR_WIDTH-1:0]    addr_mux;
    logic [DATA_WIDTH-1:0]    wdata_mux;
    logic                     we_mux;
    logic [3:0]               be_mux;     // Use byte enables for RV
    logic                     req_active; // Indicates a request is granted and active

    assign addr_mux  = grant_m0 ? wb_adr_i  : rv_addr_i;
    assign wdata_mux = grant_m0 ? wb_dat_i  : rv_wdata_i;
    assign we_mux    = grant_m0 ? wb_we_i   : rv_we_i;
    assign be_mux    = grant_m0 ? wb_sel_i  : rv_be_i; // Map WB sel to BE
    assign req_active = grant_m0 || grant_m1;

    // ---------------------------------------------------------
    // Beat‑packing logic: 32‑bit master → 16‑bit DDR (if needed)
    // ---------------------------------------------------------
    localparam USE_HALF = (DDR_DATA_WIDTH == 16);

    logic        second_half_q, second_half_d;
    logic [1:0]  byte_sel; // Based on BE/SEL
    logic [DDR_DATA_WIDTH-1:0] ddr_wdata_masked;

    // Map byte enables/selects to half-word selection
    // For writes, determine which half-word(s) are active
    logic lower_half_active, upper_half_active;
    assign lower_half_active = |be_mux[1:0];
    assign upper_half_active = |be_mux[3:2];

    // select low or high half‑word on 2nd beat
    // Address LSB determines half-word for 16-bit DDR
    assign ddr_addr_o = USE_HALF
                        ? {addr_mux[ADDR_WIDTH-1:1], second_half_q} // Use state for addr LSB
                        : addr_mux[ADDR_WIDTH-1:0];                 // Full address for 32-bit

    // Select correct half-word for writing
    assign ddr_wdata_o = USE_HALF
                         ? (second_half_q ? wdata_mux[31:16]
                                          : wdata_mux[15:0])
                         : wdata_mux[DDR_DATA_WIDTH-1:0];

    assign ddr_we_o  = we_mux & req_active; // Only assert we if write is active

    // DDR request logic: assert req if a master is granted and needs access
    // For 16-bit, handle two beats
    logic ddr_req_pending; // Internal signal to track request state
    assign ddr_req_o = ddr_req_pending;

    // Manage DDR request state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ddr_req_pending <= 1'b0;
        end else begin
            if (req_active && !ddr_req_pending && !ddr_done) begin // New request starts
                ddr_req_pending <= 1'b1;
            end else if (ddr_ack_i && ddr_req_pending) begin // DDR acknowledges
                 if (!USE_HALF || second_half_q) begin // If 32-bit or second half of 16-bit
                    ddr_req_pending <= 1'b0; // Request done
                 end
                 // else: first half of 16-bit done, keep req pending for second half
            end else if (!req_active && !ddr_ack_i) begin // If master deasserts request before ack
                 ddr_req_pending <= 1'b0;
            end
        end
    end

    // Manage second‑beat state for 16-bit DDR
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            second_half_q <= 1'b0;
        end else if (!USE_HALF) begin
            second_half_q <= 1'b0; // not used
        end else if (USE_HALF && ddr_req_pending) begin // Only change state if request is active
            if (ddr_ack_i) begin
                 if (!second_half_q && upper_half_active) begin // Move to second half if needed
                    second_half_q <= 1'b1;
                 end else begin // Done with second half or only lower half was active
                    second_half_q <= 1'b0;
                 end
            end
        end else if (!req_active) begin // Reset if no active request
             second_half_q <= 1'b0;
        end
    end

    // Determine when the full master transaction is done
    assign ddr_done = ddr_ack_i && (!USE_HALF || second_half_q);

    // ---------------------------------------------------------
    // Return path / acknowledge
    // ---------------------------------------------------------
    logic [DATA_WIDTH-1:0] rdata_tmp;

    // Assemble 32-bit data from 16-bit reads
    generate
        if (USE_HALF) begin : g_pack
            always_ff @(posedge clk) begin
                if (ddr_ack_i && !second_half_q) // First half acked
                    rdata_tmp[15:0]  <= ddr_rdata_i;
                if (ddr_ack_i &&  second_half_q) // Second half acked
                    rdata_tmp[31:16] <= ddr_rdata_i;
            end
        end else begin : g_nopack // 32-bit DDR
            always_ff @(posedge clk) begin
                if (ddr_ack_i)
                    rdata_tmp <= {{(DATA_WIDTH-DDR_DATA_WIDTH){1'b0}}, ddr_rdata_i}; // Zero extend if needed
            end
        end
    endgenerate

    // Acknowledge masters only when the full transaction is done
    // Wishbone
    assign wb_ack_o  = grant_m0 && ddr_done;
    assign wb_dat_o  = rdata_tmp;

    // PicoRV32
    assign rv_ready_o = grant_m1 && ddr_done;
    assign rv_rdata_o = rdata_tmp;

endmodule 