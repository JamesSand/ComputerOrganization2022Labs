module alu(
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [3:0] op,

    output reg [15:0] y
);

reg a_reg;
reg b_reg;


always_comb begin
    if (op == 4'd1)begin
        // add
        // y = (a + b) & 16'hffff;
        y = (a + b);
    end else if (op ==4'd2 ) begin
        // subtract
        // if (a - b < 0) begin
        //     y = a - b + 17'h10000;
        // end else begin
        //     y = a - b;
        // end

        y = a - b;
    end else if (op ==4'd3 ) begin
        // and
        y = a & b;
    end else if (op ==4'd4 ) begin
        // or
        y = a | b;
    end else if (op ==4'd5 ) begin
        // xor
        y = a ^ b;
    end else if (op ==4'd6 ) begin
        // not
        // y = 16'hffff & ~a;
        y = ~a;
    end else if (op ==4'd7 ) begin
        // shift left
        y = 16'hffff & (a << (b & 4'hf));
    end else if (op ==4'd8 ) begin
        // shift right
        y = a >> (b & 4'hf);
    end else if (op ==4'd9 ) begin
        // shift right algorithmly
        if (a & 16'h8000) begin
            // negative number
            y = a >> (b & 4'hf) | (17'h10000 - (17'h10000 >> (b & 4'hF)));
        end else begin
            // positive number
            y = a >> (b & 4'hf);
        end
    end else if (op ==4'd10 ) begin
        // 循环左移
        y = 16'hffff & (a << (b & 4'hf) | (a >> (16 - (b & 4'hf))));
    end else begin
        // 不合法的操作
        y = 16'b0;
    end
end

endmodule