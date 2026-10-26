/**
 * @file aegis_registers.h
 * @brief Memory-Mapped Register Definitions for AEGIS-RF AXI4-Lite Control Bus
 * @details Target Base Address: 0x4000_0000 on PolarFire SoC Icicle Kit
 */

#ifndef AEGIS_REGISTERS_H
#define AEGIS_REGISTERS_H

#include <stdint.h>

#define AEGIS_AXI_BASE_ADDR         0x40000000

// Register Offsets matching Table 8 in Proposal
#define REG_AEGIS_WORKLOAD_MODE     0x00  // RW: [1:0] Workload Mode (00=Coarse, 01=Standard, 10=Detailed), [2] DSP Enable
#define REG_AEGIS_SUBBAND_START     0x04  // RW: [11:0] Sub-band Start Frequency Bin (0-2047)
#define REG_AEGIS_SUBBAND_SPAN      0x08  // RW: [11:0] Sub-band Analysis Window Span (256, 1024, 2048)
#define REG_AEGIS_CFAR_CONFIG       0x0C  // RW: [15:0] K_CFAR Multiplier (Q8.8 fixed-point), [23:16] N_ref, [31:24] N_guard
#define REG_AEGIS_FEATURE_MASK      0x10  // RW: [7:0] Feature Extraction Mask (Bit 0=Centroid, 1=Spread, 2=PAPR, 3=Skewness)
#define REG_AEGIS_STATUS_FLAGS      0x14  // RO: [0] Buffer Overflow, [1] Frame Ready, [2] Underflow, [3] FSM Locked
#define REG_AEGIS_CANDIDATE_CNT     0x18  // RO: [11:0] Total Candidate Peaks Detected in Current Frame
#define REG_AEGIS_FRAME_SEQ_ID      0x1C  // RO: [31:0] Monotonic Hardware Frame Sequence Counter

// Mode Definitions
typedef enum {
    AEGIS_MODE_COARSE   = 0x00,  // Low workload / Quiescent spectrum (256-bin window)
    AEGIS_MODE_STANDARD = 0x01,  // Balanced tracking (1024-bin window)
    AEGIS_MODE_DETAILED = 0x02   // High-detail alert (Full 2048-bin analysis)
} aegis_mode_t;

// Macro register access
#define AEGIS_READ_REG(offset)         (*(volatile uint32_t *)(AEGIS_AXI_BASE_ADDR + (offset)))
#define AEGIS_WRITE_REG(offset, val)   (*(volatile uint32_t *)(AEGIS_AXI_BASE_ADDR + (offset)) = (uint32_t)(val))

#endif // AEGIS_REGISTERS_H
