`timescale 1ns / 1ps

module tb_megis;

    parameter KMER_WIDTH = 10;
    parameter MAX_WIDTH = 42;
    
    logic clk, rst_n, start;
    logic [4:0] match_count_out;

    // Instantiate the Top Module
    megis_top #(
        .KMER_WIDTH(KMER_WIDTH), 
        .MAX_WIDTH(MAX_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .match_count(match_count_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0; 
        rst_n = 0; 
        start = 0;
        
        // Reset sequence
        #20; 
        rst_n = 1;
        $display("TB: Reset released.");
        
        // Pulse Start
        #10; 
        start = 1;
        $display("TB: Start signal asserted. Phase 1 Commencing...");
        #10; 
        start = 0;

        // Wait enough time for Phase 1 AND Phase 2 to complete
        #3000; 

        $display("\n========================================");
        $display("--- FINAL PIPELINE RESULTS ---");
        $display("========================================");
        
        $display("\n--- PHASE 1: DRAM MATCHES ---");
        $display("Total Matches Found in P1: %d", match_count_out); 
        
        // Verify Specific DRAM Matches from Phase 1
        if (dut.dram.mem[10] == 10'd23) $display("SUCCESS: DRAM[10] = 23");
        else $display("FAIL: DRAM[10] missing");

        if (dut.dram.mem[11] == 10'd28) $display("SUCCESS: DRAM[11] = 28");
        else $display("FAIL: DRAM[11] missing");
        
        if (dut.dram.mem[12] == 10'd33) $display("SUCCESS: DRAM[12] = 33");
        else $display("FAIL: DRAM[12] missing");

        if (dut.dram.mem[13] == 10'd46) $display("SUCCESS: DRAM[13] = 46");
        else $display("FAIL: DRAM[13] missing");
        
        if (dut.dram.mem[14] == 10'd65) $display("SUCCESS: DRAM[14] = 65");
        else $display("FAIL: DRAM[14] missing");

        $display("\n--- PHASE 2: HOST MEMORY TAXIDs ---");
        // Verify Specific Host Memory Writes from Phase 2
        // We check against the {5-mer TaxID, 4-mer TaxID} combinations
        
        if (dut.host_mem.mem[0] == {32'd101, 32'd4005}) 
            $display("SUCCESS: HOST[0] = {TaxID: 101, 4-mer: 4005}");
        else 
            $display("FAIL: HOST[0] incorrect. Got %0d, %0d", dut.host_mem.mem[0][63:32], dut.host_mem.mem[0][31:0]);

        if (dut.host_mem.mem[1] == {32'd103, 32'd4007}) 
            $display("SUCCESS: HOST[1] = {TaxID: 103, 4-mer: 4007}");
        else 
            $display("FAIL: HOST[1] incorrect.");

        if (dut.host_mem.mem[2] == {32'd105, 32'd4008}) 
            $display("SUCCESS: HOST[2] = {TaxID: 105, 4-mer: 4008}");
        else 
            $display("FAIL: HOST[2] incorrect.");

        if (dut.host_mem.mem[3] == {32'd107, 32'd4011}) 
            $display("SUCCESS: HOST[3] = {TaxID: 107, 4-mer: 4011}");
        else 
            $display("FAIL: HOST[3] incorrect.");

        if (dut.host_mem.mem[4] == {32'd109, 32'd4016}) 
            $display("SUCCESS: HOST[4] = {TaxID: 109, 4-mer: 4016}");
        else 
            $display("FAIL: HOST[4] incorrect.");

        $display("\nSimulation Complete.");
        $finish;
    end

endmodule