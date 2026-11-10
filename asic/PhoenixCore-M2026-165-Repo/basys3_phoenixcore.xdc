## =============================================================================
## File        : basys3_phoenixcore.xdc
## Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
## Board       : Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C)
## =============================================================================

## Clock Signal (50 MHz constraint on Basys3 W5 clock pin)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk_50mhz]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports clk_50mhz]

## Slide Switch SW0 (0 = On-Chip BRAM FRAM Emulator, 1 = External PMOD SPI FRAM)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports sw_ext_fram_mode]

## Simulated / XADC Supercapacitor Voltage Input Bits (Mapped to Switches SW4..SW15 for Lab Testing)
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

## Push Buttons (btnU = Active-Low Reset, btnC = Brownout Cut Inject, btnD = Tamper Inject)
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports rst_n]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_inject_cut]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_inject_tamper]

## LEDs [8:0] = Live Dirty Block Count (N_dirty), LED9 = Busy, LED10 = Restore OK, LED11 = Tamper Alarm
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

## PMOD Header JA (External 25 MHz SPI FRAM MB85RS256B / FM25V02A)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports spi_mosi]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports spi_miso]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports spi_sck]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
