module top_abaco(
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    output wire       GPIO_0,
    output wire [6:0] HEX0
);

    // --- ADC & SYSTEM WIRES ---
    wire [31:0] adc_readdata;
    wire pll_10mhz;
    wire pll_locked;

    // --- BEAD VOLTAGE REGISTERS (Now 5 beads) ---
    reg [11:0] vol_bead0 = 0;
    reg [11:0] vol_bead1 = 0;
    reg [11:0] vol_bead2 = 0;
    reg [11:0] vol_bead3 = 0;
    reg [11:0] vol_bead4 = 0;

    // --- ADC SEQUENCER STATE MACHINE ---
    reg [19:0] warmup_timer = 0; 
    reg [2:0]  state = 0;
    reg [2:0]  current_bead = 0; // Expanded to 3 bits to count to 4
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
                        // Save the voltage to the correct bead register
                        if (current_bead == 3'd0) vol_bead0 <= adc_readdata[11:0];
                        else if (current_bead == 3'd1) vol_bead1 <= adc_readdata[11:0];
                        else if (current_bead == 3'd2) vol_bead2 <= adc_readdata[11:0];
                        else if (current_bead == 3'd3) vol_bead3 <= adc_readdata[11:0];
                        else if (current_bead == 3'd4) vol_bead4 <= adc_readdata[11:0];
                        
                        // Loop from 0 to 4 (5 channels total)
                        if (current_bead == 3'd4) begin
                            current_bead <= 0;
                        end else begin
                            current_bead <= current_bead + 1;
                        end
                        
                        read_delay <= 0;
                    end
                end
            endcase
        end
    end
    
    // --- IP CORE INSTANTIATIONS ---
    my_pll pll_inst (
        .inclk0(MAX10_CLK1_50), 
        .c0(pll_10mhz), 
        .locked(pll_locked)
    );

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
        
        // Padded with 4'b0000 to keep the address bus exactly 7 bits wide
        .sample_store_csr_address   ({4'b0000, current_bead}),  
        .sample_store_csr_read      (1'b1),   
        .sample_store_csr_write     (1'b0),   
        .sample_store_csr_writedata (32'b0),
        .sample_store_csr_readdata  (adc_readdata),
        .sample_store_irq_irq       ()
    );

    // --- 1. THE BEAD TRACKERS ---
    wire [1:0] state_u0, state_l0, state_l1, state_l2, state_l3;

    // Mapping the 5 channels: 1 upper bead, 4 lower beads
    bead_tracker tracker_u0 (.clk(MAX10_CLK1_50), .voltage_in(vol_bead0), .state_out(state_u0));
    bead_tracker tracker_l0 (.clk(MAX10_CLK1_50), .voltage_in(vol_bead1), .state_out(state_l0));
    bead_tracker tracker_l1 (.clk(MAX10_CLK1_50), .voltage_in(vol_bead2), .state_out(state_l1));
    bead_tracker tracker_l2 (.clk(MAX10_CLK1_50), .voltage_in(vol_bead3), .state_out(state_l2));
    bead_tracker tracker_l3 (.clk(MAX10_CLK1_50), .voltage_in(vol_bead4), .state_out(state_l3));

    // --- 2. THE COLUMN DECODER ---
    wire [3:0] col_0_val;
    
    // The fake '01' padding is removed. We now pass all 4 real lower beads directly.
    wire [7:0] lower_bus_0 = {state_l3, state_l2, state_l1, state_l0};
    
    column_decoder col0_dec (
        .upper_bead(state_u0), 
        .lower_beads(lower_bus_0), 
        .column_value(col_0_val)
    );
    
    // --- 3. CONTINUOUS MATH CALCULATION --- 
    wire [31:0] current_abacus_val;
    
    assign current_abacus_val = 
        ({28'd0, 4'd0} * 32'd1000000) + 
        ({28'd0, 4'd0} * 32'd100000)  + 
        ({28'd0, 4'd0} * 32'd10000)   + 
        ({28'd0, 4'd0} * 32'd1000)    + 
        ({28'd0, 4'd0} * 32'd100)     + 
        ({28'd0, 4'd0} * 32'd10)      + 
        {28'd0, col_0_val};

    // --- 4. THE SPEAK TRIGGER LOGIC ---
    wire btn_speak_clean;
    reg  btn_speak_last;
    
    reg [31:0] number_to_speak = 0;
    reg speak_trigger = 0;

    debounce deb_speak (
        .clk(MAX10_CLK1_50), 
        .rst_n(1'b1), 
        .button_in(KEY[0]), 
        .button_out(btn_speak_clean)
    );

    always @(posedge MAX10_CLK1_50) begin
        btn_speak_last <= btn_speak_clean;
        
        if (btn_speak_last == 1'b1 && btn_speak_clean == 1'b0) begin
            number_to_speak <= current_abacus_val;
            speak_trigger <= 1'b1;
        end else begin
            speak_trigger <= 1'b0; 
        end
    end
    
    // --- 5. DATA TRANSMISSION & DISPLAY ---
    wire tx_busy;
    
    uart_tx u_uart (
        .clk(MAX10_CLK1_50),          
        .rst_n(1'b1),                 
        .tx_start(speak_trigger),     
        .data_in(number_to_speak),    
        .tx_pin(GPIO_0),              
        .busy(tx_busy)
    );
    
    hex_decoder u_hex0 (
        .bin_in(number_to_speak[3:0]), 
        .hex_out(HEX0)                 
    );

endmodule
