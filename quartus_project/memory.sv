/* Memory map of Game Boy. Contains game ROM data, internal RAM, and boot ROM. */

module memory (
    input logic [15:0] cpu_addr, 
	input logic [12:0] ppu_addr,
    input logic clock,
	input logic boot_rom_en,
    input logic cpu_wren,
	input logic ppu_vram_read_en, ppu_oam_read_en,
    input logic [7:0] cpu_data_in, ppu_data_in,
    output logic [7:0] cpu_data_out, ppu_data_out
);



logic [7:0] boot_rom_out, cart_rom_out; // wires for multiplexing memory
logic work_ram_wren, video_ram_wren, external_ram_wren, oam_wren, high_ram_wren;  // enables writing to RAM
logic [12:0] video_ram_addr;
logic [7:0] oam_addr;
logic [7:0] work_ram_in, video_ram_in, external_ram_in, oam_in, high_ram_in;
logic [7:0] work_ram_out, video_ram_out, external_ram_out, oam_out, high_ram_out;


boot_rom boot_rom_inst ( // Game Boy boot ROM (256 B)
	.address ( cpu_addr[7:0] ),
	.clock ( clock ),
	.q ( boot_rom_out )
	);

cart_rom cart_rom_inst ( // Game Pak ROM (32 KB)
	.address ( cpu_addr[14:0] ),
	.clock ( clock ),
	.q ( cart_rom_out )
	);

ram_8k video_ram ( // Game Boy's internal video RAM (8 KB)
	.address ( video_ram_addr[12:0] ),
	.clock ( clock ),
	.data ( video_ram_in ),
	.wren ( video_ram_wren ),
	.q ( video_ram_out )
	);

ram_8k external_ram ( // external RAM on Gameboy cart (8 KB)
	.address ( cpu_addr[12:0] ),
	.clock ( clock ),
	.data ( external_ram_in ),
	.wren ( external_ram_wren ),
	.q ( external_ram_out )
	);

ram_8k work_ram ( // Game Boy's internal work RAM (8 KB)
	.address ( cpu_addr[12:0] ),
	.clock ( clock ),
	.data ( work_ram_in ),
	.wren ( work_ram_wren ),
	.q ( work_ram_out )
	);

ram_256 oam ( // object attribrute memory, used by PPU to store sprites (160 B only are used)
	.address ( oam_addr ),
	.clock ( clock ),
	.data ( oam_in ),
	.wren ( oam_wren ),
	.q ( oam_out )
	);

ram_256 high_ram ( // high RAM (HRAM) (127 B only are used)
	.address ( cpu_addr[7:0] ),
	.clock ( clock ),
	.data ( high_ram_in ),
	.wren ( high_ram_wren ),
	.q ( high_ram_out )
	);



always_comb begin : MEMORY_MAP

	video_ram_in = ppu_data_in; // by default ppu has VRAM control
	video_ram_addr = ppu_addr[12:0];
	ppu_data_out = video_ram_out; // PPU always reads video RAM
	video_ram_wren = 1'b0; // PPU does not write the video RAM


	oam_in = ppu_data_in; // by default ppu has OAM control
	oam_addr = ppu_addr[7:0];
	ppu_data_out = oam_out; // PPU always reads OAM
	oam_wren = 1'b0; // PPU does not write the OAM

	// selects what region of memory PPU is reading from
	if (ppu_oam_read_en && ~ppu_vram_read_en) ppu_data_out = oam_out;
	else if (~ppu_oam_read_en && ppu_vram_read_en) ppu_data_out = video_ram_out;

	// disable writes by default
	external_ram_wren = 1'b0;
	work_ram_wren = 1'b0;
	high_ram_wren = 1'b0;

	external_ram_in = cpu_data_in;
	work_ram_in = cpu_data_in;
	high_ram_in = cpu_data_in;

	cpu_data_out = 8'hXX;

	// cart ROM 
	if (cpu_addr >= 16'h0000 && cpu_addr <= 16'h7FFF) 
		begin 
			if (boot_rom_en && cpu_addr <= 16'h0100) cpu_data_out = boot_rom_out; 
			else cpu_data_out = cart_rom_out;
		end

	// video RAM
	if (cpu_addr >= 16'h8000 && cpu_addr <= 16'h9FFF) 
		begin 
			if (ppu_vram_read_en) cpu_data_out = 8'hFF; // if PPU is reading the VRAM, block CPU
			else 
			begin // otherwise grant control to CPU
				cpu_data_out = video_ram_out; 
				video_ram_in = cpu_data_in; 
				video_ram_addr = cpu_addr[12:0];
				video_ram_wren = cpu_wren;
			end
		end

	// external RAM
	if (cpu_addr >= 16'hA000 && cpu_addr <= 16'hBFFF) 
		begin 
			external_ram_wren = cpu_wren;
			cpu_data_out = external_ram_out;
		end

	// work RAM
	if (cpu_addr >= 16'hC000 && cpu_addr <= 16'hCFFF) 
		begin 
			work_ram_wren = cpu_wren;
			cpu_data_out = work_ram_out;
		end
	
	// echo RAM of work RAM (maps to C000~DDFF)
	if (cpu_addr >= 16'hE000 && cpu_addr <= 16'hFDFF) 
		begin 
			work_ram_wren = cpu_wren;
			cpu_data_out = work_ram_out;
		end
	
	// OAM 
	if (cpu_addr >= 16'hFE00 && cpu_addr <= 16'hFE9F) 
		begin 
			if (ppu_oam_read_en) cpu_data_out = 8'hFF; // if PPU is reading the OAM, block CPU
			else 
			begin // otherwise grant control to CPU
				cpu_data_out = oam_out; 
				oam_in = cpu_data_in; 
				oam_addr = cpu_addr[7:0];
				oam_wren = cpu_wren;
			end
		end

	// Not Usable
	if (cpu_addr >= 16'hFEA0 && cpu_addr <= 16'hFEFF) 
		begin 
			cpu_data_out = 8'hFF;
		end

	// I/0 #TODO implement I/0
	if (cpu_addr >= 16'hFF00 && cpu_addr <= 16'hFF7F) 
		begin 
			cpu_data_out = 8'hFF;
		end

	// HRAM
	if (cpu_addr >= 16'hFF80  && cpu_addr <= 16'hFFFE) 
		begin 
			high_ram_wren = cpu_wren;
			cpu_data_out = high_ram_out;
		end

	// Interrupts Enable Register (IE) #TODO 
	if (cpu_addr == 16'hFFFF ) 
		begin
			cpu_data_out = 8'h00;
		end

end


endmodule