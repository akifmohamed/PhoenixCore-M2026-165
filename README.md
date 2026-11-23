# PhoenixCore: Secure Energy-Aware Checkpoint Engine for Batteryless Edge Devices

**Event:** VConnecTech Engineering Marathon 2026  
**Organized by:** VConnecTech Systems Pvt. Ltd. in association with IEEE Madras Section, IEEE CAS, Silicon Setu, IEEE India Council, & IEEE IC SDG Club  
**Team ID:** `M2026-165` | **Team Name:** `NEXUS V` | **Track:** Architecture & System Design (`TRL-4 Verified`)

---

## Quick-Access Round-02 Deliverables

| Deliverable | Direct Link / File | Description |
| :--- | :--- | :--- |
| **Detailed Project Report (PDF)** | [`docs/M2026-165_PhoenixCore_DPR.pdf`](docs/M2026-165_PhoenixCore_DPR.pdf) | Final 8-page A4 lossless IEEE two-column DPR (clickable links, Figs. 1–6, Tables I–IV, & Checklist) |
| **Detailed Project Report (DOCX)** | [`docs/M2026-165_PhoenixCore_DPR.docx`](docs/M2026-165_PhoenixCore_DPR.docx) | Editable Word source matching the final A4 PDF |
| **Final Presentation Deck (PDF)** | [`docs/M2026-165_PhoenixCore_Final_Presentation.pdf`](docs/M2026-165_PhoenixCore_Final_Presentation.pdf) | 10-slide Final Round-02 presentation (Problem, Related Work, Architecture, Results, Basys3 FPGA, & Impact) |
| **Final Presentation Deck (PPTX)** | [`docs/M2026-165_PhoenixCore_Final_Presentation.pptx`](docs/M2026-165_PhoenixCore_Final_Presentation.pptx) | Editable PowerPoint source of the Final Round-02 deck |
| **Narrated Live Demo Video** | [https://youtu.be/zddmPC3iUGQ](https://youtu.be/zddmPC3iUGQ) | 1.75-minute narrated walkthrough: Architecture, 4/4 GTKWave RTL, Sky130A GDSII, & Live Basys3 QSPI FPGA Demo |
| **Hardware Documentation & Proofs** | [`docs/proofs/`](docs/proofs/) · [`FPGA_PROTOTYPE_BRINGUP_GUIDE.md`](FPGA_PROTOTYPE_BRINGUP_GUIDE.md) · [`phoenixcore_bom.csv`](phoenixcore_bom.csv) | Live Basys3 board photos, PMOD schematic, pinout/Vivado guide, and full BOM (`BQ25570` + `MB85RS256TY`) |

---

## 1. Overview & Four Hardware Bottlenecks Addressed

Batteryless edge nodes running on harvested solar, piezoelectric, or RF energy experience frequent supply brownouts ($V_{\text{cap}} < V_{\min} = 1.80\,\text{V}$) that erase volatile CPU registers and SRAM. While recent state-of-the-art architectures (**DiCA, ICCAD 2023 [5]**; **Palanisamy et al., ISQED 2025 [7]**) introduced block-level differential checkpointing and voltage triggers, they suffer from four hardware bottlenecks in real field deployments:

1. **Intra-Block Ciphertext Expansion:** Encrypting an entire 64-byte dirty block when only a few 32-bit words are non-zero turns intra-block zero-valued words (`word == 0x00000000`) into high-entropy ciphertext, wasting **41%–50% of SPI FRAM write energy**.
2. **Capacitor-Aging Blindness:** Fixed-capacitance trigger equations ($C = \text{const}$) trigger too late and crash mid-save when field aging or temperature derating reduces capacitance by $\ge 20\%$.
3. **Full-Restore Boot Stalls:** Holding the CPU in reset until the entire checkpoint image streams back over 25 MHz SPI FRAM (`0.32 µs/B`) delays wake-up by `0.79–5.29 ms`.
4. **Rollback & Glitch Vulnerability:** Static encryption keys on external serial FRAM remain vulnerable to mid-byte torn writes, checkpoint replay/rollback attacks [6], and physical tamper glitches.

**PhoenixCore** resolves all four bottlenecks in a synthesizable RTL SoC verified via **4/4 Icarus Verilog hardware tests**, a **1,000-trial seeded brownout/tamper campaign (`sim/sim_1000_trials_report.json`)**, a **live Digilent Basys3 Artix-7 FPGA (`S25FL128S` QSPI Flash boot)**, and a **SkyWater 130 nm (`Sky130A`) OpenLane 2 GDSII flow**.

---

## 2. Four Core Micro-Architectural Innovations

| Module | Micro-Architectural Mechanism | Measured / Simulated Advantage |
| :--- | :--- | :--- |
| **1. `PC-WMC`** | **Pre-Crypto Sub-Block Zero-Word Mask Compression:** 0-wait-state 256-bit (`8×32` banked) dirty bitmap + 1-cycle 16-bit active-word mask (`w_mask[15:0]`) suppressing zero-valued 32-bit words (`word == 0`) *before* AES encryption (`w_mask` is MAC-authenticated; a header bypass flag handles `k == 16`). | **41.3%–49.9% lower save energy** than DiCA'23 / ISQED'25 (`83.7%–96.4%` below SW full-copy). |
| **2. `SH-PDAT`** | **Self-Healing Closed-Loop $\Delta V$ Capacitor-Aging Trigger:** Tracks $V_{\text{start}} - V_{\text{end}}$ across every checkpoint to calibrate effective capacitance $C_{\text{eff}}$ (`+25 mV` step when $V_{\text{end}} < 1.85\,\text{V}$; the $\gamma = 1.20$ **20% energy safety margin** covers single-step capacitance drops up to ~16.7% [$1 - 1/1.20$]). | **Survives up to 45% capacitor aging** (`100 µF → 55 µF`), whereas fixed-$C$ triggers fail at $\le 80\,\mu\text{F}$. |
| **3. `CLJ-HPR`** | **Commit-Last Journal + 2-Block Hot-Priority Restore:** Appends a 16-byte Atomic Commit Frame (`0x5043`) last and restores `136 B` CPU registers + `2 × 64 B` active Stack/Data blocks (`280 B`) *first* on reboot. | **`89.6 µs` wake-up time-to-first-instruction** (`8.8×–33.5×` faster than DiCA; `59.0×` faster than SW) & `834/834` brownout recovery. |
| **4. `Zeroizer`** | **Monotonic Anti-Rollback MAC + 1-Cycle Key Zeroizer:** Binds commits to a 64-bit monotonic counter; wipes active 128-bit `aes_master_key` flip-flops and locks down the CPU (`ST_TAMPER_HALT`) in **1 clock cycle** on tamper/rollback. | **`166/166` (`100%`) detection** in simulation + live Basys3 `BTND` hardware lockdown (`LD11` ON, CPU halted). |

---

## 3. Complete Repository Map & File Guide

```text
PhoenixCore-M2026-165/
├── README.md                                     # Project overview, benchmarks, & evaluator notes
├── FPGA_PROTOTYPE_BRINGUP_GUIDE.md               # Digilent Basys3 silkscreen pinout & 4-step live demo guide
├── phoenixcore_bom.csv                           # Bill of Materials (TI BQ25570 + wide-VDD Fujitsu MB85RS256TY FRAM)
├── requirements.txt                              # Python dependencies (pyserial>=3.5 for UART dashboard)
├── run_ubuntu_flow.sh                            # Automated Linux verification & synthesis script
├── rtl/
│   ├── phoenixcore_asic_macro.v                  # Synthesizable PC-WMC, SH-PDAT, CLJ-HPR, 1-cycle zeroizer, 380 Hz 7-seg, & UART
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
│   ├── config.json                               # OpenLane 2 configuration for SkyWater 130 nm (Sky130A) RTL-to-GDSII (run from repo root)
│   ├── phoenixcore_asic_macro.sdc                # OpenSTA timing constraints for Sky130A PnR & 9-corner signoff
│   └── phoenixcore_asic_macro.gds                # Sky130A GDSII layout (pre-refactor Nov 10–12 signoff snapshot)
└── docs/
    ├── M2026-165_PhoenixCore_DPR.pdf             # Final A4 lossless IEEE Detailed Project Report (PDF)
    ├── M2026-165_PhoenixCore_DPR.docx            # Editable A4 IEEE Detailed Project Report (DOCX)
    ├── M2026-165_PhoenixCore_Final_Presentation.pdf  # Final 10-slide Round-02 Presentation (PDF)
    ├── M2026-165_PhoenixCore_Final_Presentation.pptx # Final 10-slide Round-02 Presentation (PPTX)
    └── proofs/                                   # High-res GTKWave, Yosys, OpenROAD, KLayout, Basys3 FPGA, & PMOD schematic proofs
```

*(Root-level mirrors of `phoenixcore_top.v`, `phoenixcore_asic_macro.v`, `tb_phoenixcore_top.v`, `basys3_phoenixcore.xdc`, and `rtl_verification_log.txt` are included so single-folder commands work directly.)*

---

## 4. Quick-Start & Reproducibility Guide

```bash
# 1. Run 1,000-Trial Brownout, 3-Way Benchmark, & Capacitor-Aging Simulator
python3 sim/phoenixcore_brownout_sim.py > sim/sim_1000_trials_report.json

# 2. Run Cycle-Accurate RTL Simulation (4/4 Hardware Tests Pass) & View Waveform
iverilog -o phoenixcore_sim.vvp rtl/phoenixcore_asic_macro.v rtl/phoenixcore_top.v tb/tb_phoenixcore_top.v
vvp phoenixcore_sim.vvp | tee rtl_verification_log.txt
gtkwave phoenixcore_wave.vcd

# 3. Build Digilent Basys3 Bitstream & Flash Board in Xilinx Vivado
vivado -mode batch -source fpga/build_and_program_basys3.tcl

# 4. Run OpenLane 2 Sky130A RTL-to-GDSII Flow (execute from repo root so asic/config.json resolves RTL paths)
openlane asic/config.json || nix run github:efabless/openlane2 -- asic/config.json
```

---

## 5. Benchmark Results (`sim/sim_1000_trials_report.json`)

### A. Energy & Wake-Up Latency (`50 MHz` Core, `25 MHz` SPI FRAM [`0.32 µs/B`], `100 µF` Buffer)

| Workload / Scheme | FRAM Bytes Written | Save Latency | Save Energy | Wake-Up Latency (`@ 25 MHz` SPI) | Capacitor-Aging Survival (`100 → 55 µF`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SW Full-Copy Baseline [1],[2]** | `16,536 B` | `11.244 ms` | `211.51 µJ` | `5,291.5 µs` | Fails at $\le 90\,\mu\text{F}$ (`10%` loss) |
| **Case 1 (Sparse 12.5%, $k=6/16$): DiCA / ISQED'25 [5],[7]** | `2,456 B` | `0.818 ms` | `15.38 µJ` | `785.9 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 1 (Sparse 12.5%, $k=6/16$): PhoenixCore (Ours)** | **`1,240 B` (`-49.5%`)** | **`0.409 ms`** | **`7.70 µJ` (`-49.9%`)** | **`89.6 µs` (`8.8×` faster)** | **Survives down to `55 µF` (`45%` loss)** |
| **Case 2 (Moderate 25%, $k=7/16$): DiCA / ISQED'25 [5],[7]** | `4,760 B` | `1.586 ms` | `29.83 µJ` | `1,523.2 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 2 (Moderate 25%, $k=7/16$): PhoenixCore (Ours)** | **`2,584 B` (`-45.7%`)** | **`0.855 ms`** | **`16.08 µJ` (`-46.1%`)** | **`89.6 µs` (`17.0×` faster)** | **Survives down to `55 µF` (`45%` loss)** |
| **Case 3 (Dense 50%, $k=8/16$): DiCA / ISQED'25 [5],[7]** | `9,368 B` | `3.122 ms` | `58.72 µJ` | `2,997.8 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) |
| **Case 3 (Dense 50%, $k=8/16$): PhoenixCore (Ours)** | **`5,528 B` (`-41.0%`)** | **`1.831 ms`** | **`34.45 µJ` (`-41.3%`)** | **`89.6 µs` (`33.5×` faster)** | **Survives down to `55 µF` (`45%` loss)** |

### B. 1,000-Trial Fault-Injection & 6-Step Capacitor-Aging Sweep (`100 µF → 55 µF`)
* **1,000-Trial Seeded Campaign:** **`1,000 / 1,000` (`100%`)** pass rate — **`834 / 834`** exact state-digest brownout recoveries + **`166 / 166`** rollback/tamper detections with 1-cycle key zeroization.
* **6-Step Aging Sweep (`100, 90, 80, 70, 60, 55 µF`):** Fixed-$C$ triggers [5],[7] collapse below $V_{\min} = 1.80\,\text{V}$ starting at `80 µF` (`1.767 → 1.567 V`), whereas PhoenixCore `SH-PDAT` raises $V_{\text{trig}}$ from `2.015 V` to `2.175 V` and holds $V_{\text{end}} \ge 1.838\,\text{V}$ all the way down to `55 µF` (`45%` loss).

---

## 6. Live Digilent Basys3 QSPI FPGA Demo & Silicon Signoff

### A. 4-Step Physical Basys3 Hardware Verification ([Demo Video](https://youtu.be/zddmPC3iUGQ))
Permanently flashed to the Basys3 **Spansion `S25FL128S` Quad-SPI Flash** (`JP1 = QSPI`, `Vivado 2017.4`, `0` DRC errors, `WNS = +8.625 ns`, `WHS = +0.068 ns`, `WPWS = +9.500 ns` at `20.0 ns` / `50 MHz` constraint):

| Step | Board Input | Observed LEDs | 7-Segment Display | Verified Hardware Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Test 1: Normal Run** | `SW1=1`, `SW15+SW14=1` (`3,072 mV`) | `LD6` ON (`0x040`) | **`4000`** | Tracks `64` dirty SRAM blocks in 0 wait states |
| **Test 2: Brownout Save** | `SW15` DOWN (`1,024 mV`) | `LD12` ON, `LD6` OFF | **`0001`** | `PC-WMC` + `CLJ-HPR` commits `Gen 1` to NV memory |
| **Test 3: Hot Restore** | `SW15` UP (`3,072 mV`) | `LD10`, `LD12`, `LD6` ON | **`4001`** | `89.6 µs` Hot-Priority Restore passes MAC check |
| **Test 4: Tamper Halt** | Press `BTND` (`U17`) | `LD11` latched ON | **`0002`** | 1-cycle `128-bit` `aes_master_key` zeroization + `ST_TAMPER_HALT` |

### B. Verification Status & Known Limitations (Evaluator Notes)
1. **128-bit Master Key vs. Pre-Refactor 1,408-bit Key Array:** The current refactored `rtl/phoenixcore_asic_macro.v` implements an on-the-fly **128-bit `aes_master_key`** zeroized in 1 clock cycle (the earlier pre-refactor Nov 10–12 behavioral/unoptimized model referenced `1,408` expanded key flops in the DPR/video).
2. **Yosys & OpenLane 2 Snapshot Provenance:** The committed Yosys 0.9 report (`8,046` cells) and OpenLane 2 Sky130A GDSII run (`RUN_2026-11-10_11-22-23`, `357.69 × 368.41 µm`, `55.534%` GPL utilization, `6,199` instances, `939` DFFs, 9-corner STA/LVS/DRC clean) were generated on the **Nov 10–12 pre-refactor RTL**; re-running Yosys/OpenLane on the Nov 22 refactored RTL produces updated cell counts.
3. **Basys3 Oscillator vs. XDC Constraint:** Digilent Basys3 pin `W5` is a `100 MHz` physical oscillator, while `fpga/basys3_phoenixcore.xdc` constrains `clk_50mhz` at `20.0 ns` (`50 MHz`, yielding `WNS = +8.625 ns`, i.e., `~11.375 ns` critical path). Closing full `100 MHz` (`10.0 ns`) timing or inserting an MMCM `÷2` divider is tracked for Round 03.
4. **Physical PCB Scope:** No physical KiCad PCB has been fabricated yet; Round 02 delivers the live Basys3 QSPI FPGA prototype, PMOD interconnect schematic, and BOM (`phoenixcore_bom.csv`), with physical `TI BQ25570 + MB85RS256TY` PCB assembly scheduled for Phase 4 (Round 03).

---

## 7. Live Execution, FPGA, & Silicon Signoff Proofs (`docs/proofs/`)

* **Live Digilent Basys3 QSPI FPGA Proof (Tests 1–4):** [`docs/proofs/fig6_basys3_hardware_proof.png`](docs/proofs/fig6_basys3_hardware_proof.png)
* **Basys3 PMOD Harvester/FRAM Interconnect Schematic:** [`docs/proofs/fig6_fpga_pmod_schematic.png`](docs/proofs/fig6_fpga_pmod_schematic.png)
* **Icarus Verilog `4 / 4` Tests Passed:** [`docs/proofs/01_iverilog_4_of_4_tests_passed.jpg`](docs/proofs/01_iverilog_4_of_4_tests_passed.jpg)
* **GTKWave Waveform (`0–21.83 µs`, `0x021 = 33` Blocks):** [`docs/proofs/02_gtkwave_waveform_proof.png`](docs/proofs/02_gtkwave_waveform_proof.png)
* **Yosys ASIC & Artix-7 Synthesis:** [`docs/proofs/03_yosys_asic_and_artix7_synthesis.png`](docs/proofs/03_yosys_asic_and_artix7_synthesis.png)
* **OpenLane 2 (`Sky130A`) Stage 78/78 Signoff:** [`docs/proofs/04_openlane2_stage78_drc_lvs_sta_passed.jpg`](docs/proofs/04_openlane2_stage78_drc_lvs_sta_passed.jpg)
* **OpenROAD Full-Die Sky130A Layout:** [`docs/proofs/07_openroad_full_die_layout.png`](docs/proofs/07_openroad_full_die_layout.png)
* **OpenROAD `1 µm` Standard-Cell Zoom:** [`docs/proofs/09_openroad_1um_cell_cts_hold_zoom.png`](docs/proofs/09_openroad_1um_cell_cts_hold_zoom.png)
* **KLayout `0.30.9` Final GDSII Mask:** [`docs/proofs/05_klayout_sky130a_black_bg.png`](docs/proofs/05_klayout_sky130a_black_bg.png)

---

## 8. Team Roster (`NEXUS V` — `M2026-165`)
* **Akif Mohamed J (Team Lead):** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`akifmohamed2217@gmail.com`)
* **Nandikha M:** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`sisterapk1237@gmail.com`)
* **Mariam Farisha D:** Final-Year B.E. ECE, Government College of Engineering, Srirangam, Tiruchirappalli (`mariyamfarisha90@gmail.com`)
* **Hiran Sruthi N:** Final-Year B.E. ECE, Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`hiransruthi11mar@gmail.com`)
* **Dharshini K:** Final-Year B.E. ECE, Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`dharshinisuyam11@gmail.com`)