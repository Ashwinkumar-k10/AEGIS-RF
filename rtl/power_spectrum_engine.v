// ==============================================================================
// Module: power_spectrum_engine.v
// Project: AEGIS-RF (PolarFire SoC Icicle Kit)
// Description: 3-stage pipelined 32-bit magnitude squaring (|X[k]|^2 = Re^2 + Im^2)
//              with saturation protection mapping CoreFFT output into power.
// ==============================================================================

`timescale 1ns / 1ps

module power_spectrum_engine #(
    parameter DATA_WIDTH = 16,
    parameter PWR_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Streaming Input from CoreFFT
    input  wire signed [DATA_WIDTH-1:0] in_re,
    input  wire signed [DATA_WIDTH-1:0] in_im,
    input  wire                         in_valid,
    input  wire                         in_last,
    
    // Pipelined Power Output
    output reg  [PWR_WIDTH-1:0]         out_power,
    output reg                          out_valid,
    output reg                          out_last
);

    // Stage 1: Pipeline registers for input
    reg signed [DATA_WIDTH-1:0] r1_re, r1_im;
    reg r1_valid, r1_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1_re    <= 0;
            r1_im    <= 0;
            r1_valid <= 0;
            r1_last  <= 0;
        end else begin
            r1_re    <= in_re;
            r1_im    <= in_im;
            r1_valid <= in_valid;
            r1_last  <= in_last;
        end
    end

    // Stage 2: Parallel Multiply (Utilizing PolarFire dedicated 18x18 Math Blocks)
    reg [31:0] r2_sq_re, r2_sq_im;
    reg r2_valid, r2_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r2_sq_re <= 0;
            r2_sq_im <= 0;
            r2_valid <= 0;
            r2_last  <= 0;
        end else begin
            r2_sq_re <= r1_re * r1_re;
            r2_sq_im <= r1_im * r1_im;
            r2_valid <= r1_valid;
            r2_last  <= r1_last;
        end
    end

    // Stage 3: Summation with Saturation Guard
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_power <= 0;
            out_valid <= 0;
            out_last  <= 0;
        end else begin
            out_valid <= r2_valid;
            out_last  <= r2_last;
            // 32-bit addition with overflow saturation clamp
            if (({1'b0, r2_sq_re} + {1'b0, r2_sq_im}) > 33'h0_FFFF_FFFF)
                out_power <= 32'hFFFF_FFFF;
            else
                out_power <= r2_sq_re + r2_sq_im;
        end
    end

endmodule
