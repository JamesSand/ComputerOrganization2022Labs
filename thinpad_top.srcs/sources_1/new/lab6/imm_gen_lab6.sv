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
            imm_o = { 20'b0, imm_i };
        end

        TYPE_S : begin
            imm_o = { 20'b0, imm_s };
        end

        TYPE_B : begin
            imm_o = { 19'b0, imm_s };
        end

        default : begin
            imm_o = 31'b0;
        end

    endcase
end

endmodule
