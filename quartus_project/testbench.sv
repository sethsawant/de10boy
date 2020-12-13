module test ();

timeunit 10ns;	// Half Clk cycle at 50 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;

logic Clk;
logic sim_cpu_clock;
logic [1:0] KEY;
logic reset;



assign KEY[0] = ~reset;
de10boy gb (.Clk(Clk), 
            // .clock(sim_cpu_clock), 
            .KEY(KEY), .VGA_HS(), .VGA_VS(), .VGA_R(), .VGA_G(), .VGA_B() );

logic [15:0] PC,SP,HL;
logic [7:0] A,F,B,C,D,E,OR;
logic [15:0] MEM_ADDR;
logic [7:0] MEM_IN, MEM_OUT;
reg [24*8-1:0] OPCODE;

always_comb begin : INTERNAL_SIG_BREAKOUTS
    A = gb.cpu.A;
    F = gb.cpu.F;
    B = gb.cpu.B;
    C = gb.cpu.C;
    D = gb.cpu.D;
    E = gb.cpu.E;
    PC = gb.cpu.PC;
    SP = gb.cpu.SP;
    HL = gb.cpu.HL;
    OR = gb.cpu.OR;
    OPCODE = gb.cpu.opcode_str;
    MEM_IN = gb.cpu.data_in;
    MEM_OUT = gb.cpu.data_out;
    MEM_ADDR = gb.cpu.mem_addr;
end


    
integer ErrorCnt = 0;

always begin : CLK_CLOCK_GENERATION
    #5 Clk = ~Clk;
end

always begin : CLOCK_GENERATION
    #25 sim_cpu_clock = ~sim_cpu_clock;
end

initial begin: CLOCK_INITIALIZATION
    Clk = 0;
    sim_cpu_clock = 0;
end 

task testFailed(input string str);
    $display("[FAILED] %s", str);
    ErrorCnt++;
endtask 


initial begin: TESTS

force gb.clock = sim_cpu_clock;
force gb.memclock = Clk;



reset = 1'b1;
#70 reset = 1'b0;

force gb.cpu.PC_new = 16'h000c;
force gb.cpu.PC_ld = 1'b1;
force gb.cpu.SP_new = 16'hFFFE;
force gb.cpu.SP_ld = 1'b1;
#40
force gb.cpu.PC_new = 16'h000d;
#20
release gb.cpu.PC_new;
release gb.cpu.PC_ld;
release gb.cpu.SP_new;
release gb.cpu.SP_ld;


if (ErrorCnt == 0)
    $display("All tests passed.");
else
    $display("%d error(s) found!", ErrorCnt);


end

endmodule