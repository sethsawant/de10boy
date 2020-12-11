module frame_buffer (
    input logic [1:0] in,
    input logic [7:0] X_write, Y_write,
    input logic wren, wrclock,
    output logic [1:0] out,
    input logic [7:0] X_read, Y_read,
    input logic rdclock
);

logic [13:0] buffer_in_idx, buffer_out_idx;
assign buffer_in_idx = (Y_write*160) + X_write;
assign buffer_out_idx = (Y_read*160) + X_read;

// assign wren = 1'b0;


framebuffer_ram buffer (
	.data(in),
	.rdaddress(buffer_out_idx),
	.rdclock(rdclock),
	.wraddress(buffer_in_idx),
	.wrclock(wrclock),
	.wren(wren),
	.q(out));

endmodule