module nand_flash_sim #(parameter WIDTH = 10, CHANNELS = 4) (
    input  logic clk,
    input  logic [CHANNELS-1:0] read_en, 
    // Ascending ranges to match megis_top.sv (unpacked arrays connect by position)
    input  logic [7:0] addr [0:CHANNELS-1],
    output logic [WIDTH-1:0] data_out [0:CHANNELS-1]
);

    // Memory Array: 4 Channels, 256 Rows depth
    logic [WIDTH-1:0] flash_mem [0:CHANNELS-1][0:255];
    
    // Loop variables
    integer c, r;

    // Phase 1 reference database: 48 rows x 4 channels, sorted k-mers (2 bits per base).
    // Each channel holds every 4th k-mer, so all four can be streamed in parallel.
    logic [WIDTH-1:0] preload_data [0:47][0:3];
    initial begin
        preload_data[0][0] = 10'b0000000011; preload_data[0][1] = 10'b0000000100; preload_data[0][2] = 10'b0000000101; preload_data[0][3] = 10'b0000000110;  // Row 0
        preload_data[1][0] = 10'b0000000111; preload_data[1][1] = 10'b0000001000; preload_data[1][2] = 10'b0000001001; preload_data[1][3] = 10'b0000001010;  // Row 1
        preload_data[2][0] = 10'b0000001011; preload_data[2][1] = 10'b0000001100; preload_data[2][2] = 10'b0000001101; preload_data[2][3] = 10'b0000001110;  // Row 2 (Matches 12, 13, 14)
        preload_data[3][0] = 10'b0000001111; preload_data[3][1] = 10'b0000010000; preload_data[3][2] = 10'b0000010001; preload_data[3][3] = 10'b0000010010;  // Row 3 (Matches 15)
        preload_data[4][0] = 10'b0000010011; preload_data[4][1] = 10'b0000010100; preload_data[4][2] = 10'b0000010101; preload_data[4][3] = 10'b0000010110;
        preload_data[5][0] = 10'b0000010111; preload_data[5][1] = 10'b0000011000; preload_data[5][2] = 10'b0000011001; preload_data[5][3] = 10'b0000011010;
        preload_data[6][0] = 10'b0000011011; preload_data[6][1] = 10'b0000011100; preload_data[6][2] = 10'b0000011101; preload_data[6][3] = 10'b0000011110;
        preload_data[7][0] = 10'b0000011111; preload_data[7][1] = 10'b0000100000; preload_data[7][2] = 10'b0000100001; preload_data[7][3] = 10'b0000100010;
        preload_data[8][0] = 10'b0000100011; preload_data[8][1] = 10'b0000100100; preload_data[8][2] = 10'b0000100101; preload_data[8][3] = 10'b0000100110;
        preload_data[9][0] = 10'b0000100111; preload_data[9][1] = 10'b0000101000; preload_data[9][2] = 10'b0000101001; preload_data[9][3] = 10'b0000101010;
        preload_data[10][0] = 10'b0000101011; preload_data[10][1] = 10'b0000101100; preload_data[10][2] = 10'b0000101101; preload_data[10][3] = 10'b0000101110;
        preload_data[11][0] = 10'b0000101111; preload_data[11][1] = 10'b0000110000; preload_data[11][2] = 10'b0000110001; preload_data[11][3] = 10'b0000110010;
        preload_data[12][0] = 10'b0000110011; preload_data[12][1] = 10'b0000110100; preload_data[12][2] = 10'b0000110101; preload_data[12][3] = 10'b0000110110;
        preload_data[13][0] = 10'b0000110111; preload_data[13][1] = 10'b0000111000; preload_data[13][2] = 10'b0000111001; preload_data[13][3] = 10'b0000111010;
        preload_data[14][0] = 10'b0000111011; preload_data[14][1] = 10'b0000111100; preload_data[14][2] = 10'b0000111101; preload_data[14][3] = 10'b0000111110;
        preload_data[15][0] = 10'b0000111111; preload_data[15][1] = 10'b0001000000; preload_data[15][2] = 10'b0001000001; preload_data[15][3] = 10'b0001000010;
        preload_data[16][0] = 10'b0001000011; preload_data[16][1] = 10'b0001000100; preload_data[16][2] = 10'b0001000101; preload_data[16][3] = 10'b0001000110;
        preload_data[17][0] = 10'b0001000111; preload_data[17][1] = 10'b0001001000; preload_data[17][2] = 10'b0001001001; preload_data[17][3] = 10'b0001001010;
        preload_data[18][0] = 10'b0001001011; preload_data[18][1] = 10'b0001001100; preload_data[18][2] = 10'b0001001101; preload_data[18][3] = 10'b0001001110;
        preload_data[19][0] = 10'b0001001111; preload_data[19][1] = 10'b0001010000; preload_data[19][2] = 10'b0001010001; preload_data[19][3] = 10'b0001010010;
        preload_data[20][0] = 10'b0001010011; preload_data[20][1] = 10'b0001010100; preload_data[20][2] = 10'b0001010101; preload_data[20][3] = 10'b0001010110;
        preload_data[21][0] = 10'b0001010111; preload_data[21][1] = 10'b0001011000; preload_data[21][2] = 10'b0001011001; preload_data[21][3] = 10'b0001011010;
        preload_data[22][0] = 10'b0001011011; preload_data[22][1] = 10'b0001011100; preload_data[22][2] = 10'b0001011101; preload_data[22][3] = 10'b0001011110;
        preload_data[23][0] = 10'b0001011111; preload_data[23][1] = 10'b0001100000; preload_data[23][2] = 10'b0001100001; preload_data[23][3] = 10'b0001100010;
        preload_data[24][0] = 10'b0001100011; preload_data[24][1] = 10'b0001100100; preload_data[24][2] = 10'b0001100101; preload_data[24][3] = 10'b0001100110;
        preload_data[25][0] = 10'b0001100111; preload_data[25][1] = 10'b0001101000; preload_data[25][2] = 10'b0001101001; preload_data[25][3] = 10'b0001101010;
        preload_data[26][0] = 10'b0001101011; preload_data[26][1] = 10'b0001101100; preload_data[26][2] = 10'b0001101101; preload_data[26][3] = 10'b0001101110;
        preload_data[27][0] = 10'b0001101111; preload_data[27][1] = 10'b0001110000; preload_data[27][2] = 10'b0001110001; preload_data[27][3] = 10'b0001110010;
        preload_data[28][0] = 10'b0001110011; preload_data[28][1] = 10'b0001110100; preload_data[28][2] = 10'b0001110101; preload_data[28][3] = 10'b0001110110;
        preload_data[29][0] = 10'b0001110111; preload_data[29][1] = 10'b0001111000; preload_data[29][2] = 10'b0001111001; preload_data[29][3] = 10'b0001111010;
        preload_data[30][0] = 10'b0001111011; preload_data[30][1] = 10'b0001111100; preload_data[30][2] = 10'b0001111101; preload_data[30][3] = 10'b0001111110;
        preload_data[31][0] = 10'b0001111111; preload_data[31][1] = 10'b0010000000; preload_data[31][2] = 10'b0010000001; preload_data[31][3] = 10'b0010000010;
        preload_data[32][0] = 10'b0010000011; preload_data[32][1] = 10'b0010000100; preload_data[32][2] = 10'b0010000101; preload_data[32][3] = 10'b0010000110;
        preload_data[33][0] = 10'b0010000111; preload_data[33][1] = 10'b0010001000; preload_data[33][2] = 10'b0010001001; preload_data[33][3] = 10'b0010001010;
        preload_data[34][0] = 10'b0010001011; preload_data[34][1] = 10'b0010001100; preload_data[34][2] = 10'b0010001101; preload_data[34][3] = 10'b0010001110;
        preload_data[35][0] = 10'b0010001111; preload_data[35][1] = 10'b0010010000; preload_data[35][2] = 10'b0010010001; preload_data[35][3] = 10'b0010010010;
        preload_data[36][0] = 10'b0010010011; preload_data[36][1] = 10'b0010010100; preload_data[36][2] = 10'b0010010101; preload_data[36][3] = 10'b0010010110;
        preload_data[37][0] = 10'b0010010111; preload_data[37][1] = 10'b0010011000; preload_data[37][2] = 10'b0010011001; preload_data[37][3] = 10'b0010011010;
        preload_data[38][0] = 10'b0010011011; preload_data[38][1] = 10'b0010011100; preload_data[38][2] = 10'b0010011101; preload_data[38][3] = 10'b0010011110;
        preload_data[39][0] = 10'b0010011111; preload_data[39][1] = 10'b0010100000; preload_data[39][2] = 10'b0010100001; preload_data[39][3] = 10'b0010100010;
        preload_data[40][0] = 10'b0010100011; preload_data[40][1] = 10'b0010100100; preload_data[40][2] = 10'b0010100101; preload_data[40][3] = 10'b0010100110;
        preload_data[41][0] = 10'b0010100111; preload_data[41][1] = 10'b0010101000; preload_data[41][2] = 10'b0010101001; preload_data[41][3] = 10'b0010101010;
        preload_data[42][0] = 10'b0010101011; preload_data[42][1] = 10'b0010101100; preload_data[42][2] = 10'b0010101101; preload_data[42][3] = 10'b0010101110;
        preload_data[43][0] = 10'b0010101111; preload_data[43][1] = 10'b0010110000; preload_data[43][2] = 10'b0010110001; preload_data[43][3] = 10'b0010110010;
        preload_data[44][0] = 10'b0010110011; preload_data[44][1] = 10'b0010110100; preload_data[44][2] = 10'b0010110101; preload_data[44][3] = 10'b0010110110;
        preload_data[45][0] = 10'b0010110111; preload_data[45][1] = 10'b0010111000; preload_data[45][2] = 10'b0010111001; preload_data[45][3] = 10'b0010111010;
        preload_data[46][0] = 10'b0010111011; preload_data[46][1] = 10'b0010111100; preload_data[46][2] = 10'b0010111101; preload_data[46][3] = 10'b0010111110;
        preload_data[47][0] = 10'b0010111111; preload_data[47][1] = 10'b0011000000; preload_data[47][2] = 10'b0011000001; preload_data[47][3] = 10'b0011000010;

        //  Fill EVERYTHING with 1s first (so we don't get 'x' in unused upper mem)
        for (c = 0; c < CHANNELS; c = c + 1) begin
            for (r = 0; r < 256; r = r + 1) begin
                flash_mem[c][r] = {WIDTH{1'b1}}; 
            end
        end

        // LOAD  DATA
        for (r = 0; r < 48; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                flash_mem[c][r] = preload_data[r][c];
            end
        end

        $display("NAND_SIM: Custom Data Loaded Successfully.");
    end

    // --- READ LOGIC ---
    always_ff @(posedge clk) begin
        for (int i = 0; i < CHANNELS; i++) begin
            if (read_en[i]) begin
                data_out[i] <= flash_mem[i][addr[i]];
            end
        end
    end

endmodule