module megis_top #(
    parameter KMER_WIDTH = 10,
    parameter MAX_WIDTH = 42
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic [4:0] match_count
);

    logic dram_re, dram_we;
    logic [4:0] dram_rd_addr, dram_wr_addr;
    logic [KMER_WIDTH-1:0] dram_q_data, dram_w_data;
    logic dram_valid;
    
    logic host_we;
    logic [4:0] host_wr_addr;
    logic [63:0] host_w_data;

    logic [3:0] flash_re; 
    logic [7:0] flash_addr [0:3];
    logic [MAX_WIDTH-1:0] flash_data_out [0:3];

    logic [MAX_WIDTH-1:0] curr_reg [0:3];
    logic [MAX_WIDTH-1:0] next_reg [0:3];

    logic [3:0] shift_enable; 
    logic [3:0] load_next;    
    logic [3:0] inc_flash;    
    logic pipeline_ready; 
    logic prefix_change;
    logic reset_p2_ptrs; 
    
    logic [3:0] res_less, res_equal, res_greater;

    typedef enum logic [4:0] {
        IDLE, 
        P1_INIT_FETCH, P1_INIT_LATCH_NEXT, P1_INIT_LATCH_CURR, 
        P1_FETCH_QUERY, P1_COMPARE, P1_WRITE_MATCH, P1_UPDATE_POINTERS,
        TRANSITION_TO_P2,
        P2_INIT_FETCH, P2_INIT_LATCH_NEXT, P2_INIT_LATCH_CURR,
        P2_FETCH_QUERY, P2_COMPARE, P2_WRITE_MATCH, P2_UPDATE_POINTERS,
        DONE
    } state_t;

    state_t state, next_state;

    dram_module #(.WIDTH(KMER_WIDTH)) dram (
        .clk(clk), .rst_n(rst_n),
        .read_en(dram_re), .rd_addr(dram_rd_addr),
        .data_out(dram_q_data), .data_valid(dram_valid),
        .write_en(dram_we), .wr_addr(dram_wr_addr),
        .data_in(dram_w_data)
    );

    host_memory #(.DATA_WIDTH(64), .ADDR_WIDTH(5)) host_mem (
        .clk(clk), .rst_n(rst_n),
        .write_en(host_we), .wr_addr(host_wr_addr), .data_in(host_w_data),
        .read_en(1'b0), .rd_addr(5'd0), .data_out() 
    );

    nand_flash_sim #(.MAX_WIDTH(MAX_WIDTH), .CHANNELS(4)) flash (
        .clk(clk), .read_en(flash_re), .addr(flash_addr),
        .data_out(flash_data_out)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : chan_gen
            intersector #(.WIDTH(KMER_WIDTH)) comp (
                .a(curr_reg[i][KMER_WIDTH-1:0]), .b(dram_q_data), 
                .less(res_less[i]), .equal(res_equal[i]), .greater(res_greater[i])
            );

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    curr_reg[i] <= 0;
                    next_reg[i] <= 0; 
                    flash_addr[i] <= 0;
                end else begin
                    if (shift_enable[i]) curr_reg[i] <= next_reg[i];
                    if (load_next[i])    next_reg[i] <= flash_data_out[i];
                    
                    if (inc_flash[i]) flash_addr[i] <= flash_addr[i] + 1;
                    
                    if (reset_p2_ptrs) begin
                        if (i == 0 || i == 1) flash_addr[i] <= 64; 
                    end
                end
            end
        end
    endgenerate

    index_generator #(.KMER_WIDTH(KMER_WIDTH), .PREFIX_WIDTH(8)) idx_gen (
        .curr_kmer(curr_reg[0][KMER_WIDTH-1:0]),
        .next_kmer(next_reg[0][KMER_WIDTH-1:0]),
        .prefix_change(prefix_change)
    );

    logic [4:0] query_ptr;      
    logic [4:0] match_ptr;      
    logic [4:0] p2_query_ptr;   
    logic [4:0] p2_match_ptr;   

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            query_ptr <= 0; match_ptr <= 10;
            p2_query_ptr <= 10; p2_match_ptr <= 0;
            pipeline_ready <= 0; match_count <= 0;
        end else begin
            state <= next_state;

            if (state == P1_INIT_LATCH_CURR || state == P2_INIT_LATCH_CURR) 
                pipeline_ready <= 1;
            if (state == TRANSITION_TO_P2) 
                pipeline_ready <= 0; 

            if (state == P1_WRITE_MATCH) begin
                match_ptr <= match_ptr + 1;
                match_count <= match_count + 1;
            end
            if (state == P1_UPDATE_POINTERS) begin
                if ( ((res_greater == 4'b1111) || (|res_equal)) && query_ptr < 10) begin
                    query_ptr <= query_ptr + 1;
                end
            end
            
            if (state == TRANSITION_TO_P2) begin
                p2_query_ptr <= 10;
                p2_match_ptr <= 0;
            end
            if (state == P2_WRITE_MATCH) begin
                p2_match_ptr <= p2_match_ptr + 1;
            end
            if (state == P2_UPDATE_POINTERS) begin
                if (res_equal[0] || res_greater[0]) begin
                    p2_query_ptr <= p2_query_ptr + 1;
                end
            end
        end
    end

    // Hardware Debugging Logs
    always_ff @(posedge clk) begin
        if (state == P2_COMPARE && pipeline_ready && dram_valid && dram_q_data != 0) begin
            $display("Time %0t: P2_COMPARE -> Ch0_Kmer: %0d | DRAM_Kmer: %0d", $time, curr_reg[0][KMER_WIDTH-1:0], dram_q_data);
        end
        if (state == P2_WRITE_MATCH) begin
            $display("Time %0t: MATCH WRITTEN! TaxID_5mer: %0d, TaxID_4mer: %0d", $time, host_w_data[63:32], host_w_data[31:0]);
        end
    end

    always_comb begin
        next_state = state;
        
        dram_re = 0; dram_we = 0;
        dram_wr_addr = match_ptr; dram_w_data = dram_q_data; 
        dram_rd_addr = query_ptr;
        
        host_we = 0; host_wr_addr = p2_match_ptr; host_w_data = 64'd0;
        flash_re = 0; shift_enable = 0; load_next = 0; inc_flash = 0;
        reset_p2_ptrs = 0;

        case (state)
            IDLE: if (start) next_state = P1_INIT_FETCH;

            // FIX: Added inc_flash to INIT_FETCH so we don't duplicate the first read!
            P1_INIT_FETCH: begin flash_re = 4'b1111; inc_flash = 4'b1111; next_state = P1_INIT_LATCH_NEXT; end
            P1_INIT_LATCH_NEXT: begin 
                flash_re = 4'b1111; load_next = 4'b1111; inc_flash = 4'b1111; next_state = P1_INIT_LATCH_CURR; 
            end
            P1_INIT_LATCH_CURR: begin 
                shift_enable = 4'b1111; load_next = 4'b1111; flash_re = 4'b1111; inc_flash = 4'b1111; next_state = P1_FETCH_QUERY;
            end

            P1_FETCH_QUERY: begin dram_re = 1; next_state = P1_COMPARE; end

            P1_COMPARE: begin
                if (pipeline_ready && dram_valid && dram_q_data != 0) begin
                    if (|res_equal) next_state = P1_WRITE_MATCH;
                    else next_state = P1_UPDATE_POINTERS;
                end else next_state = P1_FETCH_QUERY;
            end

            P1_WRITE_MATCH: begin dram_we = 1; next_state = P1_UPDATE_POINTERS; end

            P1_UPDATE_POINTERS: begin
                for (int j=0; j<4; j++) begin
                    if (res_equal[j] || res_less[j]) begin
                        shift_enable[j] = 1; load_next[j] = 1; flash_re[j] = 1; inc_flash[j] = 1;
                    end
                end
                
                if ((res_greater == 4'b1111) || (|res_equal)) begin
                    dram_we = 1; dram_wr_addr = query_ptr; dram_w_data = 10'b0; 
                    if (query_ptr == 9) next_state = TRANSITION_TO_P2;
                    else next_state = P1_FETCH_QUERY;
                end else begin
                    next_state = P1_FETCH_QUERY;
                end
            end

            TRANSITION_TO_P2: begin
                reset_p2_ptrs = 1; 
                next_state = P2_INIT_FETCH;
            end

            // FIX: Added inc_flash to INIT_FETCH for Phase 2 as well!
            P2_INIT_FETCH: begin flash_re[1:0] = 2'b11; inc_flash[1:0] = 2'b11; next_state = P2_INIT_LATCH_NEXT; end
            P2_INIT_LATCH_NEXT: begin 
                flash_re[1:0] = 2'b11; load_next[1:0] = 2'b11; inc_flash[1:0] = 2'b11; next_state = P2_INIT_LATCH_CURR; 
            end
            P2_INIT_LATCH_CURR: begin 
                shift_enable[1:0] = 2'b11; load_next[1:0] = 2'b11; flash_re[1:0] = 2'b11; inc_flash[1:0] = 2'b11; next_state = P2_FETCH_QUERY;
            end

            P2_FETCH_QUERY: begin 
                dram_rd_addr = p2_query_ptr; 
                dram_re = 1; 
                next_state = P2_COMPARE; 
            end

            P2_COMPARE: begin
                if (pipeline_ready && dram_valid && dram_q_data != 0) begin
                    if (res_equal[0]) next_state = P2_WRITE_MATCH;
                    else next_state = P2_UPDATE_POINTERS;
                end else next_state = P2_FETCH_QUERY;
            end

            P2_WRITE_MATCH: begin
                host_we = 1;
                host_w_data = {curr_reg[0][41:10], curr_reg[1][31:0]};
                next_state = P2_UPDATE_POINTERS;
            end

            P2_UPDATE_POINTERS: begin
                if (res_equal[0] || res_less[0]) begin
                    shift_enable[0] = 1; load_next[0] = 1; flash_re[0] = 1; inc_flash[0] = 1;
                    if (prefix_change) begin
                        shift_enable[1] = 1; load_next[1] = 1; flash_re[1] = 1; inc_flash[1] = 1;
                    end
                end
                
                if (res_equal[0] || res_greater[0]) begin
                    if (p2_query_ptr == match_ptr - 1) next_state = DONE;
                    else next_state = P2_FETCH_QUERY;
                end else begin
                    next_state = P2_FETCH_QUERY;
                end
            end

            DONE: begin end
        endcase
    end
endmodule