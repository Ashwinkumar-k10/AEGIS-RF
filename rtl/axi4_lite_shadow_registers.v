// ==============================================================================
// Module: axi4_lite_shadow_registers.v
// Project: AEGIS-RF (PolarFire SoC Icicle Kit)
// Description: Memory-mapped control and status registers (Base: 0x4000_0000).
//              Features staged shadow registers latched into active hardware
//              registers strictly on 'sof_sync' (Start-of-Frame) boundary.
// ==============================================================================

`timescale 1ns / 1ps

module axi4_lite_shadow_registers #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  wire                  s_axi_aclk,
    input  wire                  s_axi_aresetn,
    
    // AXI4-Lite Write Channels
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,
    
    // AXI4-Lite Read Channels
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,
    
    // Frame Boundary Latching Synchronization
    input  wire                  dsp_clk,
    input  wire                  sof_sync,       // Pulsed at start of every 2048-sample frame
    
    // Active Hardware Outputs (Used by Fabric DSP)
    output reg  [1:0]            hw_workload_mode,     // 0x00: Coarse, 0x01: Standard, 0x02: Detailed
    output reg  [11:0]           hw_subband_start_bin, // Window start bin (0-2047)
    output reg  [11:0]           hw_subband_bin_span,  // Window span (256, 1024, 2048)
    output reg  [15:0]           hw_cfar_k_multiplier, // Fixed-point alpha multiplier
    output reg  [7:0]            hw_feature_enable_mask,
    
    // Live Hardware Status Inputs (From Fabric DSP)
    input  wire [11:0]           live_candidate_count,
    input  wire [31:0]           live_frame_sequence_id,
    input  wire                  live_buffer_overflow
);

    // Register Offsets matching Table 8 in Proposal
    localparam REG_CONTROL_MODE    = 6'h00; // Workload mode & DSP enable
    localparam REG_SUBBAND_START   = 6'h04; // Candidate sub-band start bin
    localparam REG_SUBBAND_SPAN    = 6'h08; // Analysis window span
    localparam REG_CFAR_CONFIG     = 6'h0C; // K_CFAR multiplier & cell counts
    localparam REG_FEATURE_MASK    = 6'h10; // Moments calculation mask
    localparam REG_STATUS_FLAGS    = 6'h14; // Read-only status & overflow
    localparam REG_CANDIDATE_CNT   = 6'h18; // Read-only candidate count
    localparam REG_FRAME_SEQ_ID    = 6'h1C; // Read-only monotonic frame counter

    // Shadow Registers (Software Writable)
    reg [DATA_WIDTH-1:0] shadow_reg_mode;
    reg [DATA_WIDTH-1:0] shadow_reg_start;
    reg [DATA_WIDTH-1:0] shadow_reg_span;
    reg [DATA_WIDTH-1:0] shadow_reg_cfar;
    reg [DATA_WIDTH-1:0] shadow_reg_feat;

    // AXI-Lite Write FSM
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready    <= 1'b0;
            s_axi_wready     <= 1'b0;
            s_axi_bvalid     <= 1'b0;
            s_axi_bresp      <= 2'b00;
            shadow_reg_mode  <= 32'h0000_0001; // Default: Mode 1 Coarse, DSP Enabled
            shadow_reg_start <= 32'h0000_0000;
            shadow_reg_span  <= 32'h0000_0100; // Default: 256 Bins
            shadow_reg_cfar  <= 32'h0000_0480; // K_CFAR = 4.5
            shadow_reg_feat  <= 32'h0000_0001;
        end else begin
            // Handshake logic
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                case (s_axi_awaddr[ADDR_WIDTH-1:2] << 2)
                    REG_CONTROL_MODE:  shadow_reg_mode  <= s_axi_wdata;
                    REG_SUBBAND_START: shadow_reg_start <= s_axi_wdata;
                    REG_SUBBAND_SPAN:  shadow_reg_span  <= s_axi_wdata;
                    REG_CFAR_CONFIG:   shadow_reg_cfar  <= s_axi_wdata;
                    REG_FEATURE_MASK:  shadow_reg_feat  <= s_axi_wdata;
                    default: ; // Status registers are read-only
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // AXI-Lite Read FSM
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;
                case (s_axi_araddr[ADDR_WIDTH-1:2] << 2)
                    REG_CONTROL_MODE:  s_axi_rdata <= shadow_reg_mode;
                    REG_SUBBAND_START: s_axi_rdata <= shadow_reg_start;
                    REG_SUBBAND_SPAN:  s_axi_rdata <= shadow_reg_span;
                    REG_CFAR_CONFIG:   s_axi_rdata <= shadow_reg_cfar;
                    REG_FEATURE_MASK:  s_axi_rdata <= shadow_reg_feat;
                    REG_STATUS_FLAGS:  s_axi_rdata <= {31'b0, live_buffer_overflow};
                    REG_CANDIDATE_CNT: s_axi_rdata <= {20'b0, live_candidate_count};
                    REG_FRAME_SEQ_ID:  s_axi_rdata <= live_frame_sequence_id;
                    default:           s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                end
            end
        end
    end

    // Clock Domain Crossing: Latch Shadow to Active on 'sof_sync' pulse
    always @(posedge dsp_clk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            hw_workload_mode       <= 2'b00; // Mode 1 Coarse
            hw_subband_start_bin   <= 12'd0;
            hw_subband_bin_span    <= 12'd256;
            hw_cfar_k_multiplier   <= 16'h0480;
            hw_feature_enable_mask <= 8'h01;
        end else if (sof_sync) begin
            // Synchronous update at frame boundary guarantees zero mid-frame corruption
            hw_workload_mode       <= shadow_reg_mode[1:0];
            hw_subband_start_bin   <= shadow_reg_start[11:0];
            hw_subband_bin_span    <= shadow_reg_span[11:0];
            hw_cfar_k_multiplier   <= shadow_reg_cfar[15:0];
            hw_feature_enable_mask <= shadow_reg_feat[7:0];
        end
    end

endmodule
