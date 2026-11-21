module hex_decoder (
    input  wire [1:0] state_in,
    output reg  [6:0] hex_out
);

    // DE10-Lite displays are ACTIVE LOW (0 = ON, 1 = OFF)
    // The 7 bits map to segments: {g, f, e, d, c, b, a}
    always @(*) begin
        case (state_in)
            2'd0: hex_out = 7'b1000000; // State 0 (Idle)     -> Shows '0'
            2'd1: hex_out = 7'b1111001; // State 1 (Positive) -> Shows '1'
            2'd2: hex_out = 7'b0111111; // State 2 (Negative) -> Shows '-' (Minus sign)
            default: hex_out = 7'b1111111; // Blank/Off
        endcase
    end

endmodule