module column_decoder (
    input wire [1:0] upper_bead,   
    input wire [7:0] lower_beads,  // {l3, l2, l1, l0} 
    output reg [3:0] column_value
);

    // Convert the 2-bit states into simple Yes/No detection booleans
    wire upper_detected = (upper_bead != 2'b00);
    wire l3_detected = (lower_beads[7:6] != 2'b00); // Top-most lower bead
    wire l2_detected = (lower_beads[5:4] != 2'b00);
    wire l1_detected = (lower_beads[3:2] != 2'b00);
    wire l0_detected = (lower_beads[1:0] != 2'b00); // Bottom-most lower bead

    reg [3:0] upper_val;
    reg [3:0] lower_val;

    always @(*) begin
        // 1. UPPER BEAD LOGIC (Heaven Bead)
        if (upper_detected == 1'b0) begin
            upper_val = 4'd5; // Missing from rest = moved to middle line
        end else begin
            upper_val = 4'd0; // Resting at top edge
        end

        // 2. LOWER BEADS LOGIC (Earth Beads)
        // We check from the absolute bottom (l0) upwards.
        if (l0_detected == 1'b0) begin
            lower_val = 4'd4; // Bottom bead missing = all 4 pushed up
        end else if (l1_detected == 1'b0) begin
            lower_val = 4'd3; // 2nd from bottom missing = 3 pushed up
        end else if (l2_detected == 1'b0) begin
            lower_val = 4'd2; // 3rd from bottom missing = 2 pushed up
        end else if (l3_detected == 1'b0) begin
            lower_val = 4'd1; // Top lower bead missing = 1 pushed up
        end else begin
            lower_val = 4'd0; // All beads resting safely at bottom edge
        end

        // Combine for the final 0-9 digit
        column_value = upper_val + lower_val;
    end
endmodule
