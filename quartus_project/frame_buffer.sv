module frame_buffer (
    input logic [1:0] in,
    input logic [8:0] X_write, Y_write,
    input logic wren, wrclock,
	input logic ppu_vblank,
    input logic [8:0] X_read, Y_read,
    input logic rdclock,
	output logic [1:0] out
);

`define TEMP 16'd16000 // 16'd23040

logic [14:0] buffer_in_idx, buffer_out_idx;
logic [1:0] buffer0_out;
logic buffer0_wren;
logic [1:0] buffer1_out;
logic buffer1_wren;

logic active_read_buffer; // buffer that is currently being read by the VGA, other buffer is being written to

// when PPU finishs renderering a into non-active buffer and VGA is done reading from active buffer, swap the buffers
always_ff @( posedge ppu_vblank ) begin
	if (Y_read >= 144 || X_read >= 160) active_read_buffer  = ~active_read_buffer;
end

always_comb begin : XY_TO_IDX
	buffer_in_idx = (Y_write*8'd160) + X_write;
	buffer_out_idx = (Y_read*8'd160) + X_read; 
end

always_comb begin : BUFFER_IO
	if (active_read_buffer == 1'b0) begin
		out = buffer0_out; // read from active buffer
		buffer1_wren = wren; // write to non active buffer
		buffer0_wren = 1'b0;
	end
	else begin
		out = buffer1_out;
		buffer0_wren = wren;
		buffer1_wren = 1'b0;
	end
end

framebuffer_ram buffer0 (
	.data(in),
	.rdaddress(buffer_out_idx),
	.rdclock(rdclock),
	.wraddress(buffer_in_idx),
	.wrclock(wrclock),
	.wren(buffer0_wren),
	.q(buffer0_out));

framebuffer_ram buffer1 (
	.data(in),
	.rdaddress(buffer_out_idx),
	.rdclock(rdclock),
	.wraddress(buffer_in_idx),
	.wrclock(wrclock),
	.wren(buffer1_wren),
	.q(buffer1_out));

endmodule