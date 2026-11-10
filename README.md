# PhoenixCore: Secure Energy-Aware Checkpoint Engine for Batteryless Edge Devices

**Event:** VConnecTech Engineering Marathon 2026 (Organized by VConnecTech Systems Pvt. Ltd. in association with IEEE Madras Section, IEEE CAS, Silicon Setu, & IEEE India Council)  
**Team ID:** `M2026-165` | **Team Name:** `NEXUS V`  
**Track / Domain:** Architecture & Package Design / System Design (`+ FPGA Design, Embedded Software, Hardware Security`)

---

## 1. Overview & Problem Addressed

Batteryless edge nodes running on harvested solar, piezoelectric, or RF energy experience frequent supply brownouts ($V_{\text{cap}} < V_{\min} = 1.80\,\text{V}$) that wipe volatile CPU registers and SRAM. While recent state-of-the-art architectures (**DiCA, ICCAD 2023**; **Palanisamy et al., ISQED 2025**) introduced block-level differential checkpointing and voltage triggers, they suffer from four hardware bottlenecks in real field deployments:

1. **Intra-Block Ciphertext Expansion:** Encrypting an entire 64-byte dirty block when only a few 32-bit words are non-zero turns intra-block zero-valued words (`word == 0x00000000`, common in zero-initialized stacks, zero-padded sensor buffers, and ReLU-clamped TinyML activations) into high-entropy ciphertext, wasting **41%–50% of SPI FRAM write energy**.
2. **Capacitor-Aging Blindness:** Fixed-capacitance trigger equations ($C = \text{const}$) trigger too late and crash mid-save when field aging or temperature derating reduces capacitance by $\ge 20\%$.
3. **Full-Restore Boot Stalls:** Holding the CPU in reset until the entire checkpoint image streams back over 25 MHz SPI FRAM (`0.32 µs/B`) delays wake-up by `0.79–5.29 ms`.
4. **Rollback & Glitch Vulnerability:** Static encryption keys on external serial FRAM remain vulnerable to mid-byte torn writes, checkpoint replay/rollback attacks, and brownout fault-injection glitches.

**PhoenixCore** resolves all four bottlenecks inside a verified **`4,580-LUT` (`22.02%` of Artix-7 `XC7A35T`, `8,046` total Yosys cells = `8,044` Xilinx logic/register primitives + `2` hard BRAM macros [`12 × RAMB36E1`])** full SoC and a **DRC/LVS/STA-clean SkyWater 130 nm (`Sky130A`) GDSII ASIC macro** (`357.69 µm × 368.41 µm` die, **`55.53%` OpenROAD GPL placement utilization** [`54.12%` raw cell/core area ratio], `6,199` physical instances, **`939` sequential DFFs** via on-the-fly round-key expansion and direct FRAM shadow streaming, down from `3,219` unoptimized DFFs) coupled to a `PicoRV32` (`RV32I`) processor, `16 KB` volatile SRAM (`256 × 64B` blocks), and `32 KB` wide-$V_{DD}$ SPI FRAM (`Fujitsu MB85RS256TY`, `1.8–3.6 V`, `25 MHz`).

---

## 2. Four Core Micro-Architectural Innovations

| Module | Micro-Architectural Mechanism | Measured / Simulated Advantage |
| :--- | :--- | :--- |
| **1. `PC-WMC`** | **Pre-Crypto Sub-Block Zero-Word Mask Compression:** 0-wait-state 256-bit (`8×32` banked) block dirty bitmap + 1-cycle 16-bit active-word mask (`w_mask[15:0]`) that suppresses intra-block zero-valued 32-bit words (`word == 0`) *before* AES stream encryption (`w_mask` is MAC-authenticated). | **41.3%–49.9% lower save energy** than DiCA'23 / ISQED'25 (`83.7%–96.4%` below SW full-copy). |
| **2. `SH-PDAT`** | **Self-Healing Closed-Loop $\Delta V$ Capacitor-Aging Trigger:** Computes $E_{\text{save}}$ digitally from `total_active_words_saved` and latches $V_{\text{start}}, V_{\text{end}}$ across every checkpoint to calibrate effective capacitance $C_{\text{eff}}$ (+25 mV step when $V_{\text{end}} < 1.85\,\text{V}$; $\gamma = 1.20$ safety margin absorbs 1-save lag). | **Survives up to 45% capacitor aging** (`100 µF → 55 µF`), whereas fixed-$C$ triggers fail at $\le 80\,\mu\text{F}$. |
| **3. `CLJ-HPR`** | **Commit-Last Journal + 2-Block Hot-Priority Restore:** Appends a 16-byte Atomic Commit Frame (`0x5043`) last and restores `136 B` CPU registers + `2 × 64 B` active Stack/Data blocks (`280 B` total) *first* on reboot. | **`89.6 µs` wake-up time-to-first-instruction** (`8.8×–33.5×` faster than DiCA; `59.0×` faster than SW) & `668/668` torn-write survival. |
| **4. `Zeroizer`** | **Monotonic Anti-Rollback MAC + 1-Cycle Key Zeroizer:** Root key & 64-bit monotonic counter persist in on-chip OTP/BBRAM (or `ATECC608B`); active round-key DFFs zeroize in **1 clock cycle (`20 ns`)** on tamper/rollback. | **`166/166` (`100%`) detection** of bit-flip tamper and stale-generation rollback attacks in `20 ns`. |

---

## 3. Repository Structure

