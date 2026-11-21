module uart_tx #(
    parameter CLOCKS_PER_BIT = 434 // 50 MHz / 115200 baud rate = 434
)(
    input wire clk,
    input wire rst_n,
    input wire tx_start,           // Connects to speak_trigger
    input wire [31:0] data_in,     // Connects to number_to_speak
    output reg tx_pin,             // Physical wire to ESP32 RX
    output reg busy
);

    reg [11:0] clk_count;
    reg [2:0]  bit_index;
    reg [2:0]  byte_index;
    reg [7:0]  current_byte;
    reg [31:0] data_buffer;
    
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam NEXT  = 3'd4;
    
    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_pin <= 1'b1;
            busy <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    if (tx_start) begin
                        data_buffer <= data_in; // Snapshot the 32-bit number
                        byte_index <= 3'd0;
                        busy <= 1'b1;
                        state <= NEXT;
                    end else begin
                        busy <= 1'b0;
                    end
                end
                
                NEXT: begin
                    if (byte_index == 3'd4) begin
                        state <= IDLE; // All 4 bytes successfully sent
                    end else begin
                        // Extract one byte at a time (Big Endian: MSB first)
                        if (byte_index == 3'd0) current_byte <= data_buffer[31:24];
                        if (byte_index == 3'd1) current_byte <= data_buffer[23:16];
                        if (byte_index == 3'd2) current_byte <= data_buffer[15:8];
                        if (byte_index == 3'd3) current_byte <= data_buffer[7:0];
                        
                        clk_count <= 12'd0;
                        state <= START;
                    end
                end

                START: begin
                    tx_pin <= 1'b0; // Pull line low to signal Start Bit
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 12'd0;
                        bit_index <= 3'd0;
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx_pin <= current_byte[bit_index]; // Send bits LSB first
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 12'd0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_pin <= 1'b1; // Pull line high to signal Stop Bit
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 12'd0;
                        byte_index <= byte_index + 1'b1;
                        state <= NEXT; // Cycle to the next byte
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule