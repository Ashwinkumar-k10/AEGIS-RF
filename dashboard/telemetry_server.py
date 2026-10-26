#!/usr/bin/env python3
"""
AEGIS-RF Real-Time Spectrum & PAC1934 Power Telemetry Server
Target: Microchip PolarFire SoC Icicle Kit (MPFS250T) / Supervisory Linux U54 Cluster
Runs on standard Python 3 (zero external dependencies required for out-of-the-box demo).

Usage:
    python dashboard/telemetry_server.py [--port 8080] [--demo]
"""

import sys
import os
import json
import math
import random
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8080
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

# Simulated state for demo mode
frame_counter = 1000
current_mode = 0  # 0: Coarse (Mode 1), 1: Standard (Mode 2), 2: Detailed (Mode 3)
mode_dwell = 0

def generate_telemetry_frame():
    global frame_counter, current_mode, mode_dwell
    frame_counter += 1
    mode_dwell += 1

    # Dynamic mode switching simulation (state machine)
    if mode_dwell > 25:
        mode_dwell = 0
        current_mode = (current_mode + 1) % 3

    mode_names = ["Mode 1: Quiescent Coarse", "Mode 2: Standard Tracking", "Mode 3: Detailed Alert"]
    mode_spans = [256, 1024, 2048]
    
    # Power telemetry per mode (PAC1934 rails)
    if current_mode == 0:
        vdd_core = 780.0 + random.uniform(-10.0, 10.0)
        conf = 0.28 + random.uniform(-0.05, 0.05)
        candidates = 0
        pnr = 4.2
    elif current_mode == 1:
        vdd_core = 950.0 + random.uniform(-15.0, 15.0)
        conf = 0.65 + random.uniform(-0.04, 0.04)
        candidates = 1
        pnr = 14.8
    else:
        vdd_core = 1260.0 + random.uniform(-20.0, 20.0)
        conf = 0.92 + random.uniform(-0.02, 0.02)
        candidates = 2
        pnr = 24.5

    vdd25 = 320.0 + random.uniform(-5.0, 5.0)
    vdda25 = 185.0 + random.uniform(-3.0, 3.0)
    vdda = 142.0 + random.uniform(-2.0, 2.0)
    total_power = vdd_core + vdd25 + vdda25 + vdda

    # Generate 256 spectrum display points representing 2048 bins
    num_display_bins = 256
    spectrum = []
    cfar = []
    base_noise = -85.0 + random.uniform(-1.0, 1.0)

    for i in range(num_display_bins):
        # Rayleigh noise floor
        noise = base_noise + random.gauss(0, 2.2)
        
        # Inject Signal 1 at bin 64 (representing bin 512 in 2048-FFT)
        dist1 = abs(i - 64)
        if dist1 < 6:
            peak = (-35.0 if current_mode > 0 else -60.0) - (dist1**2 * 1.5)
            noise = max(noise, peak)
            
        # Inject Signal 2 at bin 180 (representing agile interferer in Mode 3)
        if current_mode == 2:
            dist2 = abs(i - 180)
            if dist2 < 4:
                peak2 = -42.0 - (dist2**2 * 2.0)
                noise = max(noise, peak2)

        spectrum.append(round(noise, 2))
        cfar.append(round(base_noise + 12.0 + (3.0 if current_mode == 2 else 0.0), 2))

    return {
        "frame_id": frame_counter,
        "mode": current_mode,
        "mode_name": mode_names[current_mode],
        "analysis_span": mode_spans[current_mode],
        "confidence": round(conf, 3),
        "candidates": candidates,
        "pnr_db": round(pnr, 1),
        "pac1934": {
            "vdd_core_mw": round(vdd_core, 1),
            "vdd25_mw": round(vdd25, 1),
            "vdda25_mw": round(vdda25, 1),
            "vdda_mw": round(vdda, 1),
            "total_mw": round(total_power, 1)
        },
        "spectrum": spectrum,
        "cfar": cfar
    }

class AegisTelemetryHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/telemetry":
            data = generate_telemetry_frame()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
        else:
            super().do_GET()

def run_server():
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, AegisTelemetryHandler)
    print("=" * 70)
    print("  AEGIS-RF Spectrum Intelligence & PAC1934 Power Dashboard")
    print(f"  Target: Microchip PolarFire SoC Icicle Kit")
    print(f"  Live Web UI: http://localhost:{PORT}")
    print("=" * 70)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[AEGIS-RF] Server halted cleanly.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        PORT = int(sys.argv[1])
    run_server()
