# AEGIS-RF

### Confidence-Aware, Resource-Adaptive RF Spectrum Intelligence on PolarFire SoC

[![Microchip PolarFire SoC](https://img.shields.io/badge/Platform-Microchip%20PolarFire%20SoC%20(MPFS250T)-002D62.svg)](https://www.microchip.com/en-us/products/fpgas-and-plds/system-on-chip-fpgas/polarfire-soc-fpgas)
[![Contest Track](https://img.shields.io/badge/Contest-Microchip%20FPGA%20Design%20Contest%202026%20|%20Track%202-E31B23.svg)](https://www.microchip.com)
[![FPGA Fabric Clock](https://img.shields.io/badge/Fabric%20DSP-100%20MHz%20Continuous%20Streaming-4CAF50.svg)](#1-hardware-streaming-dsp-fast-loop)
[![Full-Band Scan](https://img.shields.io/badge/Full--Band%20Scan-2048--Point%20Fixed%20CoreFFT-00BCD4.svg)](#key-technical-specifications--latency-budget)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

**Target Platform:** Microchip PolarFire® SoC Icicle Kit (`MPFS250T-FCVG484E`)  
**Design Environment:** Microchip Libero® SoC v2024.1 | SoftConsole v2022.2 | Linux BSP  
**Track:** Track 2 — Connected Real-Time Systems Using PolarFire SoC Icicle Kit  

---

## 📑 Core Technical Deliverables (One-Click Access)

| Document | Format | Description |
| :--- | :--- | :--- |
| 📊 **[System Architecture Block Diagram](01_System_Block_Diagram_AEGIS_RF.png)** | [High-Res PNG](01_System_Block_Diagram_AEGIS_RF.png) \| [PDF](01_System_Block_Diagram_AEGIS_RF.pdf) | Complete 4-tier master schematic: Fast Loop FPGA DSP, LPDDR4 Ping-Pong DMA, RISC-V Linux FSM, and PAC1934 telemetry. |
| 📘 **[Full Technical Design Proposal](02_Full_Design_Proposal_AEGIS_RF.pdf)** | [35-Page Master PDF](02_Full_Design_Proposal_AEGIS_RF.pdf) | Complete formal proposal with all 21 sections, 30 engineering tables, register maps, and mathematical proofs. |
| 📑 **[Supporting Documentation Package](03_Supporting_Documentation_Package.pdf)** | [4-Page Companion PDF](03_Supporting_Documentation_Package.pdf) | Criteria traceability matrix, 14-point technical risk register, and 3-way evaluation measurement protocol. |
| 🔍 **[Icicle Kit Board-Document Audit](04_Icicle_Kit_Board_Document_Audit.pdf)** | [2-Page Audit PDF](04_Icicle_Kit_Board_Document_Audit.pdf) | Hardware feasibility audit cross-referencing all 5 official Microchip board manuals and schematics. |

---

## 🖼️ System Architecture Schematic

![AEGIS-RF Master System Architecture](01_System_Block_Diagram_AEGIS_RF.png)

---

## 🎯 Executive Abstract

Modern edge radio frequency (RF) spectrum monitoring operates under volatile conditions: fluctuating channel occupancy, intermittent burst transmissions, non-stationary noise floors, unknown signal-to-noise ratios (SNR), and agile interference. Conventional edge receivers rely on static digital signal processing (DSP) pipelines configured permanently for worst-case high resolution. This architectural rigidity incurs substantial, continuous computational overhead and energy dissipation during quiet spectral intervals, while fixed low-complexity architectures risk missing transient, weak, or narrow-band signals in congested bands.

**AEGIS-RF** shifts spectrum monitoring from static pipelines to an uncertainty-driven, closed-loop heterogeneous architecture. Rather than relying on rigid fixed parameters or high-risk Dynamic Partial Reconfiguration (DPR), AEGIS-RF integrates standard building blocks with an innovative **Confidence-Aware Adaptive Processing Controller** running on embedded RISC-V Linux. The continuous 2048-bin full-band candidate scan remains active in all modes, while the controller dynamically scales the extent of downstream candidate analysis (proposed 256/1024/2048-bin windows), detection threshold multipliers ($K_{CFAR}$), and reporting cadence via AXI-Lite registers at frame boundaries. Workload escalates during ambiguous events and downscales during quiescent periods, while detection probability and false-alarm rates are explicitly tracked to preserve detection fidelity.

---

## ⚡ Key Technical Specifications & Latency Budget

All internal FPGA DSP streaming decisions operate on the master fabric clock ($f_{\text{clk}} = 100.0\ \text{MHz}$, $T_{\text{clk}} = 10.0\ \text{ns}$).

$$\tau_{\text{end-to-end}} = T_{\text{pipe}} + T_{\text{dma}} + T_{\text{ctrl}} \approx 20.96\ \mu\text{s} + 20.00\ \mu\text{s} + 15.00\ \mu\text{s} = \mathbf{55.96\ \mu\text{s}} \ll \mathbf{100\ \mu\text{s\ [TARGET]}}$$

| Subsystem Stage | Latency ($\mu\text{s}$) | Clocks / Interval | Determinism & Description |
| :--- | :---: | :---: | :--- |
| **Streaming Sample Ingestion & FIFO** | $0.05\ \mu\text{s}$ | 5 cycles | AXI4-Stream slave input FIFO with back-pressure handling. |
| **Fixed 2048 CoreFFT v7.1 IP** | $20.48\ \mu\text{s}$ | 2048 cycles | Pipelined streaming Radix-2/4 complex spectral transform. |
| **Pipelined Power Squaring** | $0.03\ \mu\text{s}$ | 3 cycles | 32-bit $|X[k]|^2 = \text{Re}^2 + \text{Im}^2$ with saturation guard. |
| **Continuous Full-Band Candidate Scan** | $0.40\ \mu\text{s}$ | 40 cycles | Peak-over-noise detector evaluating all 2048 bins continuously. |
| **Sub-Band CA-CFAR Detection** | $1.28\ \mu\text{s}$ | 128 cycles | Cell-Averaging sliding window with guard and reference cells. |
| **DMA Ping-Pong Transfer to LPDDR4** | $15.0\text{--}25.0\ \mu\text{s}$ | Buffer interrupt | Circular descriptor handoff to shared 2 GB LPDDR4 memory. |
| **RISC-V Confidence Controller & FSM** | $12.0\text{--}18.0\ \mu\text{s}$ | Linux userspace | Evaluates $C_{\text{det}}$ formula and updates AXI-Lite registers. |
| **Frame Boundary Latch (`sof_sync`)** | At start of $N+1$ | Synchronous | Staged shadow registers latched at Start-of-Frame boundary. |

---

## 🧠 Confidence Metric Mathematical Formulation

The supervisory controller running on the SiFive U54 cluster evaluates candidate event quality across multiple observation frames:

$$C_{\text{det}} = w_1 \cdot S_{\text{PNR}} + w_2 \cdot S_{\text{persistence}} + w_3 \cdot S_{\text{margin}}$$

Where weights are bounded such that $\sum w_i = 1.0$ (calibrated as $w_1 = 0.40$, $w_2 = 0.35$, $w_3 = 0.25$):
* **Peak-to-Noise Ratio ($S_{\text{PNR}}$):** Normalizes detected carrier prominence in dB to $[0, 1]$.
* **Temporal Persistence ($S_{\text{persistence}}$):** Measures carrier duty-cycle stability across the previous 32 observation frames.
* **Detector Margin ($S_{\text{margin}}$):** Measures the delta between the candidate peak and the local CFAR noise estimation floor.

Anti-flapping hysteresis is enforced via a mandatory dwell-time parameter ($N_r \ge 16$ frames) before de-escalation from Mode 3 $\rightarrow$ Mode 2 $\rightarrow$ Mode 1 can occur.

---

## 🛠️ Memory-Mapped AXI-Lite Register Interface (Base: `0x4000_0000`)

| Offset | Register Name | Access | Bitfields & Operational Description |
| :---: | :--- | :---: | :--- |
| **`0x00`** | `REG_WORKLOAD_MODE` | RW | `[1:0]` Workload Mode (`00`=Coarse, `01`=Standard, `10`=Detailed), `[2]` Fabric DSP Enable. |
| **`0x04`** | `REG_SUBBAND_START` | RW | `[11:0]` Sub-band starting frequency bin index ($0\text{--}2047$). |
| **`0x08`** | `REG_SUBBAND_SPAN` | RW | `[11:0]` Downstream analysis window span ($256$, $1024$, $2048$ bins). |
| **`0x0C`** | `REG_CFAR_CONFIG` | RW | `[15:0]` $K_{\text{CFAR}}$ threshold multiplier (Q8.8), `[23:16]` $N_{\text{ref}}$, `[31:24]` $N_{\text{guard}}$. |
| **`0x10`** | `REG_FEATURE_MASK` | RW | `[7:0]` Feature Mask: Bit 0=Centroid, 1=Spread, 2=PAPR, 3=Skewness. |
| **`0x14`** | `REG_STATUS_FLAGS` | RO | `[0]` DMA Buffer Overflow, `[1]` Frame Ready, `[2]` Underflow, `[3]` FSM Lock. |
| **`0x18`** | `REG_CANDIDATE_CNT` | RO | `[11:0]` Number of valid candidate peaks detected in current frame. |
| **`0x1C`** | `REG_FRAME_SEQ_ID` | RO | `[31:0]` Monotonic 32-bit hardware frame sequence counter. |

---

## 🔬 Controlled Three-Way Benchmark Strategy

To eliminate unverified claims, AEGIS-RF enforces a strict three-way comparative benchmark on identical held-out complex I/Q test vectors at matched false-alarm parity ($P_{fa} = 10^{-3}$):

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

Real-time power savings are logged across physical rails (`VDD` 1.0V Core, `VDD25`, `VDDA25`, `VDDA`) via the onboard **Microchip PAC1934** 4-channel power monitor over MSS I2C.

---

## 📂 Repository Structure

```text
AEGIS-RF/
├── 01_System_Block_Diagram_AEGIS_RF.png       # 1536x1024 Master Schematic (Figure 1)
├── 01_System_Block_Diagram_AEGIS_RF.pdf       # Printable Vector Schematic
├── 02_Full_Design_Proposal_AEGIS_RF.pdf       # 35-Page Master Technical Proposal
├── 03_Supporting_Documentation_Package.pdf    # Risk Register & Verification Plan
├── 04_Icicle_Kit_Board_Document_Audit.pdf     # 5-Manual Microchip Hardware Audit
│
├── constraints/                               # Libero SoC SDC & Physical PDC Constraints
│   ├── aegis_rf_pins.pdc                      # Icicle Kit Pinout & Bank Allocations
│   ├── aegis_rf_timing.sdc                    # 100 MHz Timing Constraints & CDC False Paths
│   └── resource_budget_analysis.md            # Detailed MPFS250T Silicon Budget (37.8% LE)
│
├── dashboard/                                 # Real-Time Telemetry & Spectrum UI
│   ├── README.md                              # Dashboard Deployment Guide
│   ├── telemetry_server.py                    # Zero-Dependency Python Streaming Server
│   └── static/index.html                      # HTML5 Canvas Dark-Mode Spectrum GUI
│
├── rtl/                                       # Modular Verilog RTL Implementation
│   ├── aegis_rf_top.v                         # Top-Level Hardware Integration
│   ├── axi4_lite_shadow_registers.v           # Memory-Mapped Shadow Register Bank
│   ├── power_spectrum_engine.v                # Pipelined Re^2 + Im^2 Magnitude Squaring
│   └── fullband_candidate_scanner.v           # Continuous 2048-Bin Peak Detector
│
├── firmware/                                  # Hardened RISC-V Linux Supervisory Code
│   ├── inc/aegis_registers.h                  # C Register Header (Matching Table 8)
│   ├── inc/pac1934_telemetry.h                # PAC1934 Power Monitor I2C Register Map
│   └── src/confidence_controller.c            # Confidence Scoring & Hysteresis FSM
│
└── sim/                                       # Bit-Accurate Verification Suite
    ├── generate_iq_testvectors.py             # Synthetic Complex I/Q Generator
    └── tb_aegis_rf_top.v                      # RTL Simulation Testbench
```

---

## 📜 References

1. **Microchip Technology Inc.**, *CoreFFT v7.1 Handbook*, DS50003058A, 2022.
2. **Microchip Technology Inc.**, *PolarFire® SoC Icicle Kit User Guide*, DS50003038B, 2023.
3. **Microchip Technology Inc.**, *PAC1934 4-Channel DC Power/Energy Monitor Data Sheet*, DS20005850E, 2021.
4. **H. Rohling**, *"Radar Marker Detection by Means of CFAR Algorithms"*, IEEE Trans. Aerosp. Electron. Syst., vol. AES-19, no. 4, pp. 608–621, 1983.
5. **Microchip Technology Inc.**, *PolarFire® SoC FPGA Architectural Overview*, DS00003256B, 2021.
