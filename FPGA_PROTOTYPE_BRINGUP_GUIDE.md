# PhoenixCore (M2026-165) — Complete Digilent Basys3 FPGA Prototype & Lab Bring-Up Guide

**Team Name:** NEXUS V | **Team ID:** `M2026-165`  
**Target FPGA Board:** Digilent Basys3 (Xilinx Artix-7 `XC7A35T-1CPG236C`)  
**Target PMOD Daughterboard:** TI `BQ25570` Harvester + Swappable `100 µF` / `55 µF` Buffer Cap + Wide-$V_{DD}$ Fujitsu `MB85RS256TY` (`1.8 V – 3.6 V`, `32 KB` SPI FRAM)

## 1. Quick-Start Summary (Two Operating Modes on Digilent Basys3)

PhoenixCore supports **two hardware operating modes** selectable in real time via slide switch **`SW0` (Pin `V17`)** on the Digilent Basys3 board:

| Mode | Switch `SW0` (`Pin V17`) | Non-Volatile Memory Target | Required Hardware in GCE Srirangam Lab |
| :--- | :--- | :--- | :--- |
| **Mode 0: On-Chip BRAM Loopback Mode** *(Instant Single-Cable Demo)* | `SW0 = 0` *(Down)* | On-chip `32 KB` dual-port Block RAM (`12 × RAMB36E1`) inside the Artix-7 FPGA emulating cycle-accurate SPI FRAM | **Only the Digilent Basys3 board + 1 Micro-USB cable** connected to your Ubuntu laptop |
| **Mode 1: External PMOD SPI FRAM Mode** *(Full Harvester + FRAM Bench)* | `SW0 = 1` *(Up)* | External wide-$V_{DD}$ **Fujitsu `MB85RS256TY`** (`1.8 V – 3.6 V`, `32 KB` SPI FRAM) wired to **PMOD Header `JA`** | Digilent Basys3 + `MB85RS256TY` SPI FRAM + `BQ25570` Harvester + `100 µF` / `55 µF` capacitors |

## 2. Exact Pinout Mapping Table (`basys3_phoenixcore.xdc` $\leftrightarrow$ `phoenixcore_top.v`)

Every top-level signal in `phoenixcore_top.v` is locked to its physical package pin on the **Artix-7 `XC7A35T-1CPG236C`** in `basys3_phoenixcore.xdc`:

| RTL Port Name (`phoenixcore_top.v`) | Direction | Basys3 Package Pin | Basys3 On-Board Peripheral | Functional Role During Hardware Demo |
| :--- | :--- | :--- | :--- | :--- |
| `clk_50mhz` | `input` | `W5` | 100 MHz Crystal Oscillator | System clock input (constrained at 50 MHz / `20.0 ns`) |
| `rst_n` | `input` | `T18` | Pushbutton `BTNU` *(Up)* | Active-low system reset |
| `btn_inject_cut` | `input` | `U18` | Pushbutton `BTNC` *(Center)* | **Test 3 Trigger:** Injects sudden mid-save brownout power cut |
| `btn_inject_tamper` | `input` | `U17` | Pushbutton `BTND` *(Down)* | **Test 4 Trigger:** Injects physical tamper / rollback attack (`20 ns` key wipe) |
| `sw_ext_fram_mode` | `input` | `V17` | Slide Switch `SW0` | `0` = On-Chip BRAM Loopback Mode; `1` = External PMOD `JA` SPI FRAM Mode |
| `adc_vcap_mv[11:0]` | `input` | `T1, U1, W2, R3, T2, T3, V2, W13, W14, V15, W15, W17` | Slide Switches `SW15..SW4` | Sets live capacitor voltage $V_{\text{cap}}$ in `mV` (e.g., `3300 mV` normal $\rightarrow$ `1830 mV` trigger) |
| `led_dirty_count[8:0]` | `output` | `V13, V14, U14, U15, W18, V19, U19, E19, U16` | LEDs `LD8..LD0` | Displays live dirty block count `N_dirty` in binary (`0_0010_0001` = `0x021` = **`33` blocks**) |
| `led_ckpt_busy` | `output` | `V3` | Green LED `LD9` | Pulses **ON (`1`)** during DMA Pre-Crypto Zero-Word Masking & FRAM save |
| `led_restore_ok` | `output` | `W3` | Green LED `LD10` | Lights **ON (`1`)** when `89.6 µs` Hot-Priority Restore completes with valid MAC |
| `led_tamper_alarm` | `output` | `U3` | Red Alert LED `LD11` | Latches **ON (`1`)** within `1 clock cycle (20 ns)` when tamper zeroes AES-128 keys |
| `committed_gen_id[3:0]` | `output` | `L1, P1, N3, P3` | LEDs `LD15..LD12` | Shows authoritative committed generation ID (`Gen_ID[3:0]`, e.g., `0001` = Gen 1) |
| `seg[6:0]` & `an[3:0]` | `output` | `W7..U7` & `U2..W4` | 4-Digit 7-Segment Display | **Left 2 digits (`AN3..AN2`):** Dirty Blocks `N_dirty` (`21` hex = `33`); **Right 2 digits (`AN1..AN0`):** `Gen_ID` (`01`) |
| `spi_cs_n` | `output` | `J1` | PMOD Header `JA1` | SPI Chip Select (`/CS`) to Fujitsu `MB85RS256TY` Pin 1 |
| `spi_mosi` | `output` | `L2` | PMOD Header `JA2` | SPI Master-Out Slave-In (`SI`) to Fujitsu `MB85RS256TY` Pin 5 |
| `spi_miso` | `input` | `J2` | PMOD Header `JA3` | SPI Master-In Slave-Out (`SO`) from Fujitsu `MB85RS256TY` Pin 2 |
| `spi_sck` | `output` | `G2` | PMOD Header `JA4` | `25 MHz` SPI Serial Clock (`SCK`) to Fujitsu `MB85RS256TY` Pin 6 |
| `uart_tx` | `output` | `A18` | FTDI USB-UART Bridge (`TX`) | Streams live telemetry frames to `/dev/ttyUSB1` at `115200 8N1` |

