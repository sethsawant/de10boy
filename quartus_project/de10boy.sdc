# Constrain clock port clk with a 10-ns requirement

create_clock -period "50.0 MHz" [get_ports Clk]
create_clock -period "25.0 MHz" [get_ports vga_controller:vga|clkdiv]
create_clock -period "25.0 Hz" [get_ports ppu:ppu|ppu_mode.VBLANK]
derive_pll_clocks
derive_clock_uncertainty


# Constrain the input I/O path

set_input_delay -clock {Clk} -max 3 [all_inputs]
set_input_delay -clock {Clk} -min 2 [all_inputs]

set_input_delay -clock {vga_controller:vga|clkdiv} -max 3 [all_inputs]
set_input_delay -clock {vga_controller:vga|clkdiv} -min 2 [all_inputs]

set_input_delay -clock {ppu:ppu|ppu_mode.VBLANK} -max 3 [all_inputs]
set_input_delay -clock {ppu:ppu|ppu_mode.VBLANK} -min 2 [all_inputs]


# Constrain the output I/O path

set_output_delay -clock {Clk} -max 3 [all_outputs]
set_output_delay -clock {Clk} -min 2 [all_outputs]


set_output_delay -clock {vga_controller:vga|clkdiv} -max 3 [all_outputs]
set_output_delay -clock {vga_controller:vga|clkdiv} -min 2 [all_outputs]

set_input_delay -clock {ppu:ppu|ppu_mode.VBLANK} -max 3 [all_inputs]
set_input_delay -clock {ppu:ppu|ppu_mode.VBLANK} -min 2 [all_inputs]