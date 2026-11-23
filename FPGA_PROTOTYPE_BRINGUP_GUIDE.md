# PhoenixCore (M2026-165) — Complete Digilent Basys3 FPGA Prototype & Lab Bring-Up Guide

**Team Name:** NEXUS V | **Team ID:** `M2026-165`  
**Target FPGA Board:** Digilent Basys3 (Xilinx Artix-7 `XC7A35T-1CPG236C`)  
**Target PMOD Daughterboard (Phase 4 / Round-03 PCB):** TI `BQ25570` Harvester + Swappable `100 µF` / `55 µF` Buffer Cap + Wide-$V_{DD}$ Fujitsu `MB85RS256TY` (`1.8 V – 3.6 V`, `32 KB` SPI FRAM)

## 1. Quick-Start Summary (Two Operating Modes on Digilent Basys3)

PhoenixCore supports **two hardware operating modes** selectable in real time via slide switch **`SW0` (Pin `V17`)** on the Digilent Basys3 board:

| Mode | Switch `SW0` (`Pin V17`) | Non-Volatile Memory Target | Required Hardware |
| :--- | :--- | :--- | :--- |
| **Mode 0: On-Chip BRAM Loopback Mode** *(Instant Single-Cable Demo)* | `SW0 = 0` *(Down)* | On-chip `32 KB` dual-port Block RAM (`12 × RAMB36E1`) inside the Artix-7 FPGA emulating cycle-accurate SPI FRAM | **Only the Digilent Basys3 board + 1 Micro-USB cable** (boots permanently from `S25FL128S` QSPI Flash when `JP1 = QSPI`) |
| **Mode 1: External PMOD SPI FRAM Mode** *(Full Harvester + FRAM Bench)* | `SW0 = 1` *(Up)* | External wide-$V_{DD}$ **Fujitsu `MB85RS256TY`** (`1.8 V – 3.6 V`, `32 KB` SPI FRAM) wired to **PMOD Header `JA`** | Digilent Basys3 + `MB85RS256TY` SPI FRAM + `BQ25570` Harvester + `100 µF` / `55 µF` capacitors |

## 2. Exact Pinout Mapping Table (`basys3_phoenixcore.xdc` $\leftrightarrow$ `phoenixcore_top.v`)

Every top-level signal in `phoenixcore_top.v` is locked to its physical package pin on the **Artix-7 `XC7A35T-1CPG236C`** in `basys3_phoenixcore.xdc`:

