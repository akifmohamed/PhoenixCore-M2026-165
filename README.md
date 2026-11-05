# PhoenixCore: Secure Energy-Aware Checkpoint Engine for Batteryless Edge Devices

**Event:** VConnecTech Engineering Marathon 2026 (Organized by VConnecTech Systems Pvt. Ltd. in association with IEEE Madras Section, IEEE CAS, Silicon Setu, & IEEE India Council)

**Team ID:** `M2026-165` | **Team Name:** `NEXUS V`

**Track / Domain:** Architecture & Package Design / System Design (`+ FPGA Design, Embedded Software, Hardware Security`)

## 1. Overview & Problem Addressed

Batteryless edge nodes running on harvested solar, piezoelectric, or RF energy experience frequent supply brownouts ($V_{\text{cap}} < V_{\min} = 1.80\,\text{V}$) that wipe volatile CPU registers and SRAM. While recent state-of-the-art architectures (**DiCA, ICCAD 2023**; **Palanisamy et al., ISQED 2025**) introduced block-level differential checkpointing and voltage triggers, they suffer from four hardware bottlenecks in real field deployments:

1. **Intra-Block Ciphertext Expansion:** Encrypting an entire 64-byte dirty block when only a few 32-bit words changed turns zero/unchanged words into high-entropy ciphertext, wasting **41%–50% of SPI FRAM write energy**.

2. **Capacitor-Aging Blindness:** Fixed-capacitance trigger equations ($C = \text{const}$) trigger too late and crash mid-save when field aging or temperature derating reduces capacitance by $\ge 20\%$.

3. **Full-Restore Boot Stalls:** Holding the CPU in reset until the entire checkpoint image streams back from serial FRAM delays wake-up by `0.7–2.7 ms`.

4. **Rollback & Glitch Vulnerability:** Static encryption keys on external serial FRAM remain vulnerable to mid-byte torn writes, checkpoint replay/rollback attacks, and brownout fault-injection glitches.

**PhoenixCore** resolves all four bottlenecks inside a compact **`925-LUT` (`4.4%` of Artix-7 `XC7A35T`) / `4.1 kGE` (`Sky130A`)** hardware IP core coupled to a `PicoRV32` (`RV32I`) processor, `16 KB` volatile SRAM (`256 × 64B` blocks), and `32 KB` SPI FRAM (`25 MHz`).

## 2. Four Core Micro-Architectural Innovations

| Module | Micro-Architectural Mechanism | Measured / Simulated Advantage | 
| ----- | ----- | ----- | 
| **1. `PC-WMC`** | **Pre-Crypto Sub-Block Word-Mask Compression:** 0-wait-state 256-bit block dirty bitmap + 1-cycle 16-bit active-word mask (`w_mask[15:0]`) that strips zero/unchanged 32-bit words *before* AES stream encryption. | **41.3%–49.9% lower save energy** than DiCA'23 / ISQED'25 (`83.7%–96.4%` below SW full-copy). | 
| **2. `SH-PDAT`** | **Self-Healing Closed-Loop** $\Delta V$ **Capacitor-Aging Trigger:** Latches $V_{\text{start}}$ and $V_{\text{end}}$ across every checkpoint to calibrate effective capacitance $C_{\text{eff}} = 2E_{\text{save}}/(V_{\text{start}}^2 - V_{\text{end}}^2)$ in hardware. | **Survives up to 45% capacitor aging** (`100 µF → 55 µF`), whereas fixed-$C$ triggers fail at $\le 80\,\mu\text{F}$. | 
| **3. `CLJ-HPR`** | **Commit-Last Journal + 2-Block Hot-Priority Restore:** Appends a 16-byte Atomic Commit Frame (`0x5043`) last and restores CPU registers + active Stack/Data blocks *first* on reboot. | **`89.6 µs` wake-up time-to-first-instruction** (`7.9×–29.8×` faster resume) & `668/668` torn-write survival. | 
| **4. `Zeroizer`** | **Monotonic Anti-Rollback MAC + 1-Cycle Key Zeroizer:** Binds every Commit MAC to a 64-bit monotonic generation counter and wipes `1,408` key/state register bits in **1 clock cycle (`20 ns`)** on tamper. | **`166/166` (`100%`) detection** of bit-flip tamper and stale-generation rollback attacks. | 

