# AEGIS-RF: Real-Time Spectrum & Telemetry Web Dashboard

This directory provides a lightweight, zero-dependency browser-based telemetry server and dashboard for the **AEGIS-RF** system on the Microchip PolarFire SoC Icicle Kit.

## Architecture

- **Backend (`telemetry_server.py`):** Standalone Python 3 HTTP server (`http.server`) exposing an `/api/telemetry` JSON endpoint. Interacts with the RISC-V Linux supervisory FSM via shared memory / UIO driver, and queries the PAC1934 4-channel power monitor over I2C. Includes a built-in synthetic generator for out-of-the-box demonstration.
- **Frontend (`static/index.html`):** Dark-mode HTML5 Canvas spectrum visualizer rendering the 2048-bin power spectrum, sliding CA-CFAR dynamic threshold line, live FSM mode status, confidence score ($C_{\text{det}}$), and real-time physical power rails (`VDD`, `VDD25`, `VDDA25`, `VDDA`).

## Quick Start (Demo Mode)

Run the server with any standard Python 3 installation:

```bash
cd dashboard
python telemetry_server.py
```

Then open your browser to:
```
http://localhost:8080
```

## Icicle Kit Production Deployment

On the physical PolarFire SoC Icicle Kit running Linux BSP:
```bash
python3 /opt/aegis-rf/dashboard/telemetry_server.py 80
```
Then navigate to the Icicle Kit's Gigabit Ethernet IP address (`http://192.168.1.xxx`) from any connected workstation.
