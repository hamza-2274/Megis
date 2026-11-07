`timescale 1ns / 1ps

module tb_megis;

    parameter WIDTH = 10;
    logic clk, rst_n, start;
    logic [4:0] match_count_out; // To capture the count

    megis_top #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .match_count(match_count_out) // Connect Port
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; start = 0;
        #20; rst_n = 1;
        $display("TB: Reset released.");
        #10; start = 1;
        $display("TB: Start signal asserted.");
        #10; start = 0;

        #2500; // Wait for logic

        $display("\n--- Final Results ---");
        $display("Total Matches Found: %d", match_count_out); // Show the Count
        
        // Verify Specific DRAM Matches
        if (dut.dram.mem[10] == 10'b0000001100) $display("SUCCESS: Found Match 12");
        else $display("FAIL: Match 12 missing");

        if (dut.dram.mem[11] == 10'b0000001101) $display("SUCCESS: Found Match 13");
        else $display("FAIL: Match 13 missing");

        // Check if Query Locations were FLUSHED (Zeroed out)
        if (dut.dram.mem[0] == 0) $display("SUCCESS: Query 0 (12) was flushed to 0.");
        else $display("FAIL: Query 0 was NOT flushed. Value: %b", dut.dram.mem[0]);

        if (dut.dram.mem[1] == 0) $display("SUCCESS: Query 1 (13) was flushed to 0.");
        else $display("FAIL: Query 1 was NOT flushed. Value: %b", dut.dram.mem[1]);
        
        $finish;
    end
    
    // Optional: Monitor writes for debugging
    always @(posedge clk) begin
        if (dut.dram_we && dut.dram_w_data == 0) begin
             $display("Time %0t: FLUSHING Query at Address %d", $time, dut.dram_wr_addr);
        end
    end

endmodule