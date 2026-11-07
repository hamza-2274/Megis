module intersector #(parameter WIDTH = 10) (
    input  logic [WIDTH-1:0] a, // Phase 1: Flash K-mer | Phase 2: Flash K-mer slice from Ch0
    input  logic [WIDTH-1:0] b, // From DRAM (Query K-mer)
    output logic less,
    output logic equal,
    output logic greater
);

    // Comparison Logic
    assign less    = (a < b);
    assign equal   = (a == b);
    assign greater = (a > b);

endmodule