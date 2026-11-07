module channel_unit #(
    parameter DATA_WIDTH = 42 // Defaults to 42 for Ch0 (10-bit kmer + 32-bit TaxID). Ch1 will override to 32.
) (
    input  logic clk,
    input  logic rst_n,
    
    // FSM Control Signals
    input  logic shift_enable, // Moves next_reg -> curr_reg
    input  logic load_next,    // Loads flash_data -> next_reg
    
    // Data In/Out
    input  logic [DATA_WIDTH-1:0] flash_data,
    output logic [DATA_WIDTH-1:0] curr_reg,
    output logic [DATA_WIDTH-1:0] next_reg
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_reg <= 0;
            next_reg <= 0;
        end else begin
            if (shift_enable) begin
                curr_reg <= next_reg;
            end
            if (load_next) begin
                next_reg <= flash_data;
            end
        end
    end

endmodule