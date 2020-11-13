

module memory_testbench ();

timeunit 10ns;	// Half clock cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;
    
logic [15:0] addr;
logic clock;
logic wren;
logic [7:0] data_in;
logic [7:0] data_out;

memory mem_dut (.*);

integer ErrorCnt = 0;

always begin : CLOCK_GENERATION
#1 clock = ~clock;
end

initial begin: CLOCK_INITIALIZATION
    clock = 0;
end 


initial begin: TESTS

wren = 1'b0;
addr = 16'h0104;
addr = 16'h00FD;
for (int i = 0; i<10; i++) begin
    #2 addr = addr + 1'b1;
end

//
/////////////////////////////////////////////

/////////////////////////////////////////////

if (ErrorCnt == 0)
    $display("All tests passed.");
else
    $display("%d error(s) found!", ErrorCnt);
end

endmodule