## 3. Repository Structure

```
PhoenixCore-M2026-165/
├── README.md                          # Setup, build, and 1-command reproducibility guide
├── requirements.txt                   # Python dependencies (standard library + matplotlib for plots)
├── run_ubuntu_flow.sh                 # 1-command automation script (Python Sim + Icarus + Yosys + GTKWave)
├── rtl/
│   └── phoenixcore_top.v              # Synthesizable RV32I + PhoenixCore SoC RTL (Verilog-2005)
├── tb/
│   └── tb_phoenixcore_top.v           # Self-checking 4-stage hardware verification testbench
├── sim/
│   └── phoenixcore_brownout_sim.py    # 1,000-trial seeded brownout, 3-way benchmark, & cap-aging simulator
├── fpga/
│   └── basys3_phoenixcore.xdc         # Xilinx Vivado pin & timing constraints for Digilent Basys3 (XC7A35T)
├── asic/
│   ├── synth_phoenixcore.ys           # Yosys open-source gate-level synthesis script
│   └── config.json                    # OpenLane 2 configuration for SkyWater 130 nm (Sky130A) RTL-to-GDSII
└── docs/
    ├── M2026-165_PhoenixCore_DPR.pdf  # Final IEEE Two-Column Detailed Project Report (DPR)
    └── M2026-165_PhoenixCore_DPR.docx # Editable DPR source document

```

## 4. Quick-Start & Reproducibility Guide (Evaluator Clean-Environment Setup)

### Prerequisites (Ubuntu 22.04 / 24.04 LTS or WSL2)

```
sudo apt update
sudo apt install -y python3 python3-pip iverilog gtkwave yosys

```

### Option A: One-Command Full Verification & Synthesis Flow

From the repository root (or flat working directory), execute:

```
chmod +x run_ubuntu_flow.sh
./run_ubuntu_flow.sh

```

### Option B: Step-by-Step Manual Execution

1. **Run the 1,000-Trial Brownout, 3-Way Benchmark, & Capacitor-Aging Simulator:**

   ```
   python3 phoenixcore_brownout_sim.py
   
   ```

   *Outputs deterministic JSON metrics for Sparse (`12.5%`), Moderate (`25.0%`), and Dense (`50.0%`) workloads, the `100 µF → 55 µF` capacitor-aging sweep, and `1,000/1,000` seeded fault-injection trials (`Seed = 2026165`).*

2. **Run Cycle-Accurate RTL Simulation (`iverilog` + `vvp`) & Inspect Waveforms (`gtkwave`):**

   ```
   iverilog -o phoenixcore_sim.vvp phoenixcore_top.v tb_phoenixcore_top.v
   vvp phoenixcore_sim.vvp
   gtkwave phoenixcore_wave.vcd
   
   ```

   *Verifies all 4 hardware tests (`[PASS] 4 / 4 HARDWARE VERIFICATION TESTS PASSED`): (1) 0-cycle bus-snoop dirty tracking, (2) pre-crypto word-masked commit &* $+\text{25 mV}$ $\Delta V$ *aging calibration, (3) mid-save torn-write rollback to Generation 1, and (4) 1-cycle (`20 ns`) AES key zeroization on tamper.*

3. **Run Open-Source Gate-Level Synthesis (`yosys`) & Sky130A ASIC Flow (`openlane`):**

   ```
   yosys -s synth_phoenixcore.ys
   # If OpenLane 2 is installed:
   openlane config.json
   
   ```

