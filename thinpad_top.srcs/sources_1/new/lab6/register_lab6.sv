// register for lab6

module register_lab6(
    input wire clk,
    input wire rst,

    input wire [4:0] raddr_a,
    output reg [31:0] rdata_a,
    input wire [4:0] raddr_b,
    output reg [31:0] rdata_b,

    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire we
);

// 二维寄存器数组
logic [31:0] regs[31:0];


always_comb begin
    rdata_a <= 32'b0;
    rdata_b <= 32'b0;

    if (raddr_a >= 5'b0) begin
        if (raddr_a < 5'd32) begin
            rdata_a <= regs[raddr_a];
        end
    end

    if (raddr_b >= 5'b0) begin
        if (raddr_b < 5'd32) begin
            rdata_b <= regs[raddr_b];
        end
    end

end

always_ff @(posedge clk) begin
    if (rst) begin
        // // 输出线清零
        // rdata_a <= 32'b0;
        // rdata_b <= 32'b0;
        // 寄存器置零
        for (integer i = 0; i < 32; i++) begin
            regs[i] <= 32'b0;
        end
    end else begin
        if (we) begin
            if (waddr > 5'b0) begin
                regs[waddr] <= wdata;
            end else begin
                regs[waddr] <= 32'b0;
            end
        end
    end
end

endmodule





