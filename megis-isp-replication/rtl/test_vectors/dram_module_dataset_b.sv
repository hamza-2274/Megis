module dram_module #(parameter WIDTH = 10) (
    input  logic clk,
    input  logic rst_n,
    input  logic read_en,
    input  logic [4:0] rd_addr,
    output logic [WIDTH-1:0] data_out,
    output logic data_valid,
    input  logic write_en,
    input  logic [4:0] wr_addr,
    input  logic [WIDTH-1:0] data_in
);

    // FIX: Increased size to 32 to prevent boundary cutoff
    logic [WIDTH-1:0] mem [0:31]; 
    integer k; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
            data_valid <= 0;

            mem[0] <= 10'b0000010111; // 23 (Match)
            mem[1] <= 10'b0000011100; // 28 (Match)
            mem[2] <= 10'b0000100001; // 33 (Match)
            mem[3] <= 10'b0000101110; // 46 (Match)
            mem[4] <= 10'b0001000001; // 65 (Match)
            
            //  (The non-matches / "T")
            mem[5] <= 10'b1100000000; // 768 (TAAAA)
            mem[6] <= 10'b1100000010; // 770 (TAAAG)
            mem[7] <= 10'b1100000100; // 772 (TAACA)
            mem[8] <= 10'b1100000110; // 774 (TAACG)
            mem[9] <= 10'b1100001001; // 777 (TAAGC)


            for (k = 10; k < 32; k = k + 1) begin
                mem[k] <= 0;
            end

        end else begin
            // Read
            if (read_en) begin
                data_out <= mem[rd_addr];
                data_valid <= 1; 
            end else begin
                data_valid <= 0;
            end

            // Write
            if (write_en) begin
                mem[wr_addr] <= data_in;
                // Debug print to confirm write happens
                $display("DRAM: Stored Match %b at addr %d", data_in, wr_addr);
            end
        end
    end

endmodule