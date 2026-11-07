`timescale 1ns/1ps

module kmer_sram #(
    parameter int CHANNELS = 4,
    parameter int DEPTH    = 256,
    parameter int WIDTH    = 10
)(
    input  logic                     clk,
    input  logic                     en,
    input  logic [$clog2(CHANNELS)-1:0] channel,
    input  logic [$clog2(DEPTH)-1:0]    addr,
    output logic [WIDTH-1:0]          data_out
);

    // -------------------------------------------------
    // SRAM-like memory
    // -------------------------------------------------
    logic [WIDTH-1:0] nand_flash [0:CHANNELS-1][0:DEPTH-1];

    integer ch;
    integer row;

    // -------------------------------------------------
    // Memory initialization (synth-friendly pattern)
    // -------------------------------------------------
    initial begin
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            for (row = 0; row < DEPTH; row = row + 1) begin
                // upper 8 bits = prefix (AAAA..TTTT)
                // lower 2 bits = last base (channel)
                nand_flash[ch][row] = {row[7:0], ch[1:0]};
            end
        end
    end

    // -------------------------------------------------
    // Synchronous read (SRAM style)
    // -------------------------------------------------
    always_ff @(posedge clk) begin
        if (en) begin
            data_out <= nand_flash[channel][addr];
        end
    end

endmodule
