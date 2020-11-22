module cpu_testbench ();

timeunit 100ns;	// Half clock cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;
    
logic clock, memclock, reset;
logic [7:0] data_in;
logic [7:0] data_out;
logic [15:0] mem_addr;
logic mem_wren;

cpu cpu_inst (.*);

logic [15:0] cpu_addr; 
logic [12:0] ppu_addr;
logic boot_rom_en;
logic cpu_wren;
logic ppu_vram_read_en, ppu_oam_read_en;
logic [7:0] cpu_data_in, ppu_data_in;
logic [7:0] cpu_data_out, ppu_data_out;

memory mem_inst (.*, .clock(memclock));

always_comb begin : blockName
    cpu_addr = mem_addr;
    ppu_addr = 13'h0;
    boot_rom_en = 1'b1;
    cpu_wren = mem_wren;
    ppu_vram_read_en = 1'b0;
    ppu_oam_read_en = 1'b0;
    cpu_data_in = data_out;
    data_in = cpu_data_out;


end

integer ErrorCnt = 0;

always begin : CLOCK_GENERATION
    #2 clock = ~clock;
end

always begin : MEMCLOCK_GENERATION
    #1 memclock = ~memclock;
end


initial begin: CLOCK_INITIALIZATION
    clock = 0;
    memclock = 0;
end 

task testFailed(input string str);
    $display("[FAILED] %s", str);
    ErrorCnt++;
endtask 


initial begin: TESTS

reset = 1'b0;

reset = 1'b1;
#4 reset = 1'b0;



if (ErrorCnt == 0)
    $display("All tests passed.");
else
    $display("%d error(s) found!", ErrorCnt);


end

endmodule