| RTL Port Name (`phoenixcore_top.v`) | Direction | Basys3 Package Pin | Basys3 On-Board Peripheral | Functional Role During Hardware Demo |
| :--- | :--- | :--- | :--- | :--- |
| `clk_50mhz` | `input` | `W5` | 100 MHz Crystal Oscillator | System clock input (physical 100 MHz oscillator constrained at `20.0 ns` / 50 MHz in `basys3_phoenixcore.xdc`; `WNS = +8.625 ns`, critical path `~11.375 ns`) |
| `rst_n` | `input` | `V16` | Slide Switch `SW1` | Active-low system reset (`UP = RUN`, `DOWN = RESET`) |
| `btn_inject_cut` | `input` | `U18` | Pushbutton `BTNC` *(Center)* | **Test 3 Trigger:** Injects sudden mid-save brownout power cut |
| `btn_inject_tamper` | `input` | `U17` | Pushbutton `BTND` *(Down)* | **Test 4 Trigger:** Injects physical tamper / rollback attack (1-cycle `aes_master_key` zeroization + CPU halt) |
| `sw_ext_fram_mode` | `input` | `V17` | Slide Switch `SW0` | `0` = On-Chip BRAM Loopback Mode; `1` = External PMOD `JA` SPI FRAM Mode |
| `adc_vcap_mv[11:0]` | `input` | `R2, T1, U1, W2, R3, T2, T3, V2, W13, W14, V15, W15` | Slide Switches `SW15..SW4` | Sets live capacitor voltage $V_{\text{cap}}$ in `mV` (`SW15 + SW14 UP = 3,072 mV` normal; `SW15 DOWN = 1,024 mV` brownout trigger) |
| `led_dirty_count[8:0]` | `output` | `V13, V14, U14, U15, W18, V19, U19, E19, U16` | LEDs `LD8..LD0` | Displays live dirty block count `N_dirty` in binary (`0_0100_0000` = `0x040` = **`64` blocks**, `LD6` ON) |
| `led_ckpt_busy` | `output` | `V3` | Green LED `LD9` | Pulses **ON (`1`)** during DMA Pre-Crypto Zero-Word Masking & FRAM save |
| `led_restore_ok` | `output` | `W3` | Green LED `LD10` | Lights **ON (`1`)** when `89.6 µs` Hot-Priority Restore completes with valid MAC |
| `led_tamper_alarm` | `output` | `U3` | Red Alert LED `LD11` | Latches **ON (`1`)** in 1 clock cycle when tamper zeroes the 128-bit `aes_master_key` and halts the CPU |
| `committed_gen_id[3:0]` | `output` | `L1, P1, N3, P3` | LEDs `LD15..LD12` | Shows authoritative committed generation ID (`Gen_ID[3:0]`, e.g., `0001` = Gen 1; upper bits `[15:4]` routed to PMOD `JB`/`JC`) |
| `seg[6:0]` & `an[3:0]` | `output` | `W7..U7` & `U2..W4` | 4-Digit 7-Segment Display | **Left 2 digits (`AN3..AN2`):** Dirty Blocks `N_dirty` (`40` hex = `64`); **Right 2 digits (`AN1..AN0`):** `Gen_ID` (`00`, `01`, `02`) |
| `spi_cs_n` | `output` | `J1` | PMOD Header `JA1` | SPI Chip Select (`/CS`) to Fujitsu `MB85RS256TY` Pin 1 |
| `spi_mosi` | `output` | `L2` | PMOD Header `JA2` | SPI Master-Out Slave-In (`SI`) to Fujitsu `MB85RS256TY` Pin 5 |
| `spi_miso` | `input` | `J2` | PMOD Header `JA3` | SPI Master-In Slave-Out (`SO`) from Fujitsu `MB85RS256TY` Pin 2 |
| `spi_sck` | `output` | `G2` | PMOD Header `JA4` | `25 MHz` SPI Serial Clock (`SCK`) to Fujitsu `MB85RS256TY` Pin 6 |
| `uart_tx` | `output` | `A18` | FTDI USB-UART Bridge (`TX`) | Streams live telemetry frames to COM port / `/dev/ttyUSB1` at `115200 8N1` |

## 3. Exact 4-Step Physical Hardware Demo Sequence (Live QSPI Flash Boot)

Once the Basys3 board powers on (`JP1 = QSPI`, booted from `S25FL128S` Flash) and `python3 sim/uart_dashboard.py --port /dev/ttyUSB1` is running:

1. **Test 1 — Normal RV32I Execution & 0-Cycle Dirty Block Snoop**:
   * Set `SW0 = 0` (BRAM Loopback Mode), `SW1 = 1` (`rst_n` = RUN), and `SW15 + SW14` UP (`3,072 mV` normal supply).
   * **Expected Board State:** `LD6` glows (`led_dirty_count[8:0] = 0x040` = **`64` dirty blocks**) and the 4-digit 7-segment display shows **`4000`**.
2. **Test 2 — Word-Masked Checkpoint Save (`Gen 1`)**:
   * Flip `SW15` DOWN ($V_{\text{cap}} = 1,024\text{ mV} < V_{\text{trig}}$).
   * **Expected Board State:** `LD9` (`led_ckpt_busy`) pulses during save, `LD12` (`committed_gen_id[0]`) turns **ON** (`Gen_ID = 1`), `LD6` clears, and the 7-segment display locks at **`0001`**.
3. **Test 3 — Power Return & `89.6 µs` Hot-Priority Restore**:
   * Flip `SW15` back UP ($V_{\text{cap}} = 3,072\text{ mV}$; optional `BTNC` injects a mid-save torn write before power returns).
   * **Expected Board State:** Green LED **`LD10` (`led_restore_ok`, Pin `W3`)** lights **ON (`1`)** confirming `89.6 µs` Hot-Priority Restore with valid MAC, `LD12` remains **ON** (`Gen 1` intact), `LD6` resumes, and the 7-segment display shows **`4001`**.
4. **Test 4 — 1-Cycle Physical Tamper Key Zeroization & CPU Lockdown**:
   * Press **`BTND` (`btn_inject_tamper`, Pin `U17`)**.
   * **Expected Board State:** Red LED **`LD11` (`led_tamper_alarm`, Pin `U3`)** latches **ON (`1`)** instantly as `aes_master_key` (128-bit) zeroes to `0x0` in 1 clock cycle and the CPU enters `ST_TAMPER_HALT` (**`0002`**) until `SW1` (`rst_n`) is toggled.
