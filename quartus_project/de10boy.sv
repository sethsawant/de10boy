module de10boy (
    
      ///////// Clocks /////////
      input logic             Clk,
    //   input logic              clock,

      input    [ 1: 0]   KEY,

      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output   [ 3: 0]   VGA_R,
      output   [ 3: 0]   VGA_G,
      output   [ 3: 0]   VGA_B,
      output   [15:0] placeholder


    //   ///////// ARDUINO /////////
    //   inout    [15: 0]   ARDUINO_IO,
    //   inout              ARDUINO_RESET_N 
);

// cpu signals
logic clock;
logic memclock, reset, cpu_mem_wren;
logic [7:0] cpu_data_in, cpu_data_out;
logic [15:0] cpu_mem_addr;

// ppu signals 
logic ppu_vram_read_en, ppu_oam_read_en;
logic [7:0] ppu_data_in;
logic [12:0] ppu_mem_addr; 
logic ppu_write_mode; // 0 if ppu is reading oam, 1 if reading vram
logic [7:0] ppuX, ppuY; // current pixel that ppu is rendering
logic [1:0] buffer_pixel_in, buffer_pixel_out;


logic ppu_frame_wren;

// interrupt lines
logic joypad_int, serial_int, timer_int, lcdc_int, vblank_int;

assign {reset}= ~ (KEY[0]);

// // // c0 = 2.1Mhz 
// clock_pll clock_generator (.locked(), .inclk0(Clk), .c0(clock), .c1(memclock)); 
// assign placeholder = {cpu_data_out, ppu_data_in};
// assign memclock = Clk;

cpu cpu (.clock(Clk), .reset(reset), .data_in(cpu_data_in), 
        .data_out(cpu_data_out), .mem_addr(cpu_mem_addr), .mem_wren(cpu_mem_wren));

memory memory_map (.cpu_addr(cpu_mem_addr), .ppu_addr(ppu_mem_addr), .clock(Clk), .boot_rom_en(1'b1), .cpu_wren(cpu_mem_wren), 
                .ppu_vram_read_en(ppu_vram_read_en), .ppu_oam_read_en(ppu_oam_read_en), .cpu_data_in(cpu_data_out),
                .cpu_data_out(cpu_data_in), .ppu_data_out(ppu_data_in), .ppu_read_mode(ppu_read_mode));


logic vga_blank;
logic [3:0] pixelR, pixelG, pixelB;
logic [9:0] DrawX, DrawY;

assign VGA_R = pixelR;
assign VGA_B = pixelG;
assign VGA_G = pixelB;

always_comb begin
    if (~vga_blank) {pixelR, pixelG, pixelB} = {4'd0, 4'd0, 4'd0};
    else begin 
        case (buffer_pixel_out)
            2'd0 : {pixelR, pixelG, pixelB} = {4'd3, 4'd0, 4'd0};
            2'd1 : {pixelR, pixelG, pixelB} = {4'd7, 4'd0, 4'd0};
            2'd2 : {pixelR, pixelG, pixelB} = {4'd11, 4'd0, 4'd0};
            2'd3 : {pixelR, pixelG, pixelB} = {4'd15, 4'd0, 4'd0};
        endcase
    end
end
ppu ppu (.data_in(ppu_data_in), .clock(Clk), .cpu_clock(Clk), .reset(reset), .ppu_mem_addr(ppu_mem_addr), 
        .X_out(ppuX), .Y_out(ppuY), .pixel_out(buffer_pixel_in), .frame_wren(ppu_frame_wren), .vblank(vblank_int), 
        .vram_access(ppu_vram_read_en), .oam_access(ppu_oam_read_en), .ppu_read_mode(ppu_read_mode)); 

vga_controller vga (.Clk(Clk), .Reset(reset), .hs(VGA_HS), .vs(VGA_VS), 
					.blank(vga_blank), .DrawX(DrawX), .DrawY(DrawY) );

frame_buffer fram (.in(buffer_pixel_in), .X_write(ppuX), .Y_write(ppuY), .wren(ppu_frame_wren), .wrclock(Clk), .out(buffer_pixel_out), .X_read(DrawX[7:0]), .Y_read(DrawY[7:0]), .rdclock(Clk));

    
endmodule