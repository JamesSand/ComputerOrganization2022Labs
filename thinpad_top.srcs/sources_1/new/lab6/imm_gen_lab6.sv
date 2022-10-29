// imm generator for lab6

module imm_gen_lab6(
    input wire [11:0] imm_i,
    input wire [11:0] imm_s,
    input wire [12:0] imm_b,
    input wire [1:0] imm_gen_type,

    output reg [31:0] imm_o
);

typedef enum logic[2:0] { 
  TYPE_I = 0,
  TYPE_S = 1,
  TYPE_B = 2,
  TYPE_R = 3,
  TYPE_U = 4
} instr_type;


// here I only implement unsign expand
always_comb begin
    case(imm_gen_type)
        TYPE_I : begin
            if (imm_s[11] == 0) begin
                imm_o = { 20'b0, imm_i };
            end else begin
                imm_o = { 20'hfffff, imm_i };
            end
        end

        TYPE_S : begin
            if (imm_s[11] == 0) begin
                imm_o = { 20'b0, imm_s };
            end else begin
                imm_o = { 20'hfffff, imm_s };
            end
        end

        TYPE_B : begin
            // 由于RISC-V指令长度必须是两个字节的倍数，
            // 分支指令的寻址方式是12位的立即数乘以2，符号扩展，
            // 然后加到PC上作为分支的跳转地址。
            // 18 + 13 + 1
            if (imm_b[12] == 0) begin
                imm_o = { 18'b0, imm_b , 1'b0};
            end else begin
                imm_o = { 16'hffff, 2'b11 , imm_b , 1'b0};
            end
            
        end

        default : begin
            imm_o = 32'b0;
        end

    endcase
end

endmodule
