module de10boy (
    
      ///////// Clocks /////////
      input              Clk,

      input    [ 1: 0]   KEY,

      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output   [ 3: 0]   VGA_R,
      output   [ 3: 0]   VGA_G,
      output   [ 3: 0]   VGA_B


    //   ///////// ARDUINO /////////
    //   inout    [15: 0]   ARDUINO_IO,
    //   inout              ARDUINO_RESET_N 
);

// cpu signals
logic clock, memclock, reset, cpu_mem_wren;
logic [7:0] cpu_data_in, cpu_data_out;
logic [15:0] cpu_mem_addr;

// ppu signals 
logic ppu_vram_read_en, ppu_oam_read_en;
logic [7:0] ppu_data_in, ppu_data_out;
logic [12:0] ppu_mem_addr;

assign ppu_mem_addr = 12'h0;
assign ppu_vram_read_en = 1'b0; 
assign ppu_oam_read_en = 1'b0;

assign {reset}= ~ (KEY[0]);

// c0 = 2.1Mhz 
clock_pll clock_generator (.locked(), .inclk0(Clk), .c0(clock), .c1(memclock)); 

cpu cpu (.clock(clock), .reset(reset), .data_in(cpu_data_in), 
        .data_out(cpu_data_out), .mem_addr(cpu_mem_addr), .mem_wren(cpu_mem_wren));

memory memory_map (.cpu_addr(cpu_mem_addr), .ppu_addr(), .clock(memclock), .boot_rom_en(1'b1), .cpu_wren(cpu_mem_wren), 
                .ppu_vram_read_en(ppu_vram_read_en), .ppu_oam_read_en(ppu_oam_read_en), .cpu_data_in(cpu_data_out),
                .cpu_data_out(cpu_data_in), .ppu_data_in(ppu_data_out), .ppu_data_out(ppu_data_in));


logic clkdiv, blank;
logic [7:0] Red, Green, Blue;
logic [9:0] DrawX, DrawY;

assign VGA_R = Red[7:4];
assign VGA_B = Blue[7:4];
assign VGA_G = Green[7:4];

always_comb begin
    if (~blank) {Red, Green, Blue} = 24'h0;
    else begin
        Red = cpu_data_out; // CHANGE THIS
        Green = 8'h55;
        Blue = 8'h00;
    end
end

vga_controller vga (.Clk(Clk), .Reset(reset), .hs(VGA_HS), .vs(VGA_VS), 
					.blank(blank), .DrawX(DrawX), .DrawY(DrawY) );

frame_buffer fram (.in(), .X_write(), .Y_write(), .wren(1'b0), .wrclock(), .out(), .X_read(DrawX), .Y_read(DrawY), .rdclock(Clk));

    
endmodule