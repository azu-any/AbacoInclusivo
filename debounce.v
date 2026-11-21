module debounce #(
    parameter DEBOUNCE_LIMIT = 20'd500000 // 10 ms at 50 MHz
)(
    input wire clk,              
    input wire rst_n,            
    input wire button_in,        // Raw noisy signal from the physical button
    output reg button_out        // Clean, stabilized signal
);

    // Synchronization registers to prevent metastability
    reg reg_sync_0, reg_sync_1;
    
    // Counter and internal state
    reg [19:0] counter;
    reg state;

    // Two-stage synchronizer into the 50 MHz clock domain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_sync_0 <= 1'b1; // Idle state is '1' (pull-up resistor)
            reg_sync_1 <= 1'b1;
        end else begin
            reg_sync_0 <= button_in;
            reg_sync_1 <= reg_sync_0;
        end
    end

    // Mechanical debounce state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter    <= 20'd0;
            state      <= 1'b1;
            button_out <= 1'b1;
        end else begin
            if (reg_sync_1 != state) begin
                // The state changed; increment the counter to measure stability
                counter <= counter + 1'b1;
                if (counter >= DEBOUNCE_LIMIT) begin
                    state      <= reg_sync_1;
                    button_out <= reg_sync_1;
                    counter    <= 20'd0;
                end
            end else begin
                // The signal is stable; reset the filtering counter
                counter <= 20'd0;
            end
        end
    end

endmodule