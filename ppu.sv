module ppu (
    ports
);

logic [1:0] frame_in, frame_out
framebuffer_ram frame_buf (.data())
// module framebuffer_ram (
// 	data,
// 	rdaddress,
// 	rdclock,
// 	wraddress,
// 	wrclock,
// 	wren,
// 	q);

endmodule