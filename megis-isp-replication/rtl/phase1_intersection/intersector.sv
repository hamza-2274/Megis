module intersector #(parameter WIDTH = 10) (
    input  logic [WIDTH-1:0] a, // From Flash (via Register)
    input  logic [WIDTH-1:0] b, // From DRAM (Query)
    output logic less,
    output logic equal,
    output logic greater
);
    // Comparison Logic
    assign less    = (a < b);
    assign equal   = (a == b);
    assign greater = (a > b);

endmodule