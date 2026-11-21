module column_decoder (
    input wire [1:0] upper_bead,      // 2-bit state from the Heaven bead
    input wire [7:0] lower_beads,     // 8-bit bus (4 Earth beads x 2 bits each)
    output reg [3:0] column_value     // Calculated decimal value (0 to 9)
);

    reg [2:0] lower_count;
    integer i;

    always @(*) begin
        lower_count = 3'd0;
        
        // Loop through the 4 lower beads and count how many are in State 1 (Positive)
        for (i = 0; i < 4; i = i + 1) begin
            if (lower_beads[(i*2) +: 2] == 2'd1) begin
                lower_count = lower_count + 1'b1;
            end
        end

        // Check if the upper bead is in State 1 (Positive)
        if (upper_bead == 2'd1) begin
            column_value = 4'd5 + lower_count;
        end else begin
            column_value = lower_count;
        end
    end

endmodule