# PhoenixCore: Secure Energy-Aware Checkpoint Engine for Batteryless Edge Devices

**Event:** VConnecTech Engineering Marathon 2026  
**Organized by:** VConnecTech Systems Pvt. Ltd. in association with IEEE Madras Section, IEEE CAS, Silicon Setu, IEEE India Council, & IEEE IC SDG Club  
**Team ID:** `M2026-165` | **Team Name:** `NEXUS V` | **Track:** Architecture & System Design (`TRL-4 Verified`)

---

## Quick-Access Round-02 Deliverables

| Deliverable | Direct Link / File | Description |
| :--- | :--- | :--- |
| **Detailed Project Report (PDF)** | [docs/M2026-165\_PhoenixCore\_DPR.pdf](https://www.google.com/search?q=docs/M2026-165_PhoenixCore_DPR.pdf) | Final 8-page A4 lossless IEEE two-column DPR (with clickable links, Figs. 1–6, Tables I–IV, & Checklist) |
| **Detailed Project Report (DOCX)** | [docs/M2026-165\_PhoenixCore\_DPR.docx](https://www.google.com/search?q=docs/M2026-165_PhoenixCore_DPR.docx) | Editable Word source matching the final A4 PDF |
| **Final Presentation Deck (PDF)** | [docs/M2026-165\_PhoenixCore\_Final\_Presentation.pdf](https://www.google.com/search?q=docs/M2026-165_PhoenixCore_Final_Presentation.pdf) | 10-slide Final Round-02 presentation (Problem, Related Work, Architecture, Results, Basys3 FPGA, Novelty, & Impact) |
| **Final Presentation Deck (PPTX)** | [docs/M2026-165\_PhoenixCore\_Final\_Presentation.pptx](https://www.google.com/search?q=docs/M2026-165_PhoenixCore_Final_Presentation.pptx) | Editable PowerPoint source of the Final Round-02 deck |
| **Narrated Live Demo Video** | [https://youtu.be/zddmPC3iUGQ](https://youtu.be/zddmPC3iUGQ) | 1.75-minute narrated walkthrough: Architecture, 4/4 GTKWave RTL, Sky130A GDSII, & Live Basys3 QSPI FPGA Demo |
| **Hardware Documentation & Proofs** | [docs/proofs/](https://www.google.com/search?q=docs/proofs/) · [FPGA\_PROTOTYPE\_BRINGUP\_GUIDE.md](https://www.google.com/search?q=FPGA_PROTOTYPE_BRINGUP_GUIDE.md) · [phoenixcore\_bom.csv](https://www.google.com/search?q=phoenixcore_bom.csv) | Live Basys3 board photos, PMOD schematic, pinout/Vivado guide, and full BOM (`BQ25570` + `MB85RS256TY`) |

---

## 1. Overview & Problem Addressed

Batteryless edge nodes running on harvested solar, piezoelectric, or RF energy experience frequent supply brownouts ($V_{\text{cap}} < V_{\min} = 1.80\,\text{V}$) that erase volatile CPU registers and SRAM. While recent state-of-the-art architectures (**DiCA, ICCAD 2023 [5]**; **Palanisamy et al., ISQED 2025 [7]**) introduced block-level differential checkpointing and voltage triggers, they suffer from four hardware bottlenecks in real field deployments:

1. **Intra-Block Ciphertext Expansion:** Encrypting an entire 64-byte dirty block when only a few 32-bit words are non-zero turns intra-block zero-valued words (`word == 0x00000000`) into high-entropy ciphertext, wasting **41%–50% of SPI FRAM write energy**.
2. **Capacitor-Aging Blindness:** Fixed-capacitance trigger equations ($C = \text{const}$) trigger too late and crash mid-save when field aging or temperature derating reduces capacitance by $\ge 20\%$.
3. **Full-Restore Boot Stalls:** Holding the CPU in reset until the entire checkpoint image streams back over 25 MHz SPI FRAM (`0.32 µs/B`) delays wake-up by `0.79–5.29 ms`.
4. **Rollback & Glitch Vulnerability:** Static encryption keys on external serial FRAM remain vulnerable to mid-byte torn writes, checkpoint replay/rollback attacks [6], and physical tamper glitches.

**PhoenixCore** resolves all four bottlenecks inside a verified **`4,580-LUT` (`22.02%` of Artix-7 `XC7A35T`, `8,046` total Yosys cells)** full SoC, implemented on a **live Digilent Basys3 FPGA booting permanently from `S25FL128S` QSPI Flash (`WNS = +8.625 ns`, `WHS = +0.068 ns`, `0` DRC errors)**, and verified through a **DRC/LVS/STA-clean SkyWater 130 nm (`Sky130A`) GDSII ASIC macro** (`357.69 µm × 368.41 µm` die, **`55.53%` OpenROAD GPL placement utilization** [`54.12%` raw cell/core area ratio], `6,199` physical instances, **`939` sequential DFFs**).

---

## 2. Four Core Micro-Architectural Innovations

| Module | Micro-Architectural Mechanism | Measured / Simulated Advantage |
| :--- | :--- | :--- |
| **1. `PC-WMC`** | **Pre-Crypto Sub-Block Zero-Word Mask Compression:** 0-wait-state 256-bit (`8×32` banked) dirty bitmap + 1-cycle 16-bit active-word mask (`w_mask[15:0]`) suppressing zero-valued 32-bit words (`word == 0`) *before* AES encryption (`w_mask` is MAC-authenticated; a header bypass flag handles `k == 16`). | **41.3%–49.9% lower save energy** than DiCA'23 / ISQED'25 (`83.7%–96.4%` below SW full-copy). |
| **2. `SH-PDAT`** | **Self-Healing Closed-Loop $\Delta V$ Capacitor-Aging Trigger:** Tracks $V_{\text{start}} - V_{\text{end}}$ across every checkpoint to calibrate effective capacitance $C_{\text{eff}}$ (+25 mV step when $V_{\text{end}} < 1.85\,\text{V}$; the $\gamma = 1.20$ **20% energy safety margin** covers single-step capacitance drops up to ~16.7% [$1 - 1/1.20$]). | **Survives up to 45% capacitor aging** (`100 µF → 55 µF`), whereas fixed-$C$ triggers fail at $\le 80\,\mu\text{F}$. |
| **3. `CLJ-HPR`** | **Commit-Last Journal + 2-Block Hot-Priority Restore:** Appends a 16-byte Atomic Commit Frame (`0x5043`) last and restores `136 B` CPU registers + `2 × 64 B` active Stack/Data blocks (`280 B`) *first* on reboot. | **`89.6 µs` wake-up time-to-first-instruction** (`8.8×–33.5×` faster than DiCA; `59.0×` faster than SW) & `668/668` torn-write survival. |
| **4. `Zeroizer`** | **Monotonic Anti-Rollback MAC + 1-Cycle Key Zeroizer:** Binds commits to a 64-bit monotonic counter; wipes active AES-128 key flip-flops and locks down the CPU in **1 clock cycle (`20 ns`)** on tamper/rollback. | **`166/166` (`100%`) detection** in simulation + live Basys3 `BTND` hardware lockdown (`LD11` ON, CPU halted). |

---

## 3. Complete Repository Map & File Guide

```text
PhoenixCore-M2026-165/
├── README.md                                     # Project overview, deliverables, & 1-command reproducibility guide
├── FPGA_PROTOTYPE_BRINGUP_GUIDE.md               # Digilent Basys3 silkscreen pinout, Vivado flow, & 4-step live demo guide
├── phoenixcore_bom.csv                           # Bill of Materials (TI BQ25570 + wide-VDD Fujitsu MB85RS256TY FRAM)
├── requirements.txt                              # Python dependencies for simulation & UART dashboard
├── run_ubuntu_flow.sh                            # Automated 6-stage verification, synthesis, & OpenLane 2 script
├── M2026-165_PhoenixCore_DPR.pdf                 # Final A4 lossless IEEE Detailed Project Report (PDF)
├── M2026-165_PhoenixCore_DPR.docx                # Editable A4 IEEE Detailed Project Report (DOCX)
├── M2026-165_PhoenixCore_Final_Presentation.pdf  # Final 10-slide Round-02 Presentation (PDF)
├── M2026-165_PhoenixCore_Final_Presentation.pptx # Final 10-slide Round-02 Presentation (PPTX)
├── rtl/
│   ├── phoenixcore_asic_macro.v                  # Synthesizable PC-WMC, SH-PDAT, CLJ-HPR, 20 ns tamper lockdown, 380 Hz 7-seg, & UART
│   └── phoenixcore_top.v                         # Top-level RV32I + INT8 TinyML MAC + BRAM inference + 20 ms hardware debouncer
├── tb/
│   └── tb_phoenixcore_top.v                      # Self-checking 4-stage hardware verification testbench (4/4 PASS)
├── sim/
│   ├── phoenixcore_brownout_sim.py               # 1,000-trial seeded brownout, 3-way benchmark, & cap-aging simulator
│   ├── sim_1000_trials_report.json               # Deterministic JSON output of 1,000-trial simulation
│   └── uart_dashboard.py                         # Live Basys3 USB-UART telemetry monitor (`115200 8N1`) & replay tool
├── fpga/
│   ├── basys3_phoenixcore.xdc                    # Silkscreen-verified Digilent Basys3 constraints (SW0, SW1, SW4–SW15, LD0–LD15, PMOD JA/JB/JC)
│   └── build_and_program_basys3.tcl              # Automated Vivado batch synthesis, P&R, bitstream, & USB-JTAG programming script
├── asic/
│   ├── config.json                               # OpenLane 2 configuration for SkyWater 130 nm (Sky130A) RTL-to-GDSII
│   ├── phoenixcore_asic_macro.sdc                # OpenSTA timing constraints for Sky130A PnR & 9-corner signoff
│   └── phoenixcore_asic_macro.gds                # Final DRC/LVS-clean Sky130A GDSII layout
└── docs/
    ├── M2026-165_PhoenixCore_DPR.pdf             # Mirror of Final A4 DPR PDF
    ├── M2026-165_PhoenixCore_DPR.docx            # Mirror of Final A4 DPR DOCX
    ├── M2026-165_PhoenixCore_Final_Presentation.pdf  # Mirror of Final Presentation PDF
    ├── M2026-165_PhoenixCore_Final_Presentation.pptx # Mirror of Final Presentation PPTX
    └── proofs/                                   # High-res GTKWave, Yosys, OpenROAD, KLayout, Basys3 FPGA, & PMOD schematic proofs
```

*(Root-level mirrors of `phoenixcore_top.v`, `phoenixcore_asic_macro.v`, `tb_phoenixcore_top.v`, `basys3_phoenixcore.xdc`, `rtl_verification_log.txt`, and `yosys_*.txt` are synchronized with the subdirectories so single-folder commands work cleanly out of the box.)*

---

## 4. Quick-Start & Reproducibility Guide (Clean-Environment Setup)

```bash
# 1. Run 1,000-Trial Brownout, 3-Way Benchmark, & Capacitor-Aging Simulator
python3 phoenixcore_brownout_sim.py > sim_1000_trials_report.json

# 2. Run Cycle-Accurate RTL Simulation (4/4 Hardware Tests Pass) & View Waveform
iverilog -o phoenixcore_sim.vvp phoenixcore_asic_macro.v phoenixcore_top.v tb_phoenixcore_top.v
vvp phoenixcore_sim.vvp | tee rtl_verification_log.txt
gtkwave phoenixcore_wave.vcd

# 3. Run Yosys ASIC Macro & Xilinx Artix-7 Basys3 Synthesis
yosys -s synth_asic_macro.ys | tee yosys_asic_macro_report.txt
yosys -s synth_basys3_fpga.ys | tee yosys_basys3_fpga_utilization.txt

# 4. Build Digilent Basys3 Bitstream & Flash Board in Xilinx Vivado
vivado -mode batch -source fpga/build_and_program_basys3.tcl

# 5. Run OpenLane 2 Sky130A RTL-to-GDSII Signoff Flow
openlane config.json || nix run github:efabless/openlane2 -- config.json
```

---

## 5. Benchmark Summary (`50 MHz` Core, `25 MHz` SPI FRAM [`0.32 µs/B`], `100 µF` Buffer)

| Workload / Scheme | FRAM Bytes Written | Save Latency | Save Energy | Wake-Up Latency (`@ 25 MHz` SPI) | Capacitor-Aging Survival (`100 → 55 µF`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SW Full-Copy Baseline [1],[2]** | `16,536 B` | `11.244 ms` | `211.51 µJ` | `5,291.5 µs` | Fails at $\le 90\,\mu\text{F}$ (`10%` loss) |
| **Case 1 (Sparse 12.5%, $k=6/16$): DiCA / ISQED'25 [5],[7]** | `2,456 B` | `0.818 ms` | `15.38 µJ` | `785.9 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 1 (Sparse 12.5%, $k=6/16$): PhoenixCore (Ours)** | **`1,240 B` (`-49.5%`)** | **`0.409 ms`** | **`7.70 µJ` (`-49.9%`)** | **`89.6 µs` (`8.8×` faster)** | **Survives down to `55 µF` (`45%` loss)** |
| **Case 2 (Moderate 25%, $k=7/16$): DiCA / ISQED'25 [5],[7]** | `4,760 B` | `1.586 ms` | `29.83 µJ` | `1,523.2 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 2 (Moderate 25%, $k=7/16$): PhoenixCore (Ours)** | **`2,584 B` (`-45.7%`)** | **`0.855 ms`** | **`16.08 µJ` (`-46.1%`)** | **`89.6 µs` (`17.0×` faster)** | **Survives down to `55 µF` (`45%` loss)** |
| **Case 3 (Dense 50%, $k=8/16$): DiCA / ISQED'25 [5],[7]** | `9,368 B` | `3.122 ms` | `58.72 µJ` | `2,997.8 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 3 (Dense 50%, $k=8/16$): PhoenixCore (Ours)** | **`5,528 B` (`-41.0%`)** | **`1.831 ms`** | **`34.45 µJ` (`-41.3%`)** | **`89.6 µs` (`33.5×` faster)** | **Survives down to `55 µF` (`45%` loss)** |

---

## 6. Measured Hardware Synthesis, FPGA, & Physical Signoff Metrics

### A. Xilinx Artix-7 (`XC7A35T` Digilent Basys3) Yosys Synthesis (`synth_xilinx -family xc7`, `hash: b5dbe39415`)
* **Total Yosys Cells (`8,046`):** **`8,044` Xilinx 7-Series primitives** + **`2` hard memory macro instances** (`12 × RAMB36E1` Block RAMs [`24.00%` of Basys3]).
* **Primitive Breakdown:** **`4,580` LUTs (`22.02%`)**, **`2,031` `FDRE` flip-flops (`4.88%`)**, **`32` `RAM32X1D` LUT-RAMs**, **`498` `MUXCY` + `456` `XORCY` carry chains**, and **`368` `MUXF7` + `79` `MUXF8` wide muxes**.

### B. Xilinx Vivado 2017.4 Digilent Basys3 (`XC7A35T-1CPG236C`) Hardware & QSPI Flash Signoff
* **Timing Closure (`50 MHz` Constraint):** **`WNS = +8.625 ns`**, **`WHS = +0.068 ns`**, **`WPWS = +9.500 ns`**, **`0` failing endpoints** out of `4,431`, **`0` DRC errors**.
* **On-Board Non-Volatile Boot:** Permanently flashed to the Basys3 **Spansion `S25FL128S` Quad-SPI Flash** (`JP1 = QSPI`), featuring a `20 ms` 2-stage switch/button debouncer (`phoenixcore_top.v`) and `380 Hz` 4-digit 7-segment display multiplexer (`seg_div[18:17]`).
* **4/4 Physical Board Tests Verified ([Demo Video](https://youtu.be/zddmPC3iUGQ)):**
  1. **Test 1 (`SW15, SW14` UP):** `LD6` glows (`64` dirty blocks tracked in 0 wait states); 7-segment displays **`4000`**.
  2. **Test 2 (`SW15` DOWN — Brownout):** `LD12` turns **ON** (`Gen 1` committed), `LD6` clears; 7-segment locks at **`0001`**.
  3. **Test 3 (`SW15` UP — Power Return):** `LD10` (`led_restore_ok`) lights **ON**, `LD6` resumes; 7-segment shows **`4001`**.
  4. **Test 4 (`BTND` — Physical Tamper):** `LD11` (`led_tamper_alarm`) latches **ON**, AES-128 key wipes in `20 ns`, CPU halts (**`0002`**) until `SW1` reset.

### C. OpenLane 2 SkyWater 130 nm (`Sky130A`) Physical GDSII Signoff (`RUN_2026-11-10_11-22-23`)
* **Die & Core Dimensions:** **`357.685 µm × 368.405 µm` die** (`0.132 mm²`), **`119,653.507 µm²` core area**, **`64,753.354 µm²` standard-cell area**.
* **Core Utilization:** **`55.534%` OpenROAD GPL placement utilization** (**`54.117%` raw cell/core area ratio**).
* **Physical Instance Breakdown (`6,199` cells):** **`939` sequential DFFs** (down from `3,219` unoptimized DFFs), **`3,270` combinational cells**, **`1,677` tap/decap cells**, **`254` fill cells**, and **`59` buffers/inverters**.
* **Signoff Verification (`78/78` Stages Complete):** **9-Corner Setup STA (`0`)**, **9-Corner Hold STA (`0`)**, **Max Capacitance STA (`0`)**, **Netgen LVS (`Passed ✅`)**, and **Magic / KLayout DRC (`Passed ✅`)**.

---

## 7. Live Execution, FPGA, & Silicon Signoff Proofs (`docs/proofs/`)

### 7.1 Live Digilent Basys3 Artix-7 QSPI FPGA Hardware Proof (Tests 1–4)


### 7.2 Icarus Verilog Cycle-Accurate RTL Verification (`4 / 4 Hardware Tests Passed`)


### 7.3 GTKWave Cycle-Accurate Waveform (`0 to 21.83 µs`, `0x021 = 33` Dirty Blocks)


### 7.4 Yosys 0.9 ASIC Macro & Xilinx Artix-7 (`synth_xilinx -family xc7`) Synthesis


### 7.5 OpenLane 2 (`Sky130A`) Stage 78/78 Signoff (`0 Setup / 0 Hold / 0 Max-Cap / LVS & DRC Passed`)


### 7.6 OpenROAD Full-Die Sky130A Layout (`357.69 µm × 368.41 µm`, `55.53%` GPL Utilization)


### 7.7 OpenROAD `1 µm` Standard-Cell Zoom (`clkbuf_0_clk` CTS Buffer, `hold390` Hold Buffers, & `fanout` Trees)


### 7.8 KLayout `0.30.9` Final GDSII Mask (`phoenixcore_asic_macro.gds` with `sky130A.lyp`)


### 7.9 Digilent Basys3 FPGA & PMOD Harvester/FRAM Interconnect Schematic (Round-03 PCB Target)


---

## 8. Team Roster (`NEXUS V` — `M2026-165`)
* **Akif Mohamed J (Team Lead):** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`akifmohamed2217@gmail.com`)
* **Nandikha M:** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`sisterapk1237@gmail.com`)
* **Mariam Farisha D:** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`mariyamfarisha90@gmail.com`)
* **Hiran Sruthi N:** Final-Year B.E. ECE, Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`hiransruthi11mar@gmail.com`)
* **Dharshini K:** Final-Year B.E. ECE, Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`dharshinisuyam11@gmail.com`)