
module register #(parameter WIDTH = 8)(
    input [WIDTH-1:0] in,
    input clock, reset, load,
    output [WIDTH-1:0] out
);

logic [WIDTH-1:0] data;

always_ff @ (posedge clock) begin
    if (reset)
        data <= 0;
    if (load)
        data <= in;
end

assign out = data;

endmodule