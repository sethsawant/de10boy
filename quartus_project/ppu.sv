module ppu (
    input logic [7:0] data_in,
    input logic clock, cpu_clock, reset,
    output logic [12:0]ppu_mem_addr,
    output logic [7:0] X_out, Y_out,
    output logic [1:0] pixel_out,
    output logic frame_wren, vblank, vram_access, oam_access, ppu_read_mode
);


// Period	                GPU mode number	 Time spent (clocks)

// Scanline (accessing OAM)	    2	            80
// Scanline (accessing VRAM)	3	            172
// Horizontal blank	            0	            204
// One line (scan and blank)		            456
// Vertical blank	            1	            4560 (10 lines)
// Full frame (scans and vblank)		        70224

enum logic [1:0] {HBLANK = 2'd0, VBLANK = 2'd1, OAM_SEARCH = 2'd2, ACTIVE_PICTURE = 2'd3} ppu_mode, next_ppu_mode;

logic [16:0] cycles; // number of CPU cycles executed so far
logic [7:0] line; // current line of the frame PPU is currently working on

always_ff @ (posedge cpu_clock)
begin
	if (reset || (cycles == 17'd70224)) begin // reset counter at the end of a full frame
		cycles <= 17'h0;
        ppu_mode <= OAM_SEARCH;
    end
	else begin
		cycles <= cycles + 2'h2; // add two per CPU clock due to implementation of CPU running at half the freqeuncy of actual GB CPU
        ppu_mode <= next_ppu_mode;
    end
end

// next PPU state logic
always_comb begin : NEXT_STATE
    next_ppu_mode = ppu_mode;
    if (cycles > 17'd65664) next_ppu_mode = VBLANK;
    else if (cycles % 456 < 80) next_ppu_mode = OAM_SEARCH;
    else if (cycles % 456 >= 80 && cycles % 456 < 172) next_ppu_mode = ACTIVE_PICTURE;
    else if (cycles % 456 >= 172 && cycles % 456 < 204) next_ppu_mode = HBLANK;
end

// PPU output settings
always_comb begin : STATE_OUTPUT
    vblank = 1'b0; 
    vram_access = 1'b0; 
    oam_access = 1'b0;
    case (ppu_mode)
        OAM_SEARCH     : oam_access = 1'b1;
        ACTIVE_PICTURE : begin vram_access = 1'b1; oam_access = 1'b1; end
        VBLANK         : vblank = 1'b1;
        default        : ; 
    endcase
end

always_comb begin : LINE_COUNT
    if (cycles <= 17'd65664) line = cycles / 9'd456;
    else line = 9'd0;
    Y_out = line;
end




    

assign ppu_read_mode = 1'b1;






endmodule