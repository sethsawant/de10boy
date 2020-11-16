module memory_testbench ();

timeunit 100ns;	// Half clock cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;
    
    logic [15:0] cpu_addr; 
	logic [12:0] ppu_addr;
    logic clock;
	logic boot_rom_en;
    logic cpu_wren;
	logic ppu_vram_read_en, ppu_oam_read_en;
    logic [7:0] cpu_data_in, ppu_data_in;
    logic [7:0] cpu_data_out, ppu_data_out;

memory mem_dut (.*);

integer ErrorCnt = 0;

always begin : CLOCK_GENERATION
#1 clock = ~clock;
end

initial begin: CLOCK_INITIALIZATION
    clock = 0;
end 

task cpuWrite(input logic [15:0] addr, [7:0] data);
    cpu_wren = 1'b1;
    cpu_addr = addr;
    cpu_data_in = data;
    #2 cpu_wren = 1'b0;
endtask 

task cpuRead(input logic [15:0] addr);
    cpu_addr = addr;
    #2;
endtask 

task ppuReadVRAM(input logic [15:0] addr);
    ppu_vram_read_en = 1'b1;
    ppu_addr = addr;
    #2
    ppu_vram_read_en = 1'b0;
endtask 

task ppuReadOAM(input logic [15:0] addr);
    ppu_oam_read_en = 1'b1;
    ppu_addr = addr;
    #2
    ppu_oam_read_en = 1'b0;
endtask 

task testFailed(input string str);
    $display("[FAILED] %s", str);
    ErrorCnt++;
endtask 


initial begin: TESTS

boot_rom_en = 1'b0;
cpu_wren = 1'b0;
cpu_addr = 16'h0000;
ppu_addr = 16'h0000;
ppu_vram_read_en = 1'b0; 
ppu_oam_read_en = 1'b0;
cpu_data_in = 8'h0;
ppu_data_in = 8'h0;

// Boot ROM / Cart ROM Tests

boot_rom_en = 1'b1; 
cpuRead(0'h0000);
if (cpu_data_out != 8'h31) testFailed("Boot ROM enabled test");
cpuRead(0'h0001);
if (cpu_data_out != 8'hfe) testFailed("Boot ROM enabled test");
cpuRead(0'h0002);
if (cpu_data_out != 8'hff) testFailed("Boot ROM enabled test");
boot_rom_en = 1'b0;
cpuRead(0'h0000);
if (cpu_data_out != 8'hc3) testFailed("Boot ROM disabled test");
cpuRead(0'h0001);
if (cpu_data_out != 8'he8) testFailed("Boot ROM disabled test");
cpuRead(0'h0002);
if (cpu_data_out != 8'h01) testFailed("Boot ROM disabled test");

// VRAM Tests

ppu_vram_read_en = 1'b0;
cpuWrite(16'h8000, 8'h12);
cpuWrite(16'h8001, 8'h34);
cpuRead(16'h8000);
if (cpu_data_out != 8'h12) testFailed("CPU VRAM write test");
cpuRead(16'h8001);
if (cpu_data_out != 8'h34) testFailed("CPU VRAM write test");

ppuReadVRAM(16'h8001);
if (ppu_data_out != 8'h34) testFailed("PPU VRAM read test");

ppu_vram_read_en = 1'b1;
#2 cpuRead(16'h8001); // should be blocked from reading vram
if (cpu_data_out != 8'hFF) testFailed("VRAM read blocking behavior test");
cpuRead(0'h0000); // should still be able to read other memory regions
if (cpu_data_out != 8'hc3) testFailed("VRAM read blocking behavior test");

cpuWrite(16'h8001, 8'h78); // should be blocked from writing 
ppu_vram_read_en = 1'b0;
cpuRead(16'h8001); // should see old value after ppu is done reading VRAM
if (cpu_data_out != 8'h34) testFailed("VRAM write blocking behavior test");

// Work RAM Tests

cpuWrite(16'hC000, 8'h12);
cpuWrite(16'hC001, 8'h34);
cpuRead(16'hC000);
if (cpu_data_out != 8'h12) testFailed("CPU work RAM write test");
cpuRead(16'hC001);
if (cpu_data_out != 8'h34) testFailed("CPU work RAM write test");

// Echo RAM test

cpuWrite(16'hC000, 8'h12);
cpuWrite(16'hC001, 8'h34);
cpuRead(16'hE000);
if (cpu_data_out != 8'h12) testFailed("CPU echo RAM write test");
cpuRead(16'hE001);
if (cpu_data_out != 8'h34) testFailed("CPU echo RAM write test");

// OAM Tests

ppu_oam_read_en = 1'b0;
cpuWrite(16'hFE00, 8'h12);
cpuWrite(16'hFE01, 8'h34);
cpuRead(16'hFE00);
if (cpu_data_out != 8'h12) testFailed("CPU OAM write test");
cpuRead(16'hFE01);
if (cpu_data_out != 8'h34) testFailed("CPU OAM write test");

ppuReadOAM(16'hFE01);
if (ppu_data_out != 8'h34) testFailed("PPU OAM read test");

ppu_oam_read_en = 1'b1;
#2 cpuRead(16'hFE01); // should be blocked from reading vram
if (cpu_data_out != 8'hFF) testFailed("OAM read blocking behavior test");
cpuRead(16'h0000); // should still be able to read other memory regions
if (cpu_data_out != 8'hc3) testFailed("OAM read blocking behavior test");

cpuWrite(16'hFE01, 8'h78); // should be blocked from writing 
ppu_oam_read_en = 1'b0;
cpuRead(16'hFE01); // should see old value after ppu is done reading VRAM
if (cpu_data_out != 8'h34) testFailed("OAM write blocking behavior test");


    

// for (int i = 0; i<10; i++) begin
//     #2 cpu_addr = cpu_addr + 1'b1;
// end

//
/////////////////////////////////////////////

/////////////////////////////////////////////

if (ErrorCnt == 0)
    $display("All tests passed.");
else
    $display("%d error(s) found!", ErrorCnt);


end

endmodule