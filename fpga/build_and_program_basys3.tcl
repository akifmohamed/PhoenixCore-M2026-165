# ============================================================================
# File        : build_and_program_basys3.tcl
# Project     : PhoenixCore: Secure Energy-Aware Checkpoint Engine (M2026-165)
# Team        : NEXUS V (GCE Srirangam & ACGCET Karaikudi)
# Target FPGA : Digilent Basys3 (Xilinx Artix-7 XC7A35T-1CPG236C)
# Usage       : vivado -mode batch -source build_and_program_basys3.tcl
# ============================================================================

set part_num "xc7a35tcpg236-1"
set out_dir  "./vivado_build"
file mkdir $out_dir

puts "================================================================"
puts "  PHOENIXCORE (M2026-165) VIVADO ARTIX-7 BITSTREAM BUILD FLOW"
puts "================================================================"

# 1. Read Synthesizable Verilog RTL & Basys3 Physical Constraints
if {[file exists "./rtl/phoenixcore_asic_macro.v"]} {
    read_verilog "./rtl/phoenixcore_asic_macro.v"
    read_verilog "./rtl/phoenixcore_top.v"
} else {
    read_verilog "./phoenixcore_asic_macro.v"
    read_verilog "./phoenixcore_top.v"
}

if {[file exists "./fpga/basys3_phoenixcore.xdc"]} {
    read_xdc "./fpga/basys3_phoenixcore.xdc"
} else {
    read_xdc "./basys3_phoenixcore.xdc"
}

# 2. Run Xilinx Artix-7 Synthesis
synth_design -top phoenixcore_top -part $part_num
report_utilization -file "$out_dir/vivado_utilization_synth.rpt"
report_timing_summary -file "$out_dir/vivado_timing_synth.rpt"

# 3. Optimize, Place, and Route
opt_design
place_design
phys_opt_design
route_design

# 4. Generate Signoff Utilization, Timing, DRC, and Power Reports
report_utilization -file "$out_dir/vivado_utilization_routed.rpt"
report_timing_summary -file "$out_dir/vivado_timing_routed.rpt"
report_power -file "$out_dir/vivado_power_routed.rpt"
report_drc -file "$out_dir/vivado_drc_routed.rpt"

# 5. Write Compressed Bitstream (.bit)
write_bitstream -force "$out_dir/phoenixcore_top.bit"
puts "================================================================"
puts "  [SUCCESS] Bitstream generated: $out_dir/phoenixcore_top.bit"
puts "================================================================"

# 6. Auto-Detect & Program Digilent Basys3 Board if Connected via USB-JTAG
if {[catch {
    open_hw_manager
    connect_hw_server -allow_non_jtag
    set targets [get_hw_targets]
    if {[llength $targets] > 0} {
        open_hw_target [lindex $targets 0]
        set dev [lindex [get_hw_devices xc7a35t_0] 0]
        current_hw_device $dev
        refresh_hw_device $dev
        set_property PROGRAM.FILE "$out_dir/phoenixcore_top.bit" $dev
        program_hw_devices $dev
        puts "================================================================"
        puts "  [SUCCESS] Digilent Basys3 (XC7A35T) Programmed Live over USB!"
        puts "================================================================"
    } else {
        puts "  [INFO] No USB-JTAG Basys3 board detected right now."
        puts "         Bitstream is saved at: $out_dir/phoenixcore_top.bit"
    }
    close_hw_manager
} err]} {
    puts "  [INFO] Hardware Manager skipped ($err). Bitstream ready at $out_dir/phoenixcore_top.bit"
}
exit
