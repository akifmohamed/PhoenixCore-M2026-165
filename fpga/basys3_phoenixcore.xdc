## =========================================================================
## File        : basys3_phoenixcore.xdc
## Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
## Team        : NEXUS V (GCE Srirangam & ACGCET Karaikudi)
## Board       : Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C)
## Description : Complete Physical Pin, Clock (50 MHz), Switch, Pushbutton,
##               LED, 7-Segment, USB-UART, and PMOD JA (MB85RS256TY SPI FRAM)
##               Constraints Matching 100% of phoenixcore_top.v Top-Level Ports.
## =========================================================================

## 1. Clock Signal (50 MHz timing constraint on Basys3 W5 clock pin)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk_50mhz]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports clk_50mhz]

## 2. Slide Switch SW0 (0 = On-Chip BRAM FRAM Emulator, 1 = External PMOD SPI FRAM)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports sw_ext_fram_mode]

## 3. Supercapacitor Voltage Input Bits adc_vcap_mv[11:0] (Mapped to Switches SW4..SW15)
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[0]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[1]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[2]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[3]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[4]}]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[5]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[6]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[7]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[8]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[9]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[10]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[11]}]

## 4. Push Buttons (BTNU = Active-Low Reset, BTNC = Brownout Cut Inject, BTND = Tamper Inject)
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports rst_n]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_inject_cut]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_inject_tamper]

## 5. Status LEDs: LD8..LD0 = Live Dirty Block Count (led_dirty_count[8:0]),
##    LD9 = led_ckpt_busy, LD10 = led_restore_ok, LD11 = led_tamper_alarm,
##    LD15..LD12 = committed_gen_id[3:0]
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led_dirty_count[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports led_ckpt_busy]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports led_restore_ok]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports led_tamper_alarm]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[0]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[1]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[2]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[3]}]

## 6. 4-Digit 7-Segment Display (an[3:0] and seg[6:0])
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## 7. USB-RS232 UART Telemetry TX (FTDI Channel B -> /dev/ttyUSB1 @ 115200 8N1)
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## 8. PMOD Header JA (External 25 MHz Wide-VDD 1.8V-3.6V SPI FRAM Fujitsu MB85RS256TY)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports spi_mosi]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports spi_miso]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports spi_sck]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
