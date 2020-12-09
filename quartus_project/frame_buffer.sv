module frame_buffer (
    input logic [1:0] in,
    input logic [7:0] X_write, Y_write,
    input logic wren, wrclock,
    output logic [1:0] out,
    input logic [7:0] X_read, Y_read,
    input logic rdclock
);

framebuffer_ram buffer (
	.data(in),
	.rdaddress({(Y_out*144) + X_out}[13:0]),
	.rdclock(rdclock),
	.wraddress({(Y_in*144) + X_in}[13:0]),
	.wrclock(wrclock),
	.wren(wren),
	.q(out));

endmodule