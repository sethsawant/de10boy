/* Memory map of Game Boy. Contains game ROM data, internal RAM, and boot ROM. */

module memory (
    input logic [15:0] addr,
    input logic clock,
    input logic wren,
    input logic [7:0] data_in,
    output logic [7:0] data_out
);

logic ram_write_en;  // enables writing to RAM
logic boot_rom_en; // flag to enable boot rom from 0x0000 to 0x00FF, @TODO 
logic [7:0] boot_rom_out, cart_rom_out, ram_out; // wires for multiplexing memory

ram	ram_inst ( // Game Boy's internal RAM
	.address ( addr[15:0] ),
	.clock ( clock ),
	.data ( data_in ),
	.wren ( wren ),
	.q ( ram_out )
	);

boot_rom boot_rom_inst ( // Game Boy boot ROM
	.address ( addr[7:0] ),
	.clock ( clock ),
	.q ( boot_rom_out )
	);

cart_rom cart_rom_inst ( // Game Pak ROM
	.address ( addr[14:0] ),
	.clock ( clock ),
	.q ( cart_rom_out )
	);

always_comb begin : MEM_SWITCHING
	boot_rom_en = 1'b1; // TODO enable turning on and off boot ROM
	if (addr <= 16'h7FFF) begin // if in bottom 32KB 
		if (boot_rom_en && addr <= 16'h0100) data_out = boot_rom_out; // if boot room enabled and address is in boot rom range
		else data_out = cart_rom_out; // otherwise read from the cartridge rom
	end
	else data_out = ram_out;
end
    
endmodule