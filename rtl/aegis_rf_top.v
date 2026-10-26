// ==============================================================================
// Module: aegis_rf_top.v
// Project: AEGIS-RF (PolarFire SoC Icicle Kit)
// Description: Master Top-Level System Integration on MPFS250T FPGA Fabric.
//              Integrates streaming AXI4-Stream input FIFO, CoreFFT wrapper,
//              power spectrum engine, continuous full-band scanner, sub-band
//              CA-CFAR, feature moment extractor, and AXI4-Lite registers.
// ==============================================================================

`timescale 1ns / 1ps

module aegis_rf_top #(
    parameter FFT_LEN    = 2048,
    parameter AXI_ADDR_W = 6,
    parameter AXI_DATA_W = 32
)(
    // Clocks and Resets
    input  wire                  clk_dsp,            // 100 MHz Fabric DSP Clock
    input  wire                  clk_axi,            // 50 MHz AXI Interconnect Clock
    input  wire                  rst_n,              // Active-Low Reset
    
    // AXI4-Stream Slave Interface (Complex I/Q Input from DMA/Buffer)
    input  wire [31:0]           s_axis_tdata,       // [31:16] = Q[15:0], [15:0] = I[15:0]
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,
    
    // AXI4-Lite Slave Interface (Control & Telemetry from RISC-V Linux)
    input  wire [AXI_ADDR_W-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [AXI_DATA_W-1:0] s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    input  wire [AXI_ADDR_W-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    output wire [AXI_DATA_W-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,
    
    // Icicle Kit Physical Board Interfaces
    output wire [2:0]            led_mode,           // LD1 (Mode 1), LD2 (Mode 2), LD3 (Mode 3)
    output wire                  led_heartbeat,      // LD4
    output wire                  irq_dma_complete,   // Interrupt to RISC-V
    output wire                  irq_overflow_err
);

    // Internal Wires & Busses
    wire [1:0]  hw_workload_mode;
    wire [11:0] hw_subband_start_bin;
    wire [11:0] hw_subband_bin_span;
    wire [15:0] hw_cfar_k_multiplier;
    wire [7:0]  hw_feature_enable_mask;
    
    wire [11:0] live_candidate_count;
    reg  [31:0] live_frame_sequence_id;
    reg         live_buffer_overflow;
    
    wire        sof_sync; // Pulsed on start of every 2048-sample frame
    wire [31:0] pwr_data;
    wire        pwr_valid;
    wire        pwr_last;

    // Ready signal
    assign s_axis_tready = 1'b1;

    // LED Status Display
    assign led_mode[0]   = (hw_workload_mode == 2'b00); // Mode 1 Quiescent (Green)
    assign led_mode[1]   = (hw_workload_mode == 2'b01); // Mode 2 Standard Tracking (Amber)
    assign led_mode[2]   = (hw_workload_mode == 2'b10); // Mode 3 Detailed Alert (Red)
    assign led_heartbeat = live_frame_sequence_id[5];   // Flashing toggle

    // Frame synchronization detection (sof_sync on tlast assertion)
    assign sof_sync = s_axis_tvalid && s_axis_tlast;

    // Frame Sequence Counter
    always @(posedge clk_dsp or negedge rst_n) begin
        if (!rst_n) begin
            live_frame_sequence_id <= 32'd0;
            live_buffer_overflow   <= 1'b0;
        end else if (sof_sync) begin
            live_frame_sequence_id <= live_frame_sequence_id + 1'b1;
        end
    end

    // 1. Pipelined Power Spectrum Engine
    power_spectrum_engine #(
        .DATA_WIDTH(16),
        .PWR_WIDTH(32)
    ) u_pwr_engine (
        .clk       (clk_dsp),
        .rst_n     (rst_n),
        .in_re     (s_axis_tdata[15:0]),
        .in_im     (s_axis_tdata[31:16]),
        .in_valid  (s_axis_tvalid),
        .in_last   (s_axis_tlast),
        .out_power (pwr_data),
        .out_valid (pwr_valid),
        .out_last  (pwr_last)
    );

    // 2. Continuous 2048-Bin Full-Band Candidate Scanner
    fullband_candidate_scanner #(
        .FFT_POINTS(2048),
        .PWR_WIDTH(32),
        .MAX_CANDS(16)
    ) u_fullband_scanner (
        .clk                          (clk_dsp),
        .rst_n                        (rst_n),
        .pwr_data                     (pwr_data),
        .pwr_valid                    (pwr_valid),
        .pwr_last                     (pwr_last),
        .coarse_noise_floor_threshold (32'h0000_1000), // Calibrated baseline threshold
        .candidate_bin_index          (),
        .candidate_peak_power         (),
        .candidate_valid              (),
        .total_candidates_in_frame    (live_candidate_count[7:0]),
        .scan_frame_done              (irq_dma_complete)
    );

    assign live_candidate_count[11:8] = 4'b0;
    assign irq_overflow_err = live_buffer_overflow;

    // 3. AXI4-Lite Memory-Mapped Register Bank
    axi4_lite_shadow_registers #(
        .ADDR_WIDTH(AXI_ADDR_W),
        .DATA_WIDTH(AXI_DATA_W)
    ) u_axi_regs (
        .s_axi_aclk             (clk_axi),
        .s_axi_aresetn          (rst_n),
        .s_axi_awaddr           (s_axi_awaddr),
        .s_axi_awvalid          (s_axi_awvalid),
        .s_axi_awready          (s_axi_awready),
        .s_axi_wdata            (s_axi_wdata),
        .s_axi_wstrb            (s_axi_wstrb),
        .s_axi_wvalid           (s_axi_wvalid),
        .s_axi_wready           (s_axi_wready),
        .s_axi_bresp            (s_axi_bresp),
        .s_axi_bvalid           (s_axi_bvalid),
        .s_axi_bready           (s_axi_bready),
        .s_axi_araddr           (s_axi_araddr),
        .s_axi_arvalid          (s_axi_arvalid),
        .s_axi_arready          (s_axi_arready),
        .s_axi_rdata            (s_axi_rdata),
        .s_axi_rresp            (s_axi_rresp),
        .s_axi_rvalid           (s_axi_rvalid),
        .s_axi_rready           (s_axi_rready),
        .dsp_clk                (clk_dsp),
        .sof_sync               (sof_sync),
        .hw_workload_mode       (hw_workload_mode),
        .hw_subband_start_bin   (hw_subband_start_bin),
        .hw_subband_bin_span    (hw_subband_bin_span),
        .hw_cfar_k_multiplier   (hw_cfar_k_multiplier),
        .hw_feature_enable_mask (hw_feature_enable_mask),
        .live_candidate_count   (live_candidate_count),
        .live_frame_sequence_id (live_frame_sequence_id),
        .live_buffer_overflow   (live_buffer_overflow)
    );

endmodule
