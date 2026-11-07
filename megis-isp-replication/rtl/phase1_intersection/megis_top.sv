module megis_top #(parameter WIDTH = 10) (
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic [4:0] match_count
);

    // --- Signals ---
    logic dram_re, dram_we;
    logic [4:0] dram_rd_addr, dram_wr_addr;
    logic [WIDTH-1:0] dram_q_data, dram_w_data;
    logic dram_valid;
    
    logic [3:0] flash_re; 
    logic [7:0] flash_addr [0:3];
    logic [WIDTH-1:0] flash_data_out [0:3];

    logic [WIDTH-1:0] curr_reg [0:3];
    logic [WIDTH-1:0] next_reg [0:3];
    
    logic [3:0] shift_enable; 
    logic [3:0] load_next;    
    logic [3:0] inc_flash;    
    logic pipeline_ready; 
    
    logic [3:0] res_less, res_equal, res_greater;

    // --- Instantiations ---
    dram_module #(.WIDTH(WIDTH)) dram (
        .clk(clk), .rst_n(rst_n),
        .read_en(dram_re), .rd_addr(dram_rd_addr),
        .data_out(dram_q_data), .data_valid(dram_valid),
        .write_en(dram_we), .wr_addr(dram_wr_addr),
        .data_in(dram_w_data)
    );

    nand_flash_sim #(.WIDTH(WIDTH), .CHANNELS(4)) flash (
        .clk(clk), .read_en(flash_re), .addr(flash_addr),
        .data_out(flash_data_out)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : chan_gen
            intersector comp (
                .a(curr_reg[i]), .b(dram_q_data), 
                .less(res_less[i]), .equal(res_equal[i]), .greater(res_greater[i])
            );
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    curr_reg[i] <= 0; next_reg[i] <= 0; flash_addr[i] <= 0;
                end else begin
                    if (shift_enable[i]) curr_reg[i] <= next_reg[i];
                    if (load_next[i])    next_reg[i] <= flash_data_out[i];
                    if (inc_flash[i])    flash_addr[i] <= flash_addr[i] + 1;
                end
            end
        end
    endgenerate

    // --- State Machine ---
    typedef enum logic [3:0] {
        IDLE, INIT_FETCH, INIT_LATCH_NEXT, INIT_LATCH_CURR, 
        FETCH_QUERY, COMPARE, WRITE_MATCH, UPDATE_POINTERS
    } state_t;

    state_t state, next_state;
    logic [4:0] query_ptr;
    logic [4:0] match_ptr;

    // --- Sequential Logic ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            query_ptr <= 0;
            match_ptr <= 10;
            pipeline_ready <= 0;
            match_count <= 0;
        end else begin
            state <= next_state;
            
            if (state == INIT_LATCH_CURR) pipeline_ready <= 1;

            if (state == WRITE_MATCH) begin
                match_ptr <= match_ptr + 1;
                match_count <= match_count + 1;
            end

            // Pointer Logic: Advance Query
            if (state == UPDATE_POINTERS) begin
                // FIX: Advance Query if All Greater OR if we just Matched (Equal)
                // This prevents processing the same query twice.
                if ( ((res_greater == 4'b1111) || (|res_equal)) && query_ptr < 9) begin
                    query_ptr <= query_ptr + 1;
                end
            end
        end
    end

    // --- Combinational Logic ---
    always_comb begin
        next_state = state;
        dram_re = 0; dram_we = 0;
        dram_wr_addr = match_ptr; dram_w_data = dram_q_data; 
        dram_rd_addr = query_ptr;
        flash_re = 0; shift_enable = 0; load_next = 0; inc_flash = 0;

        case (state)
            IDLE: if (start) next_state = INIT_FETCH;

            INIT_FETCH: begin flash_re = 4'b1111; next_state = INIT_LATCH_NEXT; end
            INIT_LATCH_NEXT: begin flash_re = 4'b1111; load_next = 4'b1111; inc_flash = 4'b1111; next_state = INIT_LATCH_CURR; end
            INIT_LATCH_CURR: begin shift_enable = 4'b1111; load_next = 4'b1111; flash_re = 4'b1111; inc_flash = 4'b1111; next_state = FETCH_QUERY; end

            FETCH_QUERY: begin dram_re = 1; next_state = COMPARE; end

            COMPARE: begin
                if (pipeline_ready && dram_valid && dram_q_data != 0) begin
                    if (|res_equal) next_state = WRITE_MATCH;
                    else if (|res_less) next_state = UPDATE_POINTERS;
                    else next_state = UPDATE_POINTERS;
                end 
                else next_state = FETCH_QUERY; 
            end

            WRITE_MATCH: begin
                dram_we = 1; 
                next_state = UPDATE_POINTERS;
            end

            UPDATE_POINTERS: begin
                // 1. Advance Flash (if Equal or Less)
                for (int j=0; j<4; j++) begin
                    if (res_equal[j] || res_less[j]) begin
                        shift_enable[j] = 1; load_next[j] = 1; flash_re[j] = 1; inc_flash[j] = 1;    
                    end
                end
                
                // 2. Advance/Flush Query (if All Greater OR Matched)
                // We assume once matched, the query is done.
                if ((res_greater == 4'b1111) || (|res_equal)) begin
                    dram_we = 1;
                    dram_wr_addr = query_ptr; // Flush Current Query
                    dram_w_data = 10'b0;      // Write Zero
                end
                
                next_state = FETCH_QUERY;
            end
        endcase
    end
endmodule