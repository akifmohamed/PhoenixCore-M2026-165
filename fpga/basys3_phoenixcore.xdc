## =========================================================================
## File        : basys3_phoenixcore.xdc
## Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
## Team        : NEXUS V (GCE Srirangam & ACGCET Karaikudi)
## Board       : Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C)
## Description : Verified against Physical Basys3 Board Silkscreen:
##               SW0(V17)=Mode, SW1(V16)=rst_n, SW4..SW15(W15..R2)=adc_vcap_mv[11:0],
##               BTNC(U18)=Cut, BTND(U17)=Tamper, LD0..LD15, 7-Seg, UART, PMOD JA/JB/JC.
## =========================================================================

## 1. Clock Signal (Pin W5 = 100 MHz oscillator, constrained at 50 MHz / 20 ns)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk_50mhz]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports clk_50mhz]

## 2. Control Slide Switches:
##    SW0 (V17): 0 = On-Chip BRAM FRAM Emulator | 1 = External PMOD SPI FRAM
##    SW1 (V16): Active-Low Reset rst_n (UP = RUN | DOWN = RESET)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports sw_ext_fram_mode]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports rst_n]

## 3. Supercapacitor Voltage Input adc_vcap_mv[11:0] Mapped to Exact SW4..SW15 Silkscreen Pins:
##    SW15(R2)=2048mV, SW14(T1)=1024mV, SW13(U1)=512mV ... SW4(W15)=1mV
##    (Flip SW15 + SW14 UP = 3072 mV Normal; Flip SW15 DOWN = 1024 mV Brownout Trigger!)
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[0]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[1]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[2]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[3]}]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[4]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[5]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[6]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[7]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[8]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[9]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[10]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {adc_vcap_mv[11]}]

## 4. Fault-Injection Pushbuttons:
##    BTNC (U18) = Inject Mid-Save Brownout Torn-Write Cut
##    BTND (U17) = Inject Physical Tamper Attack (1-Cycle 20 ns Key Zeroization)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_inject_cut]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_inject_tamper]

## 5. Status LEDs (Exact Basys3 Silkscreen):
##    LD8..LD0   = Live Dirty Block Count led_dirty_count[8:0] (LD6 = 64 blocks!)
##    LD9  (V3)  = led_ckpt_busy (DMA Checkpoint Save Active)
##    LD10 (W3)  = led_restore_ok (89.6 us Hot-Priority Restore Verified)
##    LD11 (U3)  = led_tamper_alarm (20 ns Key Zeroization Latched)
##    LD15..LD12 = committed_gen_id[3:0] (Authoritative Checkpoint Generation)
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

## 5b. Upper Debug Bits committed_gen_id[15:4] -> PMOD JB (8 pins) & JC (4 pins) (Bank 14 LVCMOS33)
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[4]}]
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[5]}]
set_property -dict { PACKAGE_PIN B15  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[6]}]
set_property -dict { PACKAGE_PIN B16  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[7]}]
set_property -dict { PACKAGE_PIN A15  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[8]}]
set_property -dict { PACKAGE_PIN A17  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[9]}]
set_property -dict { PACKAGE_PIN C15  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[10]}]
set_property -dict { PACKAGE_PIN C16  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[11]}]
set_property -dict { PACKAGE_PIN K17  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[12]}]
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[13]}]
set_property -dict { PACKAGE_PIN N17  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[14]}]
set_property -dict { PACKAGE_PIN P18  IOSTANDARD LVCMOS33 } [get_ports {committed_gen_id[15]}]

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

## 7. USB-RS232 UART Telemetry TX (FTDI Channel B -> COM port / /dev/ttyUSB1 @ 115200 8N1)
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## 8. PMOD Header JA (External 25 MHz Wide-VDD 1.8V-3.6V SPI FRAM Fujitsu MB85RS256TY)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports spi_mosi]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports spi_miso]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports spi_sck]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]