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

boot_rom boot_rom_inst (.address(mem_addr[7:0]), .clock(memclock), .q(data_in));

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