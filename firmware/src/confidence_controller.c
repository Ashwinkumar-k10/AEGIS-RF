/**
 * @file confidence_controller.c
 * @brief Multi-Parameter Confidence Scoring & Hysteresis State Machine
 * @details Executes on Quad-Core SiFive U54 RISC-V Linux MSS
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include "../inc/aegis_registers.h"

// Weighting parameters for Confidence Metric Fusion (w1 + w2 + w3 = 1.0)
#define WEIGHT_PNR          0.40f  // Peak-to-Noise Ratio contribution
#define WEIGHT_PERSISTENCE  0.35f  // Temporal history stability
#define WEIGHT_MARGIN       0.25f  // Detection margin above CFAR floor

// Hysteresis Thresholds
#define THRESH_ESCALATE     0.70f  // Trigger Detailed Mode when C_det >= 0.70
#define THRESH_DEESCALATE   0.20f  // Return to Coarse Mode when C_det <= 0.20
#define HYSTERESIS_DWELL    16     // Must dwell for at least 16 frames before de-escalation

typedef struct {
    aegis_mode_t current_mode;
    uint32_t dwell_frame_counter;
    float recent_persistence_history[32];
    uint8_t history_index;
} confidence_fsm_t;

static confidence_fsm_t g_fsm = {
    .current_mode = AEGIS_MODE_COARSE,
    .dwell_frame_counter = 0,
    .history_index = 0
};

/**
 * @brief Evaluates bounded multi-parameter confidence score
 * @formula C_det = w1 * S_PNR + w2 * S_persistence + w3 * S_margin
 */
float calculate_confidence_score(float pnr_db, float persistence_ratio, float margin_db) {
    // Normalization to [0.0, 1.0]
    float s_pnr = (pnr_db > 30.0f) ? 1.0f : ((pnr_db < 0.0f) ? 0.0f : (pnr_db / 30.0f));
    float s_persist = (persistence_ratio > 1.0f) ? 1.0f : ((persistence_ratio < 0.0f) ? 0.0f : persistence_ratio);
    float s_margin = (margin_db > 20.0f) ? 1.0f : ((margin_db < 0.0f) ? 0.0f : (margin_db / 20.0f));

    return (WEIGHT_PNR * s_pnr) + (WEIGHT_PERSISTENCE * s_persist) + (WEIGHT_MARGIN * s_margin);
}

/**
 * @brief Step function for supervisory state machine with anti-flapping hysteresis
 */
aegis_mode_t update_adaptive_mode(float confidence_score, uint16_t candidate_count) {
    g_fsm.dwell_frame_counter++;

    // Safe Fallback Rule: If zero candidates exist, spectrum is quiescent
    if (candidate_count == 0) {
        if (g_fsm.current_mode != AEGIS_MODE_COARSE && g_fsm.dwell_frame_counter >= HYSTERESIS_DWELL) {
            g_fsm.current_mode = AEGIS_MODE_COARSE;
            g_fsm.dwell_frame_counter = 0;
            printf("[AEGIS-FSM] De-escalating to Mode 1 (Coarse Surveillance)\n");
        }
        return g_fsm.current_mode;
    }

    // Escalation logic: Fast transition to high detail on ambiguous / weak candidates
    if (confidence_score >= THRESH_ESCALATE || candidate_count > 8) {
        if (g_fsm.current_mode != AEGIS_MODE_DETAILED) {
            g_fsm.current_mode = AEGIS_MODE_DETAILED;
            g_fsm.dwell_frame_counter = 0;
            printf("[AEGIS-FSM] Escalating to Mode 3 (Detailed Analysis)\n");
        }
    } 
    // Standard Tracking range
    else if (confidence_score > THRESH_DEESCALATE && confidence_score < THRESH_ESCALATE) {
        if (g_fsm.current_mode != AEGIS_MODE_STANDARD && g_fsm.dwell_frame_counter >= HYSTERESIS_DWELL) {
            g_fsm.current_mode = AEGIS_MODE_STANDARD;
            g_fsm.dwell_frame_counter = 0;
            printf("[AEGIS-FSM] Transitioning to Mode 2 (Standard Tracking)\n");
        }
    }
    // De-escalation logic with mandatory dwell time to prevent flapping
    else if (confidence_score <= THRESH_DEESCALATE && g_fsm.dwell_frame_counter >= HYSTERESIS_DWELL) {
        if (g_fsm.current_mode != AEGIS_MODE_COARSE) {
            g_fsm.current_mode = AEGIS_MODE_COARSE;
            g_fsm.dwell_frame_counter = 0;
            printf("[AEGIS-FSM] De-escalating to Mode 1 (Coarse Surveillance)\n");
        }
    }

    return g_fsm.current_mode;
}
