module register_file(
    input wire clk,
    input wire rst,

    input wire [4:0] raddr_a,
    output reg [15:0] rdata_a,
    input wire [4:0] raddr_b,
    output reg [15:0] rdata_b,

    input wire [4:0] waddr,
    input wire [15:0] wdata,
    input wire we
);

// 二维寄存器数组
logic [15:0] regs[31:0];

always_ff @(posedge clk) begin
    if (rst) begin
        // 输出线清零
        rdata_a <= 16'b0;
        rdata_b <= 16'b0;
        // 寄存器置零
        for (integer i = 0; i < 32; i++) begin
            regs[i] <= 16'b0;
        end
    end else begin
        // 所有 reg addr 都是合法的
        rdata_a <= regs[raddr_a];
        rdata_b <= regs[raddr_b];

        if (we) begin
            if (waddr > 5'b0) begin
                regs[waddr] <= wdata;
            end else begin
                regs[waddr] <= 16'b0;
            end
        end
    end
end

endmodule


