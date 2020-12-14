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



logic [16:0] cycles; // number of CPU cycles executed so far
logic [8:0] line_cycles; // CPU cycles executed so for for the current line
logic [9:0] y, x; // x and y coordinates in the 256 x 256 window to be rendered
logic [9:0] scrollY,scrollX;
logic [5:0] bgTileX, bgTileY; // tile coordinates that need to be fetched to render the pixel at x,y
logic [4:0] tileX, tileY; // coordinates of pixel inside tile

assign bgTileX = x >> 3; // dividing 8 
assign bgTileY = y >> 3;

assign tileX = x[2:0]; // same as modulo 8
assign tileY = y[2:0];

logic [7:0] tilemapByte_new, tilemapByte;
logic [7:0] tileByte0_new, tileByte0;
logic [7:0] tileByte1_new, tileByte1;
logic tilemapByte_ld, tileByte0_ld, tileByte1_ld;

register #(.WIDTH(8)) tilemapByte_reg (.in(tilemapByte_new), .clock(clock), .reset(reset), .load(tilemapByte_ld), .out(tilemapByte));
register #(.WIDTH(8)) tileByte0_reg (.in(tileByte0_new), .clock(clock), .reset(reset), .load(tileByte0_ld), .out(tileByte0));
register #(.WIDTH(8)) tileByte1_reg (.in(tileByte1_new), .clock(clock), .reset(reset), .load(tileByte1_ld), .out(tileByte1));

enum logic [1:0] {HBLANK = 2'd0, VBLANK = 2'd1, OAM_SEARCH = 2'd2, ACTIVE_PICTURE = 2'd3} ppu_mode, next_ppu_mode;
enum logic [5:0] {WAITING, GET_TILEMAP_WAIT, GET_TILEMAP, GET_TILE0_WAIT,  GET_TILE0, GET_TILE1_WAIT, GET_TILE1, DRAW_PIXELS, INC_Y, DONE} render_state, next_render_state;

always_ff @ (posedge cpu_clock)
begin

    if (reset || (line_cycles >= 9'd454)) line_cycles <= 9'h0; // reset counter at the end of a full line
	else line_cycles <= line_cycles + 2'h2; // add two per CPU clock due to implementation of CPU running at half the freq of actual GB CPU

	if (reset || (cycles == 17'd70222)) cycles <= 17'h0; // reset counter at the end of a full frame
		
	else cycles <= cycles + 2'h2; // add two per CPU clock due to implementation of CPU running at half the freq of actual GB CPU

end

// next PPU mode state logic
always_comb begin : NEXT_STATE
    next_ppu_mode = ppu_mode;
    if (cycles >= 17'd65664) next_ppu_mode = VBLANK;
    else if (line_cycles < 80) next_ppu_mode = OAM_SEARCH;
    else if (line_cycles >= 80 && line_cycles < 252) next_ppu_mode = ACTIVE_PICTURE;
    else if (line_cycles >= 252) next_ppu_mode = HBLANK;
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

always_comb begin : X_CALC
    scrollX = 10'd0;
    x = X_out + scrollX;
end

always_comb begin : Y_CALC
    scrollY = 10'd64;
    y = Y_out + scrollY;
end


//////////////////////////////////////////////////////////////////////////////////////////////////////




always_ff @ (posedge clock)
begin


    if (reset || (cycles == 17'd0)) ppu_mode <= OAM_SEARCH;
	else ppu_mode <= next_ppu_mode;
        

	if (reset) begin
        render_state <= WAITING;
        X_out <= 8'd0;
        Y_out <= 8'd0;
        // scrollY <= 10'd0;
    end 

	else begin
        render_state <= next_render_state;
        if (render_state == DRAW_PIXELS) X_out <= X_out + 8'd1;  
        else if (render_state == DONE) X_out <= 8'd0;
        else X_out <= X_out;

        if (render_state == INC_Y) Y_out <= Y_out + 8'd1;
        else if (ppu_mode == VBLANK) Y_out <= 8'd0;
        else Y_out <= Y_out;
    end
end

always_comb begin : RENDER_NEXT_STATE_LOGIC
    next_render_state = render_state;
    case (render_state)
        WAITING : if (ppu_mode == ACTIVE_PICTURE) next_render_state = GET_TILEMAP_WAIT;
        GET_TILEMAP_WAIT        : next_render_state = GET_TILEMAP;
        GET_TILEMAP             : next_render_state = GET_TILE0_WAIT;
        GET_TILE0_WAIT          : next_render_state = GET_TILE0;
        GET_TILE0               : next_render_state = GET_TILE1_WAIT;
        GET_TILE1_WAIT          : next_render_state = GET_TILE1;
        GET_TILE1               : next_render_state = DRAW_PIXELS;
        DRAW_PIXELS             : begin 
                                    if (X_out >= 159) next_render_state = INC_Y; // if done with current line, switch to done to begin hblank period
                                    else if (tileX == 3'd7) next_render_state = GET_TILEMAP_WAIT; // every 8 pixels need to fetch new tile data
                                  end
        INC_Y                   : next_render_state = DONE;
        DONE                    : if (ppu_mode != ACTIVE_PICTURE) next_render_state = WAITING;
        default: ;
    endcase
end

always_comb begin : blockName
    tilemapByte_new = tilemapByte;
    tileByte0_new = tileByte0;
    tileByte1_new = tileByte1;
    tilemapByte_ld = 1'b0;
    tileByte0_ld = 1'b0;
    tileByte1_ld = 1'b0;
    ppu_mem_addr = 16'hXXXX;
    pixel_out = 2'bXX;
    frame_wren = 1'b0;    


    case (render_state)

        // get appropriate tile index byte from tile map region
        GET_TILEMAP_WAIT : ppu_mem_addr = 16'h1800 + 6'd32 * bgTileY + bgTileX;
        GET_TILEMAP : begin
            ppu_mem_addr = 16'h1800 + 6'd32 * bgTileY + bgTileX;
            tilemapByte_new = data_in;
            tilemapByte_ld = 1'b1;
        end

        // use that index to retrieve one line of the tile data (consists of two bytes)
        GET_TILE0_WAIT : ppu_mem_addr = (16'h0000 + tilemapByte << 4) + (tileY << 1) + (tileX >> 1);
        GET_TILE0 : begin
            ppu_mem_addr = (16'h0000 + tilemapByte << 4) + (tileY << 1) + (tileX >> 1);
            tileByte0_new = data_in;
            tileByte0_ld = 1'b1;
        end
        GET_TILE1_WAIT : ppu_mem_addr = (16'h0000 + tilemapByte << 4) + (tileY << 1) + (tileX >> 1) + 1'b1;
        GET_TILE1 : begin
            ppu_mem_addr = (16'h0000 + tilemapByte << 4) + (tileY << 1) + (tileX >> 1) + 1'b1;
            tileByte1_new = data_in;
            tileByte1_ld = 1'b1;
        end

        // draw the 8 pixels of the tile's line, then rinse and repeat
        DRAW_PIXELS : begin
            pixel_out = {tileByte1[3'b111-tileX],tileByte0[3'b111-tileX]};
            frame_wren = 1'b1;
        end

        default: ;
    endcase
end




    

assign ppu_read_mode = 1'b1;






endmodule