4. **Digilent Basys3 (`XC7A35T`) FPGA Synthesis (Xilinx Vivado):**

   * Create a new RTL project in Vivado targeting `xc7a35tcpg236-1` (Digilent Basys3).

   * Add `phoenixcore_top.v` as design source and `basys3_phoenixcore.xdc` as constraints.

   * Use `SW0 = 0` for **On-Chip 32 KB BRAM FRAM Loopback Emulation** (single-USB-cable lab testing with `BTNC` = brownout cut and `BTND` = tamper zeroize) or `SW0 = 1` for **External PMOD Header `JA` SPI FRAM (`MB85RS256B`)**.

## 5. Benchmark Summary (50 MHz Core, 25 MHz SPI FRAM, 100 µF Buffer)

| Workload / Scheme | FRAM Bytes Written | Save Latency | Save Energy | Wake-Up Latency | Capacitor-Aging Survival (`100 → 55 µF`) | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| **SW Full-Copy Baseline** | `16,536 B` | `11.244 ms` | `211.51 µJ` | `2,670.1 µs` | Fails at $\le 90\,\mu\text{F}$ (`10%` loss) | 
| **Case 1 (Sparse 12.5%): DiCA / ISQED'25** | `2,456 B` | `0.818 ms` | `15.38 µJ` | `704.0 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) | 
| **Case 1 (Sparse 12.5%): PhoenixCore (Ours)** | **`1,240 B` (`-49.5%`)** | **`0.409 ms`** | **`7.70 µJ` (`-49.9%`)** | **`89.6 µs` (`7.9×`)** | **Survives down to `55 µF` (`45%` loss)** | 
| **Case 2 (Moderate 25%): DiCA / ISQED'25** | `4,760 B` | `1.586 ms` | `29.83 µJ` | `1,359.4 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) | 
| **Case 2 (Moderate 25%): PhoenixCore (Ours)** | **`2,584 B` (`-45.7%`)** | **`0.855 ms`** | **`16.08 µJ` (`-46.1%`)** | **`89.6 µs` (`15.2×`)** | **Survives down to `55 µF` (`45%` loss)** | 
| **Case 3 (Dense 50%): DiCA / ISQED'25** | `9,368 B` | `3.122 ms` | `58.72 µJ` | `2,670.1 µs` | Fails at $\le 80\,\mu\text{F}$ (`20%` loss) | 
| **Case 3 (Dense 50%): PhoenixCore (Ours)** | **`5,528 B` (`-41.0%`)** | **`1.831 ms`** | **`34.45 µJ` (`-41.3%`)** | **`89.6 µs` (`29.8×`)** | **Survives down to `55 µF` (`45%` loss)** | 

## 6. Team Roster (`NEXUS V` — `M2026-165`)

* **Akif Mohamed J (Team Lead):** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli — *SoC Architecture, PC-WMC/CLJ RTL, AES-128 Zeroizer, & Sky130A Physical Design* (`akifmohamed2217@gmail.com`)

* **Nandikha M:** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli — *Pre-Silicon Verification, 1,000-Trial Brownout/Aging Regression, & Vivado STA/Power* (`sisterapk1237@gmail.com`)

* **Mariam Farisha D:** B.E. ECE (IV Year), Government College of Engineering, Srirangam, Tiruchirappalli — *Bare-Metal RISC-V C Workloads, Hot-Restore Boot Firmware, & UART Telemetry* (`mariyamfarisha90@gmail.com`)

* **Hiran Sruthi N:** B.E. ECE (IV Year), Alagappa Chettiar Government College of Engineering & Technology, Karaikudi — *SH-PDAT* $\Delta V$ *Aging Calibrator RTL & Basys3 7-Segment/PMOD Integration* (`hiransruthi11mar@gmail.com`)

* **Dharshini K:** B.E. ECE (IV Year), Alagappa Chettiar Government College of Engineering & Technology, Karaikudi — *BQ25570 Harvester + 100 µF Supercap + MB85RS256B KiCad Schematic, 4-Layer PCB, & BOM* (`dharshinisuyam11@gmail.com`)