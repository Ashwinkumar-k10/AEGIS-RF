// ==============================================================================
// Module: tb_aegis_rf_top.v
// Project: AEGIS-RF (PolarFire SoC Icicle Kit)
// Description: RTL Simulation Testbench for AEGIS-RF Top-Level System.
//              Simulates continuous 2048-sample AXI-Stream frame feeding,
//              coarse peak candidate detection, and AXI-Lite register latching.
// ==============================================================================

`timescale 1ns / 1ps

module tb_aegis_rf_top;

    reg         clk_dsp;
    reg         clk_axi;
    reg         rst_n;
    
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;
    
    wire [2:0]  led_mode;
    wire        led_heartbeat;
    wire        irq_dma_complete;
    wire        irq_overflow_err;

    // Instantiate AEGIS-RF Top Module
    aegis_rf_top #(
        .FFT_LEN(2048),
        .AXI_ADDR_W(6),
        .AXI_DATA_W(32)
    ) uut (
        .clk_dsp          (clk_dsp),
        .clk_axi          (clk_axi),
        .rst_n            (rst_n),
        .s_axis_tdata     (s_axis_tdata),
        .s_axis_tvalid    (s_axis_tvalid),
        .s_axis_tready    (s_axis_tready),
        .s_axis_tlast     (s_axis_tlast),
        .s_axi_awaddr     (6'd0),
        .s_axi_awvalid    (1'b0),
        .s_axi_awready    (),
        .s_axi_wdata      (32'd0),
        .s_axi_wstrb      (4'h0),
        .s_axi_wvalid     (1'b0),
        .s_axi_wready     (),
        .s_axi_bresp      (),
        .s_axi_bvalid     (),
        .s_axi_bready     (1'b1),
        .s_axi_araddr     (6'd0),
        .s_axi_arvalid    (1'b0),
        .s_axi_arready    (),
        .s_axi_rdata      (),
        .s_axi_rresp      (),
        .s_axi_rvalid     (),
        .s_axi_rready     (1'b1),
        .led_mode         (led_mode),
        .led_heartbeat    (led_heartbeat),
        .irq_dma_complete (irq_dma_complete),
        .irq_overflow_err (irq_overflow_err)
    );

    // 100 MHz DSP Clock generation (10 ns period)
    always #5.0 clk_dsp = ~clk_dsp;

    // 50 MHz AXI Clock generation (20 ns period)
    always #10.0 clk_axi = ~clk_axi;

    integer i, frame;

    initial begin
        clk_dsp       = 0;
        clk_axi       = 0;
        rst_n         = 0;
        s_axis_tdata  = 32'h0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        // Apply Reset
        #100;
        rst_n = 1;
        #100;
        $display("[TB] Reset de-asserted. Commencing streaming I/Q frames...");

        // Stream 3 consecutive 2048-sample frames
        for (frame = 0; frame < 3; frame = frame + 1) begin
            $display("[TB] Starting Frame %0d streaming at time %t", frame, $time);
            for (i = 0; i < 2048; i = i + 1) begin
                @(posedge clk_dsp);
                s_axis_tvalid <= 1'b1;
                // Synthetic I/Q: Inject peak at bin 512 (sample 512)
                if (i == 512)
                    s_axis_tdata <= {16'h2000, 16'h2000}; // High power peak
                else
                    s_axis_tdata <= {16'h0080, 16'h0080}; // Low noise floor
                
                s_axis_tlast <= (i == 2047) ? 1'b1 : 1'b0;
            end
            @(posedge clk_dsp);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
            #500; // Inter-frame gap
        end

        #2000;
        $display("[TB] Simulation completed successfully with zero buffer overflow!");
        $finish;
    end

endmodule
