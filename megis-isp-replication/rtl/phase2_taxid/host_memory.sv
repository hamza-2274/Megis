module host_memory #(
    parameter DATA_WIDTH = 64, // 32-bit 5-mer TaxID + 32-bit 4-mer TaxID
    parameter ADDR_WIDTH = 5   // Depth of 32, same as DRAM
) (
    input  logic clk,
    input  logic rst_n,
    
    // Write Port (Used by FSM during TaxID Retrieval)
    input  logic write_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] data_in,
    
    // Read Port (Optional, for verifying data at the end of simulation)
    input  logic read_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] data_out
);

    // Memory Array
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
            // Clear memory on reset
            for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
                mem[i] <= 0;
            end
        end else begin
            // Synchronous Read
            if (read_en) begin
                data_out <= mem[rd_addr];
            end

            // Synchronous Write
            if (write_en) begin
                mem[wr_addr] <= data_in;
                // Debug print matching your cycle breakdown format!
                $display("Time %0t: HOST_MEM: Stored {TaxID_5mer: %0d, TaxID_4mer: %0d} at addr %0d", 
                         $time, data_in[63:32], data_in[31:0], wr_addr);
            end
        end
    end

endmodule