module bead_tracker (
    input  wire        clk,
    input  wire [11:0] voltage_in, // Raw 12-bit number from the ADC
    output reg  [1:0]  state_out   // 0=Idle, 1=Active(North), 2=Inactive(South)
);

    // Adjust these thresholds based on your 3D-printed PLA thickness
    parameter NORTH_THRESHOLD = 12'd1800; 
    parameter SOUTH_THRESHOLD = 12'd1300;

    always @(posedge clk) begin
        if (voltage_in > NORTH_THRESHOLD) begin
            state_out <= 2'd2; // -negative
        end 
        else if (voltage_in < SOUTH_THRESHOLD) begin
            state_out <= 2'd1; // positive
        end 
        else begin
            state_out <= 2'd0; // inactive
        end
    end

endmodule