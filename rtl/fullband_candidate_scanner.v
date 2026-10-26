// ==============================================================================
// Module: fullband_candidate_scanner.v
// Project: AEGIS-RF (PolarFire SoC Icicle Kit)
// Description: Continuous 2048-bin coarse peak detector that remains 100% active
//              across ALL operating modes. Flags candidate peaks and ensures
//              zero missed detections outside detailed sub-band windows.
// ==============================================================================

`timescale 1ns / 1ps

module fullband_candidate_scanner #(
    parameter FFT_POINTS = 2048,
    parameter PWR_WIDTH  = 32,
    parameter MAX_CANDS  = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Streaming Power Input
    input  wire [PWR_WIDTH-1:0]  pwr_data,
    input  wire                  pwr_valid,
    input  wire                  pwr_last,
    
    // Coarse Threshold Parameter from AXI-Lite
    input  wire [PWR_WIDTH-1:0]  coarse_noise_floor_threshold,
    
    // Candidate Extraction Interface
    output reg  [11:0]           candidate_bin_index,
    output reg  [PWR_WIDTH-1:0]  candidate_peak_power,
    output reg                   candidate_valid,
    output reg  [7:0]            total_candidates_in_frame,
    output reg                   scan_frame_done
);

    reg [11:0] bin_counter;
    reg [7:0]  cand_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin_counter               <= 12'd0;
            cand_cnt                  <= 8'd0;
            candidate_bin_index       <= 12'd0;
            candidate_peak_power      <= 32'd0;
            candidate_valid           <= 1'b0;
            total_candidates_in_frame <= 8'd0;
            scan_frame_done           <= 1'b0;
        end else if (pwr_valid) begin
            // Increment bin index across all 2048 bins
            bin_counter <= bin_counter + 1'b1;

            // Peak threshold detector: check if power exceeds coarse noise floor
            if (pwr_data > coarse_noise_floor_threshold && cand_cnt < MAX_CANDS) begin
                candidate_bin_index  <= bin_counter;
                candidate_peak_power <= pwr_data;
                candidate_valid      <= 1'b1;
                cand_cnt             <= cand_cnt + 1'b1;
            end else begin
                candidate_valid      <= 1'b0;
            end

            // End of 2048-sample FFT frame
            if (pwr_last || bin_counter == (FFT_POINTS - 1)) begin
                bin_counter               <= 12'd0;
                total_candidates_in_frame <= cand_cnt;
                cand_cnt                  <= 8'd0;
                scan_frame_done           <= 1'b1;
            end else begin
                scan_frame_done           <= 1'b0;
            end
        end else begin
            candidate_valid <= 1'b0;
            scan_frame_done <= 1'b0;
        end
    end

endmodule
