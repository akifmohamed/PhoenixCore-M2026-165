#!/usr/bin/env bash
# =============================================================================
# File        : run_ubuntu_flow.sh
# Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
# Team        : NEXUS V
# Description : Complete End-to-End Ubuntu Open-Source Flow:
#                 [1/5] Python 1,000-Trial Brownout, 3-Way, & Cap-Aging Sim
#                 [2/5] Icarus Verilog Cycle-Accurate RTL Verification
#                 [3/5] Yosys ASIC IP Macro Gate-Level Synthesis (Sky130 Target)
#                 [4/5] Yosys Xilinx Artix-7 (Basys3 XC7A35T) FPGA Utilization
#                 [5/5] OpenLane 2 Sky130A High-Utilization (65%) Config
# =============================================================================
set -e

echo "======================================================================"
echo " PHOENIXCORE (M2026-165 | NEXUS V) — COMPLETE OPEN-SOURCE VLSI FLOW"
echo "======================================================================"

echo "[1/5] Running 1,000-Trial Python Brownout & Capacitor-Aging Simulator..."
python3 phoenixcore_brownout_sim.py > sim_1000_trials_report.json
echo "  -> Saved 1,000-trial JSON metrics to sim_1000_trials_report.json"

echo "[2/5] Compiling & Running Full Modular RTL in Icarus Verilog..."
iverilog -o phoenixcore_sim.vvp phoenixcore_asic_macro.v phoenixcore_top.v tb_phoenixcore_top.v
vvp phoenixcore_sim.vvp | tee rtl_verification_log.txt

echo "[3/5] Running Yosys Pure ASIC IP Macro Synthesis (phoenixcore_asic_macro)..."
cat << 'EOF' > synth_asic_macro.ys
read_verilog phoenixcore_asic_macro.v
hierarchy -check -top phoenixcore_asic_macro
synth -top phoenixcore_asic_macro
abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX
opt_clean
stat
write_verilog -noattr phoenixcore_asic_macro_netlist.v
write_json phoenixcore_asic_macro.json
EOF
yosys -s synth_asic_macro.ys | tee yosys_asic_macro_report.txt

echo "[4/5] Running Yosys Xilinx Artix-7 (Basys3 XC7A35T) FPGA Synthesis..."
cat << 'EOF' > synth_basys3_fpga.ys
read_verilog phoenixcore_asic_macro.v phoenixcore_top.v
synth_xilinx -top phoenixcore_top -family xc7
stat
EOF
yosys -s synth_basys3_fpga.ys | tee yosys_basys3_fpga_utilization.txt

echo "[5/5] Generating OpenLane 2 Sky130A High-Utilization (65%) config.json..."
cat << 'EOF' > config.json
{
  "DESIGN_NAME": "phoenixcore_asic_macro",
  "VERILOG_FILES": ["dir::phoenixcore_asic_macro.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 10.0,
  "FP_CORE_UTIL": 65,
  "PL_TARGET_DENSITY_PCT": 68,
  "SYNTH_STRATEGY": "AREA 0"
}
EOF
echo "======================================================================"
echo " ALL 5 FLOW STAGES COMPLETE!"
echo " -> RTL Sim Log          : rtl_verification_log.txt"
echo " -> ASIC Macro Report    : yosys_asic_macro_report.txt"
echo " -> Basys3 FPGA Report   : yosys_basys3_fpga_utilization.txt"
echo " -> OpenLane 2 Config    : config.json (65% Core Utilization)"
echo "======================================================================"
