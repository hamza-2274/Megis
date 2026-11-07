`timescale 1ns/1ps

module kmer_sram_tb;

    // -----------------------------
    // Clock & control
    // -----------------------------
    logic clk;
    logic en;

    logic [1:0] channel;
    logic [7:0] addr;
    logic [9:0] data_out;

    // Temp storage for 4 channels
    logic [9:0] a, c, g, t;

    // -----------------------------
    // DUT
    // -----------------------------
    kmer_sram dut (
        .clk(clk),
        .en(en),
        .channel(channel),
        .addr(addr),
        .data_out(data_out)
    );

    // -----------------------------
    // Clock generation (100 MHz)
    // -----------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------
    // Main stimulus
    // -----------------------------
    integer row;

    initial begin
        en = 1'b1;

        // Dummy clock to let SRAM initialize and first data be valid
        @(posedge clk);

        // Header
        $display("-------------------------------------------------------------");
        $display(" Row |   Channel A     Channel C     Channel G     Channel T ");
        $display("-------------------------------------------------------------");

        // Loop through all 256 rows
        for (row = 0; row < 256; row = row + 1) begin
            addr = row;

            // Synchronous read per channel
            channel = 2'd0; @(posedge clk); a = data_out;
            channel = 2'd1; @(posedge clk); c = data_out;
            channel = 2'd2; @(posedge clk); g = data_out;
            channel = 2'd3; @(posedge clk); t = data_out;

            // Print the row
            $display("%3d | %010b   %010b   %010b   %010b", row, a, c, g, t);
        end

        $display("-------------------------------------------------------------");
        $finish;
    end

endmodule
