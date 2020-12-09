module frame_buffer (
    input logic [1:0] in,
    input logic [7:0] X_write, Y_write,
    input logic wren, wrclock,
    output logic [1:0] out,
    output logic [7:0] X_read, Y_read,
    input logic rdclock
);

framebuffer_ram buffer (
	.data(in),
	.rdaddress((Y_out*144) + X_out),
	.rdclock(rdclock),
	.wraddress((Y_in*144) + X_in),
	.wrclock(wrclock),
	.wren(wrclock),
	.q(out));

endmodule