## 3. Exact 4-Step Physical Hardware Demo Sequence (60 Seconds for Video Recording)

Once `phoenixcore_top.bit` is loaded onto the Digilent Basys3 board and `python3 sim/uart_dashboard.py --port /dev/ttyUSB1` is running on your laptop screen:

1. **Test 1 — Normal RV32I Execution & 0-Cycle Dirty Block Snoop (`0:00 – 0:15`)**:
   * Set `SW0 = 0` (BRAM Loopback Mode) and switches `SW15..SW4` to `3,300 mV` (`0xCE4`).
   * **What to show on camera:** Point to `LD8..LD0` (`led_dirty_count[8:0] = 0x021` = **`33` dirty blocks**) and the 4-digit 7-segment display showing **`21 00`**.
2. **Test 2 — Word-Masked Checkpoint Save & $+25\text{ mV}$ Aging Calibration (`0:15 – 0:30`)**:
   * Flip `SW15` down so $V_{\text{cap}}$ drops below $V_{\text{trig}} = 1,864\text{ mV}$.
   * **What to show on camera:** `LD9` (`led_ckpt_busy`) flashes high as Pre-Crypto Zero-Word Masking (`PC-WMC`) saves only non-zero words, `LD15..LD12` (`committed_gen_id[3:0]`) increments to **`0001`** (`Gen_ID = 1`), and `LD8..LD0` clears to `0x000`.
3. **Test 3 — Mid-Save Torn-Write Power Cut & $89.6\text{ µs}$ Hot-Priority Restore (`0:30 – 0:45`)**:
   * Press center button **`BTNC` (`btn_inject_cut`, Pin `U18`)** mid-save during Generation 2, then release `BTNC` and restore `SW15 = 1` ($V_{\text{cap}} = 3,300\text{ mV}$).
   * **What to show on camera:** The uncommitted Generation 2 torn write is safely discarded, `LD15..LD12` stays at **`0001`** (Generation 1 intact), and green LED **`LD10` (`led_restore_ok`, Pin `W3`)** lights up **ON (`1`)** confirming $89.6\text{ µs}$ 2-Block Hot-Priority Restore!
4. **Test 4 — 1-Cycle (`20 ns`) Physical Tamper Key Zeroization (`0:45 – 1:00`)**:
   * Press down button **`BTND` (`btn_inject_tamper`, Pin `U17`)**.
   * **What to show on camera:** Red LED **`LD11` (`led_tamper_alarm`, Pin `U3`)** latches **ON (`1`)** instantly as all active AES-128 key flip-flops zeroize to `0x0` in a single `20 ns` clock tick.
