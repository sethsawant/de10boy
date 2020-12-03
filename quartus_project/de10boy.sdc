# Constrain clock port clk with a 10-ns requirement

create_clock -period "4.0 MHz" [get_ports Clk]

derive_pll_clocks
derive_clock_uncertainty


# Constrain the input I/O path

set_input_delay -clock {Clk} -max 3 [all_inputs]
set_input_delay -clock {Clk} -min 2 [all_inputs]

# Constrain the output I/O path

set_output_delay -clock {Clk} -max 3 [all_outputs]
set_output_delay -clock {Clk} -min 2 [all_outputs]