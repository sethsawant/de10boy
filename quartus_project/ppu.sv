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
logic [7:0] y, x; // current line and pixel of the frame PPU is currently working on
logic [9:0] scrollY,scrollX;
logic [5:0] bgTileX, bgTileY; // tile coordinates that need to be fetched to render the current pixel at x,y
logic [4:0] tileX, tileY; // coordinates of pixel inside tile

assign bgTileX = x >> 3; // dividing by 8 
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
enum logic [5:0] {WAITING, GET_TILEMAP_WAIT, GET_TILEMAP, GET_TILE0_WAIT,  GET_TILE0, GET_TILE1_WAIT, GET_TILE1, DRAW_PIXELS, DONE} render_state, next_render_state;

always_ff @ (posedge cpu_clock)
begin

    if (reset || (line_cycles == 9'd456)) line_cycles <= 9'h0; // reset counter at the end of a full line
	else line_cycles <= line_cycles + 2'h2; // add two per CPU clock due to implementation of CPU running at half the freqeuncy of actual GB CPU

	if (reset || (cycles == 17'd70224)) begin // reset counter at the end of a full frame
		cycles <= 17'h0;
        ppu_mode <= OAM_SEARCH;
    end
	else begin
		cycles <= cycles + 2'h2; // add two per CPU clock due to implementation of CPU running at half the freqeuncy of actual GB CPU
        ppu_mode <= next_ppu_mode;
    end

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
    // scrollX = 0;
    // x = X_out + scrollX;
    X_out = x;
end

always_comb begin : Y_CALC
    scrollY = 0;
    y = Y_out + scrollY;
end

always_comb begin : CURRENT_OUTPUT_LINE;
    if (cycles >= 0 && cycles < 456) Y_out = 0;
    else if (cycles >= 456 && cycles < 912) Y_out = 1;
    else if (cycles >= 912 && cycles < 1368) Y_out = 2;
    else if (cycles >= 1368 && cycles < 1824) Y_out = 3;
    else if (cycles >= 1824 && cycles < 2280) Y_out = 4;
    else if (cycles >= 2280 && cycles < 2736) Y_out = 5;
    else if (cycles >= 2736 && cycles < 3192) Y_out = 6;
    else if (cycles >= 3192 && cycles < 3648) Y_out = 7;
    else if (cycles >= 3648 && cycles < 4104) Y_out = 8;
    else if (cycles >= 4104 && cycles < 4560) Y_out = 9;
    else if (cycles >= 4560 && cycles < 5016) Y_out = 10;
    else if (cycles >= 5016 && cycles < 5472) Y_out = 11;
    else if (cycles >= 5472 && cycles < 5928) Y_out = 12;
    else if (cycles >= 5928 && cycles < 6384) Y_out = 13;
    else if (cycles >= 6384 && cycles < 6840) Y_out = 14;
    else if (cycles >= 6840 && cycles < 7296) Y_out = 15;
    else if (cycles >= 7296 && cycles < 7752) Y_out = 16;
    else if (cycles >= 7752 && cycles < 8208) Y_out = 17;
    else if (cycles >= 8208 && cycles < 8664) Y_out = 18;
    else if (cycles >= 8664 && cycles < 9120) Y_out = 19;
    else if (cycles >= 9120 && cycles < 9576) Y_out = 20;
    else if (cycles >= 9576 && cycles < 10032) Y_out = 21;
    else if (cycles >= 10032 && cycles < 10488) Y_out = 22;
    else if (cycles >= 10488 && cycles < 10944) Y_out = 23;
    else if (cycles >= 10944 && cycles < 11400) Y_out = 24;
    else if (cycles >= 11400 && cycles < 11856) Y_out = 25;
    else if (cycles >= 11856 && cycles < 12312) Y_out = 26;
    else if (cycles >= 12312 && cycles < 12768) Y_out = 27;
    else if (cycles >= 12768 && cycles < 13224) Y_out = 28;
    else if (cycles >= 13224 && cycles < 13680) Y_out = 29;
    else if (cycles >= 13680 && cycles < 14136) Y_out = 30;
    else if (cycles >= 14136 && cycles < 14592) Y_out = 31;
    else if (cycles >= 14592 && cycles < 15048) Y_out = 32;
    else if (cycles >= 15048 && cycles < 15504) Y_out = 33;
    else if (cycles >= 15504 && cycles < 15960) Y_out = 34;
    else if (cycles >= 15960 && cycles < 16416) Y_out = 35;
    else if (cycles >= 16416 && cycles < 16872) Y_out = 36;
    else if (cycles >= 16872 && cycles < 17328) Y_out = 37;
    else if (cycles >= 17328 && cycles < 17784) Y_out = 38;
    else if (cycles >= 17784 && cycles < 18240) Y_out = 39;
    else if (cycles >= 18240 && cycles < 18696) Y_out = 40;
    else if (cycles >= 18696 && cycles < 19152) Y_out = 41;
    else if (cycles >= 19152 && cycles < 19608) Y_out = 42;
    else if (cycles >= 19608 && cycles < 20064) Y_out = 43;
    else if (cycles >= 20064 && cycles < 20520) Y_out = 44;
    else if (cycles >= 20520 && cycles < 20976) Y_out = 45;
    else if (cycles >= 20976 && cycles < 21432) Y_out = 46;
    else if (cycles >= 21432 && cycles < 21888) Y_out = 47;
    else if (cycles >= 21888 && cycles < 22344) Y_out = 48;
    else if (cycles >= 22344 && cycles < 22800) Y_out = 49;
    else if (cycles >= 22800 && cycles < 23256) Y_out = 50;
    else if (cycles >= 23256 && cycles < 23712) Y_out = 51;
    else if (cycles >= 23712 && cycles < 24168) Y_out = 52;
    else if (cycles >= 24168 && cycles < 24624) Y_out = 53;
    else if (cycles >= 24624 && cycles < 25080) Y_out = 54;
    else if (cycles >= 25080 && cycles < 25536) Y_out = 55;
    else if (cycles >= 25536 && cycles < 25992) Y_out = 56;
    else if (cycles >= 25992 && cycles < 26448) Y_out = 57;
    else if (cycles >= 26448 && cycles < 26904) Y_out = 58;
    else if (cycles >= 26904 && cycles < 27360) Y_out = 59;
    else if (cycles >= 27360 && cycles < 27816) Y_out = 60;
    else if (cycles >= 27816 && cycles < 28272) Y_out = 61;
    else if (cycles >= 28272 && cycles < 28728) Y_out = 62;
    else if (cycles >= 28728 && cycles < 29184) Y_out = 63;
    else if (cycles >= 29184 && cycles < 29640) Y_out = 64;
    else if (cycles >= 29640 && cycles < 30096) Y_out = 65;
    else if (cycles >= 30096 && cycles < 30552) Y_out = 66;
    else if (cycles >= 30552 && cycles < 31008) Y_out = 67;
    else if (cycles >= 31008 && cycles < 31464) Y_out = 68;
    else if (cycles >= 31464 && cycles < 31920) Y_out = 69;
    else if (cycles >= 31920 && cycles < 32376) Y_out = 70;
    else if (cycles >= 32376 && cycles < 32832) Y_out = 71;
    else if (cycles >= 32832 && cycles < 33288) Y_out = 72;
    else if (cycles >= 33288 && cycles < 33744) Y_out = 73;
    else if (cycles >= 33744 && cycles < 34200) Y_out = 74;
    else if (cycles >= 34200 && cycles < 34656) Y_out = 75;
    else if (cycles >= 34656 && cycles < 35112) Y_out = 76;
    else if (cycles >= 35112 && cycles < 35568) Y_out = 77;
    else if (cycles >= 35568 && cycles < 36024) Y_out = 78;
    else if (cycles >= 36024 && cycles < 36480) Y_out = 79;
    else if (cycles >= 36480 && cycles < 36936) Y_out = 80;
    else if (cycles >= 36936 && cycles < 37392) Y_out = 81;
    else if (cycles >= 37392 && cycles < 37848) Y_out = 82;
    else if (cycles >= 37848 && cycles < 38304) Y_out = 83;
    else if (cycles >= 38304 && cycles < 38760) Y_out = 84;
    else if (cycles >= 38760 && cycles < 39216) Y_out = 85;
    else if (cycles >= 39216 && cycles < 39672) Y_out = 86;
    else if (cycles >= 39672 && cycles < 40128) Y_out = 87;
    else if (cycles >= 40128 && cycles < 40584) Y_out = 88;
    else if (cycles >= 40584 && cycles < 41040) Y_out = 89;
    else if (cycles >= 41040 && cycles < 41496) Y_out = 90;
    else if (cycles >= 41496 && cycles < 41952) Y_out = 91;
    else if (cycles >= 41952 && cycles < 42408) Y_out = 92;
    else if (cycles >= 42408 && cycles < 42864) Y_out = 93;
    else if (cycles >= 42864 && cycles < 43320) Y_out = 94;
    else if (cycles >= 43320 && cycles < 43776) Y_out = 95;
    else if (cycles >= 43776 && cycles < 44232) Y_out = 96;
    else if (cycles >= 44232 && cycles < 44688) Y_out = 97;
    else if (cycles >= 44688 && cycles < 45144) Y_out = 98;
    else if (cycles >= 45144 && cycles < 45600) Y_out = 99;
    else if (cycles >= 45600 && cycles < 46056) Y_out = 100;
    else if (cycles >= 46056 && cycles < 46512) Y_out = 101;
    else if (cycles >= 46512 && cycles < 46968) Y_out = 102;
    else if (cycles >= 46968 && cycles < 47424) Y_out = 103;
    else if (cycles >= 47424 && cycles < 47880) Y_out = 104;
    else if (cycles >= 47880 && cycles < 48336) Y_out = 105;
    else if (cycles >= 48336 && cycles < 48792) Y_out = 106;
    else if (cycles >= 48792 && cycles < 49248) Y_out = 107;
    else if (cycles >= 49248 && cycles < 49704) Y_out = 108;
    else if (cycles >= 49704 && cycles < 50160) Y_out = 109;
    else if (cycles >= 50160 && cycles < 50616) Y_out = 110;
    else if (cycles >= 50616 && cycles < 51072) Y_out = 111;
    else if (cycles >= 51072 && cycles < 51528) Y_out = 112;
    else if (cycles >= 51528 && cycles < 51984) Y_out = 113;
    else if (cycles >= 51984 && cycles < 52440) Y_out = 114;
    else if (cycles >= 52440 && cycles < 52896) Y_out = 115;
    else if (cycles >= 52896 && cycles < 53352) Y_out = 116;
    else if (cycles >= 53352 && cycles < 53808) Y_out = 117;
    else if (cycles >= 53808 && cycles < 54264) Y_out = 118;
    else if (cycles >= 54264 && cycles < 54720) Y_out = 119;
    else if (cycles >= 54720 && cycles < 55176) Y_out = 120;
    else if (cycles >= 55176 && cycles < 55632) Y_out = 121;
    else if (cycles >= 55632 && cycles < 56088) Y_out = 122;
    else if (cycles >= 56088 && cycles < 56544) Y_out = 123;
    else if (cycles >= 56544 && cycles < 57000) Y_out = 124;
    else if (cycles >= 57000 && cycles < 57456) Y_out = 125;
    else if (cycles >= 57456 && cycles < 57912) Y_out = 126;
    else if (cycles >= 57912 && cycles < 58368) Y_out = 127;
    else if (cycles >= 58368 && cycles < 58824) Y_out = 128;
    else if (cycles >= 58824 && cycles < 59280) Y_out = 129;
    else if (cycles >= 59280 && cycles < 59736) Y_out = 130;
    else if (cycles >= 59736 && cycles < 60192) Y_out = 131;
    else if (cycles >= 60192 && cycles < 60648) Y_out = 132;
    else if (cycles >= 60648 && cycles < 61104) Y_out = 133;
    else if (cycles >= 61104 && cycles < 61560) Y_out = 134;
    else if (cycles >= 61560 && cycles < 62016) Y_out = 135;
    else if (cycles >= 62016 && cycles < 62472) Y_out = 136;
    else if (cycles >= 62472 && cycles < 62928) Y_out = 137;
    else if (cycles >= 62928 && cycles < 63384) Y_out = 138;
    else if (cycles >= 63384 && cycles < 63840) Y_out = 139;
    else if (cycles >= 63840 && cycles < 64296) Y_out = 140;
    else if (cycles >= 64296 && cycles < 64752) Y_out = 141;
    else if (cycles >= 64752 && cycles < 65208) Y_out = 142;
    else if (cycles >= 65208 && cycles < 65664) Y_out = 143;
    else Y_out = 9'd0;
end





//////////////////////////////////////////////////////////////////////////////////////////////////////




always_ff @ (posedge clock)
begin
	if (reset) begin
        render_state <= WAITING;
        x <= 8'd0;
    end 
	else begin
        render_state <= next_render_state;
        if (render_state == DRAW_PIXELS) x <= x + 8'd1;  
        else if (render_state == DONE) x <= 8'd0;
        else x <= x;
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
                                    if (x >= 159) next_render_state = DONE; // if done with current line, switch to done to begin hblank period
                                    else if (tileX == 3'd7) next_render_state = GET_TILEMAP_WAIT; // every 8 pixels need to fetch new tile data
                                  end
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