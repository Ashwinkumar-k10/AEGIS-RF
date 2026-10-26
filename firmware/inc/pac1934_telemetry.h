/**
 * @file pac1934_telemetry.h
 * @brief Register Map for Microchip PAC1934 4-Channel DC Power Monitor over I2C
 * @details Icicle Kit I2C Address: 0x10 (MSS I2C-0 Bus)
 */

#ifndef PAC1934_TELEMETRY_H
#define PAC1934_TELEMETRY_H

#include <stdint.h>

#define PAC1934_I2C_ADDR            0x10

// PAC1934 Register Addresses
#define PAC1934_REFRESH             0x00
#define PAC1934_CTRL                0x01
#define PAC1934_VBUS1_AVG           0x0F  // VDD (1.0V FPGA Core Rail)
#define PAC1934_VSENSE1_AVG         0x13
#define PAC1934_VBUS2_AVG           0x10  // VDD25 (2.5V Auxiliary Rail)
#define PAC1934_VSENSE2_AVG         0x14
#define PAC1934_VBUS3_AVG           0x11  // VDDA25 (2.5V Analog Rail)
#define PAC1934_VSENSE3_AVG         0x15
#define PAC1934_VBUS4_AVG           0x12  // VDDA (3.3V Transceiver Rail)
#define PAC1934_VSENSE4_AVG         0x16

typedef struct {
    float vdd_core_mw;
    float vdd25_mw;
    float vdda25_mw;
    float vdda_mw;
    float total_monitored_mw;
    uint32_t timestamp_ms;
} pac1934_power_reading_t;

#endif // PAC1934_TELEMETRY_H
