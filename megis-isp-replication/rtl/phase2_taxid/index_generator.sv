module index_generator #(
    parameter KMER_WIDTH = 10,
    parameter PREFIX_WIDTH = 8
) (
    input  logic [KMER_WIDTH-1:0] curr_kmer,
    input  logic [KMER_WIDTH-1:0] next_kmer,
    output logic prefix_change
);

    // Extract the prefixes (top PREFIX_WIDTH bits)
    // For a 10-bit k-mer and 8-bit prefix, this grabs bits [9:2]
    logic [PREFIX_WIDTH-1:0] curr_prefix;
    logic [PREFIX_WIDTH-1:0] next_prefix;

    assign curr_prefix = curr_kmer[KMER_WIDTH-1 : KMER_WIDTH-PREFIX_WIDTH];
    assign next_prefix = next_kmer[KMER_WIDTH-1 : KMER_WIDTH-PREFIX_WIDTH];

    // Detect if the prefix changes between the current and next 5-mer
    // This flag tells the FSM to advance Channel 1 (the 4-mer TaxID stream)
    assign prefix_change = (curr_prefix != next_prefix);

endmodule