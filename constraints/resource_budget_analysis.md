# AEGIS-RF: PolarFire SoC MPFS250T Silicon Resource Budget Analysis

## 1. Overview
The **PolarFire SoC MPFS250T-FCVG484E** integrates 254K Logic Elements (4-input LUTs + DFFs), 784 dedicated 18x18 Math Blocks (DSP), and 816 Large SRAM blocks (20 kb each, total 16.32 Mb). AEGIS-RF is conservatively architected to consume **under 45% of total silicon resources**, ensuring timing closure at 100–125 MHz and generous routing headroom.

## 2. Subsystem Resource Breakdown Table

| Subsystem Module | Logic Elements (LE) | Math Blocks (DSP) | LSRAM (20 kb) | uSRAM (64-bit) | Functional Responsibility |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **I/Q Streaming FIFO & Alignment** | 1,850 (0.7%) | 0 (0.0%) | 4 (0.5%) | 16 (1.2%) | AXI4-Stream slave, frame synchronization, 2048-sample circular input FIFO. |
| **Microchip CoreFFT v7.1 IP** | 42,500 (16.7%) | 192 (24.5%) | 144 (17.6%) | 0 (0.0%) | Fixed 2048-point complex streaming Radix-2/4 pipeline with convergent rounding. |
| **Magnitude Squaring Engine** | 4,200 (1.7%) | 32 (4.1%) | 0 (0.0%) | 0 (0.0%) | Pipelined Re^2 + Im^2 squaring with 32-bit dynamic range saturation. |
| **Full-Band Candidate Scanner** | 8,600 (3.4%) | 16 (2.0%) | 32 (3.9%) | 64 (4.9%) | Continuous 2048-bin coarse peak detector, dynamic noise floor estimation. |
| **Sub-Band CA-CFAR Engine** | 21,400 (8.4%) | 64 (8.2%) | 64 (7.8%) | 32 (2.5%) | Sliding window cell-averaging CFAR (CUT, 8 guard, 32 reference cells). |
| **Feature Extraction Moments Unit** | 11,200 (4.4%) | 48 (6.1%) | 16 (2.0%) | 16 (1.2%) | 1st to 4th-order spectral moments: centroid, spread, skewness, PAPR. |
| **AXI4-Lite Register & Control Bank** | 2,100 (0.8%) | 0 (0.0%) | 0 (0.0%) | 16 (1.2%) | 0x00–0x1C shadow register bank with frame-synchronous sof_sync latching. |
| **CoreAXI4DMA & Ping-Pong Memory FSM** | 4,350 (1.7%) | 0 (0.0%) | 8 (1.0%) | 32 (2.5%) | 64-bit AXI4 master DMA engine, circular descriptor management, IRQ generation. |
| **TOTAL ESTIMATED FABRIC UTILIZATION** | **96,200 (37.8%)** | **352 (44.8%)** | **268 (32.8%)** | **176 (13.6%)** | **Conservatively within 45% ceiling. Zero routing congestion.** |
| **AVAILABLE POLARFIRE MPFS250T CAPACITY** | **254,196 (100%)** | **784 (100%)** | **816 (100%)** | **1,296 (100%)** | **Safe margin > 55% across all silicon primitives.** |

## 3. Clock Domain Architecture
* **Fabric DSP Domain (`clk_dsp`):** 100.0 MHz (Period = 10.0 ns).
* **MSS Subsystem Bus Domain (`clk_axi`):** 50.0 MHz (Period = 20.0 ns).
* **Reference Oscillator:** 50.0 MHz on-board oscillator conditioned via PolarFire Clock Conditioning Circuit (CCC/PLL).
