#!/usr/bin/env bash
# =============================================================================
# File        : run_ubuntu_flow.sh
# Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
# Team        : NEXUS V
# Description : 1-Command Ubuntu Open-Source Flow:
#                 Step 1: Run Python 1,000-Trial Brownout & Aging Simulator
#                 Step 2: Compile & Run Verilog RTL in Icarus Verilog (iverilog)
#                 Step 3: Synthesize RTL in Yosys (Gate/Cell Count & Netlist)
#                 Step 4: Generate OpenLane 2 Sky130A config.json
#                 Step 5: Launch GTKWave with pre-selected signals
# =============================================================================
set -e

echo "======================================================================"
echo " PHOENIXCORE (M2026-165 | NEXUS V) — UBUNTU OPEN-SOURCE VLSI FLOW"
echo "======================================================================"

# Step 1: Python 1,000-Trial Brownout & 3-Way Comparison Simulator
if command -v python3 >/dev/null 2>&1; then
    echo "[1/4] Running 1,000-Trial Python Brownout & Aging Simulator..."
    python3 phoenixcore_brownout_sim.py > sim_1000_trials_report.json
    echo "  -> Saved 1,000-trial JSON metrics to sim_1000_trials_report.json"
fi

# Step 2: Icarus Verilog Compilation & Cycle-Accurate Waveform Simulation
if command -v iverilog >/dev/null 2>&1; then
    echo "[2/4] Compiling Synthesizable RTL + Testbench with Icarus Verilog..."
    iverilog -o phoenixcore_sim.vvp phoenixcore_top.v tb_phoenixcore_top.v
    vvp phoenixcore_sim.vvp | tee rtl_verification_log.txt
else
    echo "[!] iverilog not found. Install on Ubuntu with: sudo apt update && sudo apt install -y iverilog gtkwave yosys"
    exit 1
fi

# Step 3: Yosys Open-Source Gate-Level Synthesis & Area/Cell Report
if command -v yosys >/dev/null 2>&1; then
    echo "[3/4] Running Yosys Open-Source RTL Synthesis..."
    cat << 'EOF' > synth_phoenixcore.ys
read_verilog phoenixcore_top.v
hierarchy -check -top phoenixcore_top
proc; opt; fsm; opt; memory; opt
techmap; opt
dfflibmap -liberty +/simcells.v
abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX
clean
stat
write_verilog -noattr phoenixcore_synth_netlist.v
write_json phoenixcore_synth.json
EOF
    yosys -s synth_phoenixcore.ys | tee yosys_synthesis_report.txt
    echo "  -> Saved Yosys synthesis report to yosys_synthesis_report.txt"
fi

# Step 4: Generate OpenLane 2 Configuration File (Sky130A RTL-to-GDSII)
cat << 'EOF' > config.json
{
  "DESIGN_NAME": "phoenixcore_top",
  "VERILOG_FILES": ["dir::phoenixcore_top.v"],
  "CLOCK_PORT": "clk_50mhz",
  "CLOCK_PERIOD": 10.0,
  "FP_CORE_UTIL": 45,
  "PL_TARGET_DENSITY_PCT": 50,
  "SYNTH_STRATEGY": "AREA 0"
}
EOF
echo "[4/4] Generated OpenLane 2 Sky130A configuration: config.json"
echo "  -> To run OpenLane 2 RTL-to-GDSII on Ubuntu: openlane config.json"

# Optional: Launch GTKWave if running in a GUI session
if [ -n "$DISPLAY" ] && command -v gtkwave >/dev/null 2>&1; then
    echo "Launching GTKWave with phoenixcore_wave.vcd..."
    gtkwave phoenixcore_wave.vcd &
fi
