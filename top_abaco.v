module top_abaco(
    input  wire       MAX10_CLK1_50,
    input wire [1:0] KEY,
	 output wire GPIO_0
);

    wire [31:0] adc_readdata;
    wire pll_10mhz;
    wire pll_locked;

    reg [11:0] vol_bead0 = 0;
    reg [11:0] vol_bead1 = 0;
    reg [11:0] vol_bead2 = 0;
    reg [11:0] vol_bead3 = 0;
    
    wire [1:0] state_bead0;
    wire [1:0] state_bead1;
    wire [1:0] state_bead2;
    wire [1:0] state_bead3;

    reg [19:0] warmup_timer = 0; 
    reg [2:0]  state = 0;
    reg [1:0]  current_bead = 0; 
    reg [2:0]  read_delay = 0;
    reg seq_write = 0;

    always @(posedge MAX10_CLK1_50) begin
        if (pll_locked == 1'b1) begin 
            case (state)
                0: begin 
                    if (warmup_timer < 20'd500_000) warmup_timer <= warmup_timer + 1;
                    else state <= 1;
                end
                1: begin 
                    seq_write <= 1'b1; 
                    state <= 2;
                end
                2: begin 
                    seq_write <= 1'b0; 
                    state <= 3;
                end
                3: begin
                    if (read_delay < 3'd4) begin
                        read_delay <= read_delay + 1;
                    end else begin
                        if (current_bead == 2'd0) vol_bead0 <= adc_readdata[11:0];
                        else if (current_bead == 2'd1) vol_bead1 <= adc_readdata[11:0];
                        else if (current_bead == 2'd2) vol_bead2 <= adc_readdata[11:0];
                        else if (current_bead == 2'd3) vol_bead3 <= adc_readdata[11:0];
                        
                        current_bead <= current_bead + 1;
                        read_delay <= 0;
                    end
                end
            endcase
        end
    end
    
    my_pll pll_inst (.inclk0(MAX10_CLK1_50), .c0(pll_10mhz), .locked(pll_locked));

    Sensor u0 (
        .clock_clk                  (MAX10_CLK1_50),
        .reset_sink_reset_n         (1'b1),
        .adc_pll_clock_clk          (pll_10mhz),
        .adc_pll_locked_export      (pll_locked),
        
        .sequencer_csr_address      (1'b0), 
        .sequencer_csr_read         (1'b0),
        .sequencer_csr_write        (seq_write),     
        .sequencer_csr_writedata    (32'd1),
        .sequencer_csr_readdata     (), 
        
        .sample_store_csr_address   ({5'b00000, current_bead}),  
        .sample_store_csr_read      (1'b1),   
        .sample_store_csr_write     (1'b0),   
        .sample_store_csr_writedata (32'b0),
        .sample_store_csr_readdata  (adc_readdata),
        .sample_store_irq_irq       ()
    );

   // --- 1. THE BEAD TRACKERS (Example for 1 Column / 5 Beads) ---
    wire [1:0] state_u0, state_l0, state_l1, state_l2, state_l3;

    bead_tracker tracker_u0 (.clk(MAX10_CLK1_50), .voltage_in(vol_u0), .state_out(state_u0));
    bead_tracker tracker_l0 (.clk(MAX10_CLK1_50), .voltage_in(vol_l0), .state_out(state_l0));
    bead_tracker tracker_l1 (.clk(MAX10_CLK1_50), .voltage_in(vol_l1), .state_out(state_l1));
    bead_tracker tracker_l2 (.clk(MAX10_CLK1_50), .voltage_in(vol_l2), .state_out(state_l2));
    bead_tracker tracker_l3 (.clk(MAX10_CLK1_50), .voltage_in(vol_l3), .state_out(state_l3));

    // --- 2. THE COLUMN DECODER ---
    wire [3:0] col_0_val; // Will hold a digit 0-9
    
    // Bundle the 4 lower bead states into an 8-bit bus for the decoder
    wire [7:0] lower_bus_0 = {state_l3, state_l2, state_l1, state_l0};
    
    column_decoder col0_dec (
        .upper_bead(state_u0), 
        .lower_beads(lower_bus_0), 
        .column_value(col_0_val)
    );
    
    // (You would repeat this for col_1_val, col_2_val, etc. as you add multiplexers)

	 
    // --- 3. CONTINUOUS MATH CALCULATION 
    wire [31:0] current_abacus_val;
    
    // Mathematically combine the columns into one large number.
    // (Assuming col_1 through col_6 are 0 for this single-column example)
    assign current_abacus_val = 
        ({28'd0, 4'd0} * 32'd1000000) + 
        ({28'd0, 4'd0} * 32'd100000)  + 
        ({28'd0, 4'd0} * 32'd10000)   + 
        ({28'd0, 4'd0} * 32'd1000)    + 
        ({28'd0, 4'd0} * 32'd100)     + 
        ({28'd0, 4'd0} * 32'd10)      + 
        {28'd0, col_0_val};

    // --- 4. THE SPEAK TRIGGER ---
    wire btn_speak_clean;
    reg  btn_speak_last;
    
    reg [31:0] number_to_speak = 0;
    reg speak_trigger = 0;

    // Use your debounce.v module to clean the KEY[0] hardware button
    debounce deb_speak (
        .clk(MAX10_CLK1_50), 
        .rst_n(1'b1), 
        .button_in(KEY[0]), 
        .button_out(btn_speak_clean)
    );

    always @(posedge MAX10_CLK1_50) begin
        // Keep track of the button's previous state to detect a physical "press" (falling edge)
        btn_speak_last <= btn_speak_clean;
        
        // If the button was previously unpressed (1) and is now pressed (0)
        if (btn_speak_last == 1'b1 && btn_speak_clean == 1'b0) begin
            // 1. Snapshot the live math value
            number_to_speak <= current_abacus_val;
            
            // 2. Fire the trigger (this will pulse high for exactly 1 clock cycle)
            speak_trigger <= 1'b1;
        end else begin
            // Turn off the trigger immediately so it doesn't spam the speaker
            speak_trigger <= 1'b0; 
        end
    end
	 
	 wire tx_busy;
    
    uart_tx u_uart (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .tx_start(speak_trigger),     // Pulses for 1 clock cycle when button is pressed
        .data_in(number_to_speak),    // The locked 32-bit math total
        .tx_pin(GPIO_0),              // The physical pin on your Cyclone IV
        .busy(tx_busy)
    );

endmodule
