create_clock -name clk -period 20.0 [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]
set_clock_transition  0.10 [get_clocks clk]

set clk_idx [lsearch -exact [all_inputs] [get_ports clk]]
set all_in_no_clk [lreplace [all_inputs] $clk_idx $clk_idx]

set_input_delay  -max 4.0 -clock [get_clocks clk] $all_in_no_clk
set_input_delay  -min 2.0 -clock [get_clocks clk] $all_in_no_clk
set_output_delay -max 4.0 -clock [get_clocks clk] [all_outputs]
set_output_delay -min 1.0 -clock [get_clocks clk] [all_outputs]

set_input_transition 0.08 $all_in_no_clk
set_load 0.005 [all_outputs]
set_max_fanout 4 [current_design]
set_max_transition 1.50 [current_design]
