# AEGIS-RF: Confidence-Aware, Resource-Adaptive RF Spectrum Intelligence on PolarFire SoC

[![Microchip PolarFire SoC](https://img.shields.io/badge/Platform-Microchip%20PolarFire%20SoC%20(MPFS250T)-002D62.svg)](https://www.microchip.com/en-us/products/fpgas-and-plds/system-on-chip-fpgas/polarfire-soc-fpgas)
[![Contest Track](https://img.shields.io/badge/Contest-Microchip%20FPGA%20Design%20Contest%202026%20%7C%20Track%202-E31B23.svg)](https://www.microchip.com)
[![FPGA Fabric Clock](https://img.shields.io/badge/Fabric%20DSP-100%20MHz%20Continuous%20Streaming-4CAF50.svg)](#-key-technical-specifications--latency-budget)
[![Full-Band Scan](https://img.shields.io/badge/Full--Band%20Scan-2048--Point%20Fixed%20CoreFFT-00BCD4.svg)](#-fpga-fabric-architecture--resource-budget)
[![RISC-V Host](https://img.shields.io/badge/Host-Hard%20Quad--Core%20SiFive%20U54%20(Linux)-795548.svg)](#-supervisory-firmware--anti-flapping-fsm)
[![Power Telemetry](https://img.shields.io/badge/Telemetry-Microchip%20PAC1934%20(4--Rail%20I2C)-FF9800.svg)](#-power-telemetry--controlled-three-way-benchmark)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## 📌 Executive Summary

**AEGIS-RF** is an uncertainty-driven, closed-loop heterogeneous architecture for edge radio frequency (RF) spectrum monitoring implemented on the **Microchip PolarFire® SoC Icicle Kit (`MPFS250T-FCVG484E`)**. 

Conventional edge RF receivers face an architectural dilemma: they must either run a worst-case, maximum-resolution digital signal processing (DSP) pipeline continuously—incurring severe power penalties during quiescent periods—or employ static low-power configurations that fail to detect agile, low-SNR, or burst transmissions. While Dynamic Partial Reconfiguration (DPR) is sometimes proposed to address this, DPR introduces unacceptable millisecond-scale reconfiguration latencies, complex bitstream scrubbing overhead, Single Event Upset (SEU) vulnerabilities, and blind spots during transmission shifts.

**AEGIS-RF resolves this trade-off without DPR.** It combines:
1. A **fixed, deterministic 2048-point CoreFFT v7.1 streaming pipeline** executing on the low-power PolarFire FPGA fabric ($100.0\text{ MHz}$), maintaining a continuous 100% duty-cycle coarse spectrum scan across all modes.
2. A **closed-loop Confidence-Aware Supervisory Controller** executing on the embedded SiFive U54 quad-core RISC-V Linux subsystem. The controller dynamically scales downstream analysis parameters (sub-band window spans, CA-CFAR multipliers, and moment extraction) at synchronous frame boundaries via memory-mapped AXI4-Lite shadow registers.
3. Multi-rail hardware power and energy telemetry via the onboard **Microchip PAC1934** 4-channel power monitor over MSS I2C, streaming live metrics to a real-time Gigabit Ethernet web visualizer.

---

## 📑 Core Submission Deliverables

| Deliverable | Format | Verification Scope & Description |
| :--- | :--- | :--- |
| 📊 **[System Architecture Schematic](01_System_Block_Diagram_AEGIS_RF.png)** | [High-Res PNG](01_System_Block_Diagram_AEGIS_RF.png) \| [PDF](01_System_Block_Diagram_AEGIS_RF.pdf) | Complete 4-tier hardware/software architectural schematic covering FPGA DSP, AXI DMA, RISC-V FSM, and PAC1934 telemetry. |
| 📘 **[Full Technical Design Proposal](02_Full_Design_Proposal_AEGIS_RF.pdf)** | [35-Page Master PDF](02_Full_Design_Proposal_AEGIS_RF.pdf) | Formal 21-section technical proposal with 30 engineering tables, timing diagrams, mathematical proofs, and safety analyses. |
| 📑 **[Supporting Documentation Package](03_Supporting_Documentation_Package.pdf)** | [4-Page Companion PDF](03_Supporting_Documentation_Package.pdf) | Full criteria traceability matrix, 14-point risk register, and 3-way evaluation benchmark protocol. |
| 🔍 **[Icicle Kit Board-Document Audit](04_Icicle_Kit_Board_Document_Audit.pdf)** | [2-Page Audit PDF](04_Icicle_Kit_Board_Document_Audit.pdf) | Comprehensive pinout and peripheral validation cross-referencing all 5 official Microchip Icicle Kit schematics and manuals. |

---

## 🖼️ System Architecture Overview

```
                      POLARFIRE SoC ICICLE KIT (MPFS250T)
 ═════════════════════════════════════════════════════════════════════════════
 ┌──────────────────────────────────────────────────────────────────────────┐
 │  TIER 1: FPGA FABRIC STREAMING DSP (100.0 MHz Clock Domain)              │
 │                                                                          │
 │  Complex I/Q ──► [Input FIFO] ──► [Fixed 2048 CoreFFT] ──► [|X[k]|^2]   │
 │  (16-bit + 16-bit)  (AXI4-Stream)      (v7.1 Pipelined)     (Power Spec) │
 │                                                                   │      │
 │       ┌───────────────────────────────────────────────────────────┴──┐   │
 │       ▼                                                              ▼   │
 │  [Continuous 2048-Bin Full Scanner]                     [Candidate Window]│
 │  (Dynamic Noise Floor + Coarse Peaks)                   (256/1024/2048)  │
 │       │                                                              │   │
 │       │                                                 [Sub-Band CA-CFAR]
 │       │                                                 (Dynamic Alpha)  │
 │       │                                                              │   │
 │       ▼                                                              ▼   │
 │  [Frame Aggregator & Status] ◄── [AXI4-Lite Registers] ◄── [Moments Eng] │
 │  (live_candidates, seq_id)       (latched on sof_sync)     (Centroid/PAPR)│
 └───────┬──────────────────────────────────────▲───────────────────────────┘
         │ 64-bit CoreAXI4DMA (Ping-Pong)       │ 32-bit AXI4-Lite
         ▼                                      │ (Control & Config)
 ┌──────────────────────────────────────────────┴───────────────────────────┐
 │  TIER 2: AXI INTERCONNECT & HIGH-SPEED MEMORY                            │
 │  • 2 GB LPDDR4 Ping-Pong Buffering (Buffer A / Buffer B Circular Handoff)│
 │  • Zero-Copy Direct Memory Descriptors with Frame Completion Interrupt   │
 └───────────────────────┬──────────────────────────────────────────────────┘
                         │ Interconnect Bridge / DMA IRQ
                         ▼
 ┌──────────────────────────────────────────────────────────────────────────┐
 │  TIER 3: EMBEDDED RISC-V LINUX SUBSYSTEM (SiFive U54 Quad-Core @ 600 MHz) │
 │                                                                          │
 │  [DMA ISR / Kernel Driver] ──► [Userspace Confidence Scoring Engine]    │
 │                                             │                            │
 │      Evaluates C_det = w1*PNR + w2*Persist + w3*Margin                   │
 │                                             ▼                            │
 │                                [Anti-Flapping Hysteresis FSM]            │
 │                                (Dwell N_dwell >= 16 Frames)              │
 │                                             │                            │
 │  Mode 1 (Coarse) ◄──────────── Mode 2 (Standard) ──────────► Mode 3 (Adv)│
 │  (256 bins, sparse)            (1024 bins, nominal)        (2048 bins)   │
 └───────────────────────┬──────────────────────────────────────────────────┘
                         │ PAC1934 Power Telemetry (MSS I2C) & Gigabit Ethernet
                         ▼
 ┌──────────────────────────────────────────────────────────────────────────┐
 │  TIER 4: TELEMETRY & HUMAN-MACHINE INTERFACE                             │
 │  • Onboard Microchip PAC1934: Rail-level current/voltage on VDD, VDD25   │
 │  • Real-time HTML5 WebSocket / HTTP Dashboard (Zero external deps)       │
 └──────────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Key Technical Specifications & Latency Budget

All internal FPGA DSP streaming pipeline stages operate synchronously on the master fabric clock ($f_{\text{clk}} = 100.0\text{ MHz}$, $T_{\text{clk}} = 10.0\text{ ns}$).

$$\tau_{\text{end-to-end}} = T_{\text{pipe}} + T_{\text{dma}} + T_{\text{ctrl}} \approx 20.96\ \mu\text{s} + 20.00\ \mu\text{s} + 15.00\ \mu\text{s} = \mathbf{55.96\ \mu\text{s}} \ll \mathbf{100\ \mu\text{s}\ \text{[TARGET BOUNDARY]}}$$

| Subsystem Stage | Latency | Clock Cycles / Rate | Determinism & Architectural Function |
| :--- | :---: | :---: | :--- |
| **Streaming Sample Ingestion & FIFO** | $0.05\ \mu\text{s}$ | 5 cycles | AXI4-Stream slave FIFO with back-pressure elasticity. |
| **Fixed 2048 CoreFFT v7.1 IP** | $20.48\ \mu\text{s}$ | 2048 cycles | Pipelined streaming Radix-2/4 complex spectral transform. |
| **Pipelined Power Squaring** | $0.03\ \mu\text{s}$ | 3 cycles | 32-bit $\|X[k]\|^2 = \text{Re}^2 + \text{Im}^2$ with saturation guard. |
| **Continuous Full-Band Candidate Scan** | $0.40\ \mu\text{s}$ | 40 cycles | Peak-over-noise detector evaluating all 2048 bins continuously. |
| **Sub-Band CA-CFAR Detection** | $1.28\ \mu\text{s}$ | 128 cycles | Cell-Averaging sliding window (CUT, 8 guard, 32 ref cells). |
| **DMA Ping-Pong Transfer to LPDDR4** | $15.0\text{--}25.0\ \mu\text{s}$ | Interrupt boundary | Circular buffer descriptor handoff to shared 2 GB LPDDR4. |
| **RISC-V Confidence Controller & FSM** | $12.0\text{--}18.0\ \mu\text{s}$ | Linux userspace | Evaluates $C_{\text{det}}$ formula and updates AXI4-Lite registers. |
| **Frame Boundary Latch (`sof_sync`)** | At start of $N+1$ | Synchronous | Staged shadow registers latched at Start-of-Frame boundary. |

---

## 🧮 Mathematical Formulations

### 1. Confidence Metric Formulation ($C_{\text{det}}$)

The supervisory controller running on the SiFive U54 cluster assesses the quality and certainty of candidate spectral events:

$$C_{\text{det}} = w_1 \cdot S_{\text{PNR}} + w_2 \cdot S_{\text{persistence}} + w_3 \cdot S_{\text{margin}}$$

Where weights are normalized such that $\sum_{i=1}^3 w_i = 1.0$ (empirically calibrated to $w_1 = 0.40$, $w_2 = 0.35$, $w_3 = 0.25$):
* **Peak-to-Noise Ratio ($S_{\text{PNR}}$):** Normalizes detected carrier prominence in dB into $[0, 1]$:
  $$S_{\text{PNR}} = \text{clamp}\left(\frac{\text{PNR}_{\text{dB}} - \text{PNR}_{\min}}{\text{PNR}_{\max} - \text{PNR}_{\min}}, 0, 1\right)$$
* **Temporal Persistence ($S_{\text{persistence}}$):** Measures carrier temporal duty-cycle across a sliding window of the previous $M = 32$ observation frames:
  $$S_{\text{persistence}} = \frac{1}{M} \sum_{m=0}^{M-1} \mathbb{I}(\text{hit}_m)$$
* **Detector Margin ($S_{\text{margin}}$):** Measures the delta between candidate peak magnitude and local Cell-Averaging noise floor:
  $$S_{\text{margin}} = \text{clamp}\left(\frac{P_{\text{peak}} - T_{\text{CFAR}}}{T_{\text{CFAR}}}, 0, 1\right)$$

### 2. Cell-Averaging CFAR (CA-CFAR) Threshold

The dynamic detection threshold $T$ is calculated across leading and trailing reference cells:

$$T = \alpha \cdot P_n = \left(P_{\text{fa}}^{-1/N_{\text{ref}}} - 1\right) \cdot \left(\frac{1}{N_{\text{ref}}} \sum_{i \in \text{Ref}} X_i\right)$$

In AEGIS-RF, the threshold multiplier $\alpha = K_{\text{CFAR}}$ is dynamically scaled by the supervisory FSM via the `REG_CFAR_CONFIG` register to adjust sensitivity between quiet monitoring and high-interference tracking.

### 3. Anti-Flapping Hysteresis State Machine

To prevent rapid mode chattering under boundary conditions, mode transitions follow asymmetric threshold logic with a mandatory dwell counter:
* **Escalation (Mode 1 $\rightarrow$ Mode 2 $\rightarrow$ Mode 3):** Immediate trigger upon high-uncertainty detection ($C_{\text{det}} > \gamma_{\text{high}}$).
* **De-escalation (Mode 3 $\rightarrow$ Mode 2 $\rightarrow$ Mode 1):** Permitted only when $C_{\text{det}} < \gamma_{\text{low}}$ continuously for a dwell time $N_{\text{dwell}} \ge 16$ consecutive frames.

---

## 🎛️ FPGA Fabric Architecture & Resource Budget

The target silicon is the **Microchip PolarFire SoC MPFS250T-FCVG484E** (254,196 Logic Elements, 784 Math Blocks, 816 LSRAMs). AEGIS-RF is architected to utilize **less than 45% of total silicon primitives**, guaranteeing timing closure at $100\text{ MHz}$ and zero routing congestion:

| Subsystem Module | Logic Elements (LE) | Math Blocks (DSP) | LSRAM (20 kb) | uSRAM (64-bit) | Functional Responsibility |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **I/Q Streaming FIFO & Input Sync** | 1,850 (0.7%) | 0 (0.0%) | 4 (0.5%) | 16 (1.2%) | AXI4-Stream slave, frame synchronization, 2048-sample circular buffer. |
| **Microchip CoreFFT v7.1 IP** | 42,500 (16.7%) | 192 (24.5%) | 144 (17.6%) | 0 (0.0%) | Fixed 2048-point complex streaming Radix-2/4 pipeline with convergent rounding. |
| **Power Spectrum Engine** | 4,200 (1.7%) | 32 (4.1%) | 0 (0.0%) | 0 (0.0%) | Pipelined $\text{Re}^2 + \text{Im}^2$ squaring with 32-bit dynamic range saturation guard. |
| **Full-Band Candidate Scanner** | 8,600 (3.4%) | 16 (2.0%) | 32 (3.9%) | 64 (4.9%) | Continuous 2048-bin coarse peak detector, running noise floor estimation. |
| **Sub-Band CA-CFAR Engine** | 21,400 (8.4%) | 64 (8.2%) | 64 (7.8%) | 32 (2.5%) | Sliding window cell-averaging CFAR (CUT, 8 guard, 32 reference cells). |
| **Spectral Moments Extractor** | 11,200 (4.4%) | 48 (6.1%) | 16 (2.0%) | 16 (1.2%) | 1st to 4th-order spectral moments: Centroid, Spread, Skewness, PAPR. |
| **AXI4-Lite Register Bank** | 2,100 (0.8%) | 0 (0.0%) | 0 (0.0%) | 16 (1.2%) | Memory-mapped register bank with frame-synchronous `sof_sync` shadow latching. |
| **CoreAXI4DMA Engine & Handoff** | 4,350 (1.7%) | 0 (0.0%) | 8 (1.0%) | 32 (2.5%) | 64-bit AXI4 master DMA engine, ping-pong circular descriptor handoff. |
| **TOTAL ESTIMATED FABRIC UTILIZATION** | **96,200 (37.8%)** | **352 (44.8%)** | **268 (32.8%)** | **176 (13.6%)** | **Conservatively under 45% ceiling. Excellent routing headroom.** |
| **AVAILABLE POLARFIRE MPFS250T CAPACITY** | **254,196 (100%)** | **784 (100%)** | **816 (100%)** | **1,296 (100%)** | **Safe headroom > 55% across all silicon primitives.** |

---

## 🛠️ Memory-Mapped AXI4-Lite Register Interface

**Base Address:** `0x4000_0000` (Fabric AXI4-Lite Slave mapped to MSS address space)

All supervisory control writes are held in shadow stage registers and latched atomically into active fabric registers upon the assertion of the frame boundary signal `sof_sync`. This eliminates intra-frame pipeline corruption.

| Offset | Register Name | Access | Reset | Bitfields & Functional Description |
| :---: | :--- | :---: | :---: | :--- |
| **`0x00`** | `REG_WORKLOAD_MODE` | RW | `0x0000_0005` | `[1:0]` Workload Mode (`00`=Mode 1 Quiescent, `01`=Mode 2 Standard, `10`=Mode 3 Detailed).<br>`[2]` Fabric DSP Enable (`1`=Active, `0`=Bypass). |
| **`0x04`** | `REG_SUBBAND_START` | RW | `0x0000_0000` | `[11:0]` Sub-band starting frequency bin index ($0\text{--}2047$). |
| **`0x08`** | `REG_SUBBAND_SPAN` | RW | `0x0000_0100` | `[11:0]` Downstream detailed analysis window span ($256$, $1024$, or $2048$ bins). |
| **`0x0C`** | `REG_CFAR_CONFIG` | RW | `0x0820_0280` | `[15:0]` $K_{\text{CFAR}}$ threshold multiplier in Q8.8 fixed-point format.<br>`[23:16]` $N_{\text{ref}}$ Reference cells count (default: 32).<br>`[31:24]` $N_{\text{guard}}$ Guard cells count (default: 8). |
| **`0x10`** | `REG_FEATURE_MASK` | RW | `0x0000_0003` | `[7:0]` Feature Extractor Enable Mask:<br>Bit 0: Centroid, Bit 1: Spread, Bit 2: PAPR, Bit 3: Skewness. |
| **`0x14`** | `REG_STATUS_FLAGS` | RO | `0x0000_0000` | `[0]` DMA Buffer Overflow Flag.<br>`[1]` Frame Complete Ready Flag.<br>`[2]` Input FIFO Underflow Flag.<br>`[3]` FSM Hardware Lock Flag. |
| **`0x18`** | `REG_CANDIDATE_CNT` | RO | `0x0000_0000` | `[11:0]` Number of valid candidate carrier peaks detected in current frame. |
| **`0x1C`** | `REG_FRAME_SEQ_ID` | RO | `0x0000_0000` | `[31:0]` Monotonic 32-bit hardware frame sequence counter. |

---

## 🔬 Power Telemetry & Controlled Three-Way Benchmark

To avoid unvalidated performance assertions, AEGIS-RF enforces a strict three-way comparative benchmark on identical held-out synthetic I/Q test vectors at matched false-alarm parity ($P_{\text{fa}} = 10^{-3}$):

```
┌────────────────────────────────────────────────────────────────────────┐
│ CONFIG A: Fixed-Coarse Baseline (Static Low-Power Reference)           │
│ Fixed 2048 FFT | Static 256-bin window | Higher moments disabled       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Identical 10,000-Frame Test Traces
┌───────────────────────────────────▼────────────────────────────────────┐
│ CONFIG B: Fixed-Detailed Baseline (Static High-Fidelity Reference)     │
│ Fixed 2048 FFT | Full 2048-bin window | Full 4th-order moments active  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Matched False-Alarm Operating Point
┌───────────────────────────────────▼────────────────────────────────────┐
│ CONFIG C: AEGIS-RF Adaptive (Confidence-Aware Dynamic Allocation)       │
│ Fixed 2048 FFT | Continuous full-band scan | Multi-parameter scaling   │
└────────────────────────────────────────────────────────────────────────┘
```

### Microchip PAC1934 Multi-Rail Power Monitoring
Real-time power measurements are captured via the onboard **Microchip PAC1934** 4-channel power monitor over MSS I2C (`0x10`):
* **Channel 1 (`VDD`):** $1.0\text{ V}$ PolarFire FPGA Core Logic rail.
* **Channel 2 (`VDD25`):** $2.5\text{ V}$ Auxiliary & I/O logic rail.
* **Channel 3 (`VDDA25`):** $2.5\text{ V}$ High-precision analog PLL/transceiver rail.
* **Channel 4 (`VDDA`):** $1.8\text{ V}$ Analog circuitry supply rail.

Telemetry is logged dynamically without interfering with DSP pipelines, allowing real-time profiling of power savings across Modes 1, 2, and 3.

---

## 📂 Repository File Structure

```text
AEGIS-RF/
├── 01_System_Block_Diagram_AEGIS_RF.png       # 1536x1024 Master System Architecture (Figure 1)
├── 01_System_Block_Diagram_AEGIS_RF.pdf       # Printable Vector Architecture Schematic
├── 02_Full_Design_Proposal_AEGIS_RF.pdf       # 35-Page Master Technical Proposal (Formal Submission)
├── 03_Supporting_Documentation_Package.pdf    # Risk Register, Traceability & Evaluation Protocol
├── 04_Icicle_Kit_Board_Document_Audit.pdf     # 5-Manual Microchip Hardware Feasibility Audit
├── README.md                                  # Complete Technical Architecture & Specification
├── LICENSE                                    # Apache 2.0 Open-Source License
├── .gitignore                                 # Libero SoC, SoftConsole & OS build exclusions
│
├── constraints/                               # Microchip Libero SoC Constraints
│   ├── aegis_rf_pins.pdc                      # Icicle Kit Physical Pinout & Bank Voltages
│   ├── aegis_rf_timing.sdc                    # 100 MHz Timing Constraints & CDC False Paths
│   └── resource_budget_analysis.md            # Detailed MPFS250T Silicon Budget (37.8% LE)
│
├── dashboard/                                 # Tier 4 Real-Time Web Telemetry Visualizer
│   ├── README.md                              # Standalone Web Dashboard Guide
│   ├── telemetry_server.py                    # Standalone Python HTTP/JSON Streaming Server
│   └── static/index.html                      # HTML5 Canvas Dark-Mode Spectrum & Power GUI
│
├── rtl/                                       # Synthesizable Verilog Hardware Modules
│   ├── aegis_rf_top.v                         # Top-Level Master System Integration
│   ├── axi4_lite_shadow_registers.v           # Memory-Mapped Register Bank with sof_sync
│   ├── power_spectrum_engine.v                # Pipelined Re^2 + Im^2 Magnitude Squaring
│   └── fullband_candidate_scanner.v           # Continuous 2048-Bin Peak Detector
│
├── firmware/                                  # Embedded RISC-V Linux Supervisory Software
│   ├── inc/aegis_registers.h                  # Hardware Register Offsets & Bitfields
│   ├── inc/pac1934_telemetry.h                # PAC1934 4-Channel Power Monitor Register Map
│   └── src/confidence_controller.c            # Confidence Scoring & Anti-Flapping FSM
│
└── sim/                                       # Pre-Silicon Simulation & Verification Suite
    ├── generate_iq_testvectors.py             # Synthetic Complex I/Q Vector Generator
    ├── tb_aegis_rf_top.v                      # Verilog Testbench for Streaming Top-Level
    └── waveforms/                             # Simulation Trace Artifacts (.gitkeep)
```

---

## 🚀 Quickstart & Demonstration Guide

### 1. Run the Live Spectrum & Telemetry Visualizer

The included dashboard provides an out-of-the-box demonstration of real-time spectrum monitoring, CA-CFAR thresholding, FSM mode transitions, and PAC1934 power rail telemetry. It requires **zero external dependencies** (runs on standard Python 3):

```bash
# Navigate to the dashboard directory
cd dashboard

# Start the telemetry server (default port: 8080)
python telemetry_server.py
```

Then open your browser to:
```
http://localhost:8080
```

### 2. Generate Bit-Accurate I/Q Test Vectors

Generate synthetic multi-frame RF traces containing quiet intervals, single-carrier burst transmissions, and multi-carrier interference:

```bash
cd sim
python generate_iq_testvectors.py
```
This generates `aegis_synthetic_iq_100frames.bin` formatted as packed 32-bit signed complex words (`[31:16] = Q[15:0]`, `[15:0] = I[15:0]`).

### 3. Run Verilog RTL Simulation

Compile and simulate `tb_aegis_rf_top.v` using ModelSim / QuestaSim (bundled with Libero SoC) or Icarus Verilog:

```bash
# Example with Icarus Verilog
cd rtl
iverilog -o aegis_sim ../sim/tb_aegis_rf_top.v aegis_rf_top.v power_spectrum_engine.v fullband_candidate_scanner.v axi4_lite_shadow_registers.v
vvp aegis_sim
```

---

## 📜 References & Citations

1. **Microchip Technology Inc.**, *CoreFFT v7.1 Handbook*, Document Number DS50003058A, 2022.
2. **Microchip Technology Inc.**, *PolarFire® SoC Icicle Kit User Guide*, Document Number DS50003038B, 2023.
3. **Microchip Technology Inc.**, *PAC1934 4-Channel DC Power/Energy Monitor Data Sheet*, Document Number DS20005850E, 2021.
4. **Microchip Technology Inc.**, *PolarFire® SoC FPGA Architectural Overview*, Document Number DS00003256B, 2021.
5. **H. Rohling**, *"Radar Marker Detection by Means of CFAR Algorithms"*, IEEE Transactions on Aerospace and Electronic Systems, vol. AES-19, no. 4, pp. 608–621, 1983.
6. **SiFive Inc.**, *U54-MC Core Complex Manual*, v19.08, 2019.

---

## 📄 License

This project is licensed under the **Apache License, Version 2.0**. See the [LICENSE](LICENSE) file for details.
