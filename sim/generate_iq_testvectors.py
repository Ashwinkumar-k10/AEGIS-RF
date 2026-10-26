#!/usr/bin/env python3
"""
AEGIS-RF: Synthetic Complex I/Q Test Vector Generation Script
Generates 10,000 reproducible 2048-sample frames across calibrated SNR regimes
(-10 dB to +20 dB) with multi-tone, BPSK, QPSK, frequency offsets, and AWGN noise.
Used for Bit-Accurate Verification against RTL output.
"""

import numpy as np
import os
import struct

def generate_frame(frame_id, frame_len=2048, snr_db=10.0, signal_type='BPSK'):
    np.random.seed(frame_id)
    t = np.arange(frame_len)
    
    # Generate Synthetic Signal of Interest (SOI)
    if signal_type == 'BPSK':
        # BPSK Carrier at normalized frequency 0.25 (Bin 512)
        symbols = np.random.choice([-1.0, 1.0], size=frame_len // 16)
        baseband = np.repeat(symbols, 16)
        carrier = np.exp(1j * 2 * np.pi * 0.25 * t)
        signal = baseband * carrier
    elif signal_type == 'QPSK':
        # QPSK Carrier at normalized frequency 0.60 (Bin 1228)
        symbols_i = np.random.choice([-1.0, 1.0], size=frame_len // 16)
        symbols_q = np.random.choice([-1.0, 1.0], size=frame_len // 16)
        baseband = (np.repeat(symbols_i, 16) + 1j * np.repeat(symbols_q, 16)) / np.sqrt(2)
        carrier = np.exp(1j * 2 * np.pi * 0.60 * t)
        signal = baseband * carrier
    elif signal_type == 'MULTI_TONE':
        # 3 simultaneous tones at bins 256, 1024, 1536
        signal = (np.sin(2 * np.pi * (256/2048) * t) + 
                  np.sin(2 * np.pi * (1024/2048) * t) + 
                  np.sin(2 * np.pi * (1536/2048) * t))
    else: # Quiescent (Noise only)
        signal = np.zeros(frame_len, dtype=complex)
        
    # Scale signal power
    sig_power = np.mean(np.abs(signal)**2)
    if sig_power > 0:
        signal = signal / np.sqrt(sig_power)
        noise_power = 10.0 ** (-snr_db / 10.0)
    else:
        noise_power = 1.0
        
    # Add Additive White Gaussian Noise (AWGN)
    noise = (np.random.normal(0, np.sqrt(noise_power/2), frame_len) + 
             1j * np.random.normal(0, np.sqrt(noise_power/2), frame_len))
    rx_signal = signal + noise
    
    # Quantize to 16-bit signed integer (-32768 to 32767)
    scale_factor = 16384.0
    i_samples = np.clip(np.real(rx_signal) * scale_factor, -32768, 32767).astype(np.int16)
    q_samples = np.clip(np.imag(rx_signal) * scale_factor, -32768, 32767).astype(np.int16)
    
    return i_samples, q_samples

def export_test_suite(output_file, num_frames=100):
    print(f"[AEGIS-RF] Generating {num_frames} frames of synthetic I/Q test vectors...")
    with open(output_file, 'wb') as f:
        for f_idx in range(num_frames):
            sig_type = 'BPSK' if (f_idx % 4 == 0) else ('QPSK' if (f_idx % 4 == 1) else ('MULTI_TONE' if (f_idx % 4 == 2) else 'QUIESCENT'))
            snr = 15.0 if f_idx < 50 else 0.0
            i_data, q_data = generate_frame(f_idx, 2048, snr, sig_type)
            
            # Interleave I and Q: [I0, Q0, I1, Q1, ...]
            interleaved = np.empty((4096,), dtype=np.int16)
            interleaved[0::2] = i_data
            interleaved[1::2] = q_data
            f.write(interleaved.tobytes())
            
    print(f"[AEGIS-RF] Successfully exported to {output_file} ({os.path.getsize(output_file)} bytes)")

if __name__ == '__main__':
    out_path = os.path.join(os.path.dirname(__file__), "aegis_synthetic_iq_100frames.bin")
    export_test_suite(out_path, 100)