```text
PhoenixCore-M2026-165/
├── README.md                                  # Setup, build, and 1-command reproducibility guide
├── requirements.txt                           # Python dependencies
├── run_ubuntu_flow.sh                         # 6-stage automation script (Sim + Icarus + Yosys + OpenLane 2)
├── phoenixcore_asic_macro.v                   # DRC/LVS/STA-clean synthesizable PhoenixCore ASIC/FPGA IP macro
├── phoenixcore_top.v                          # Top-level RV32I + INT8 TinyML MAC + PhoenixCore SoC + BRAM macros
├── tb_phoenixcore_top.v                       # Self-checking 4-stage hardware verification testbench
├── phoenixcore_brownout_sim.py                # 1,000-trial seeded brownout, 3-way benchmark, & cap-aging simulator
├── sim_1000_trials_report.json                # Deterministic JSON output of 1,000-trial simulation
├── basys3_phoenixcore.xdc                     # Xilinx Vivado pin & timing constraints for Digilent Basys3 (XC7A35T)
├── phoenixcore_asic_macro.sdc                 # OpenSTA-native Synopsys Design Constraints for Sky130A PnR & Signoff
├── config.json                                # OpenLane 2 configuration for SkyWater 130 nm (Sky130A) RTL-to-GDSII
├── rtl/                                       # Mirror of modular RTL files
├── tb/                                        # Mirror of testbench files
├── sim/                                       # Mirror of Python simulator & JSON report
├── fpga/                                      # Mirror of Basys3 XDC constraints
├── asic/                                      # Mirror of OpenLane 2 config.json & SDC constraints
└── docs/
    ├── M2026-165_PhoenixCore_DPR.pdf          # Final 8-Page IEEE Two-Column Detailed Project Report (DPR)
    ├── M2026-165_PhoenixCore_DPR.docx         # Editable DPR source document
    └── M2026-165_PhoenixCore_MidWork_Review.pptx # 9-Slide Mid-Work Progress Review Presentation (13 Nov 2026)
```

---

## 4. Quick-Start & Reproducibility Guide (Evaluator Clean-Environment Setup)

### Option A: One-Command Full Verification, Synthesis, & GDSII Flow
```bash
chmod +x run_ubuntu_flow.sh
./run_ubuntu_flow.sh
```

### Option B: Step-by-Step Execution
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

# 4. Run OpenLane 2 Sky130A RTL-to-GDSII Signoff Flow
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

## 6. Measured Hardware Synthesis & Physical Signoff Metrics

### A. Xilinx Artix-7 (`XC7A35T` Digilent Basys3) Full-SoC Utilization (`Logfile hash: b5dbe39415`)
* **Total Yosys Cells (`8,046`):** **`8,044` Xilinx 7-Series logic/register primitives** + **`2` hard memory macro instances** (`sram_16kb_bram_macro` and `fram_32kb_bram_macro`, mapping to **`12 × RAMB36E1` Block RAMs** [`24.00%` of Basys3's 50 BRAMs]).
* **Breakdown of `8,044` Primitives:** **`4,580` LUTs (`22.02%`)** (`1,588` LUT6, `1,049` LUT5, `648` LUT4, `396` LUT3, `831` LUT2, `68` LUT1) + **`2,031` `FDRE` flip-flops (`4.88%`)** + **`32` `RAM32X1D` LUT-RAMs** + **`498` `MUXCY` + `456` `XORCY` carry chains** + **`368` `MUXF7` + `79` `MUXF8` wide muxes** = `8,044`.

### B. OpenLane 2 SkyWater 130 nm (`Sky130A`) Physical GDSII Signoff (`RUN_2026-11-10_11-22-23`)
* **Die & Core Dimensions:** **`357.685 µm × 368.405 µm` die** (`0.132 mm²`), **`119,653.507 µm²` core area**, **`64,753.354 µm²` standard-cell area**.
* **Core Utilization:** **`55.534%` OpenROAD GPL placement utilization** (`64,753.354 / (119,653.507 - 3,051.677) = 55.534%` after subtracting `3,051.677 µm²` of non-placeable tap/obstruction area with `GPL_CELL_PADDING = 2`; **`54.117%` raw cell/core area ratio**).
* **Physical Instance Breakdown (`6,199` total cells):** **`939` sequential DFFs** (reduced from `3,219` unoptimized DFFs via on-the-fly 128-bit round-key expansion and direct `0xFE0–0xFFF` FRAM shadow streaming), **`3,270` multi-input combinational cells**, **`1,677` tap/decap cells**, **`254` fill cells**, and **`59` buffers/inverters**.
* **Signoff Verification (`78/78` Stages Complete in `08m 19s`):** **9-Corner Setup STA (`0` violations)**, **9-Corner Hold STA (`0` violations)**, **Max Capacitance STA (`0` violations)**, **Netgen LVS (`Passed ✅`)**, and **Magic / KLayout DRC (`Passed ✅`)**.

---

## 7. Team Roster (`NEXUS V` — `M2026-165`)
* **Akif Mohamed J (Team Lead):** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli (`akifmohamed2217@gmail.com`)
* **Nandikha M:** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli (`sisterapk1237@gmail.com`)
* **Mariam Farisha D:** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli (`mariyamfarisha90@gmail.com`)
* **Hiran Sruthi N:** B.E. ECE (IV Year), Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`hiransruthi11mar@gmail.com`)
* **Dharshini K:** B.E. ECE (IV Year), Alagappa Chettiar Government College of Engineering & Technology, Karaikudi (`dharshinisuyam11@gmail.com`)
