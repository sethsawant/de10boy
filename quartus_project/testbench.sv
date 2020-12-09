module de10boy_testbench ();

timeunit 10ns;	// Half Clk cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;

logic Clk;
logic [1:0] KEY;
logic reset;

assign KEY[0] = ~reset;
de10boy gb (.Clk(Clk), .KEY(KEY), .VGA_HS(), .VGA_VS(), .VGA_R(), .VGA_G(), .VGA_B() );

logic [15:0] PC,SP,HL;
logic [7:0] A,F,B,C,D,E;
logic [15:0] MEM_ADDR;
logic [7:0] MEM_IN, MEM_OUT;
reg [24*8-1:0] OPCODE;



always_comb begin : INTERNAL_SIG_BREAKOUTS
    A = gb.cpu.A;
    F = gb.cpu.F;
    B = gb.cpu.A;
    C = gb.cpu.A;
    D = gb.cpu.A;
    E = gb.cpu.A;
    PC = gb.cpu.PC;
    SP = gb.cpu.SP;
    HL = gb.cpu.HL;
    OPCODE = gb.cpu.opcode_str;
    MEM_IN = gb.cpu.data_in;
    MEM_OUT = gb.cpu.data_out;
    MEM_ADDR = gb.cpu.mem_addr;
end

// always_comb begin : PLL_SIM
//     gb.clock = cpu_clock;
//     gb.memclock = mem_clock;
// end
    
integer ErrorCnt = 0;

always begin : CLOCK_GENERATION
    #1 Clk = ~Clk;
end

initial begin: CLOCK_INITIALIZATION
    Clk = 0;
end 

task testFailed(input string str);
    $display("[FAILED] %s", str);
    ErrorCnt++;
endtask 


initial begin: TESTS

reset = 1'b1;
#10 reset = 1'b0;

if (ErrorCnt == 0)
    $display("All tests passed.");
else
    $display("%d error(s) found!", ErrorCnt);


end

endmodule