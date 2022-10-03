
module controller (
    input wire clk,
    input wire reset,

    // 连接寄存器堆模块的信号
    output reg  [4:0]  rf_raddr_a,
    input  wire [15:0] rf_rdata_a,
    output reg  [4:0]  rf_raddr_b,
    input  wire [15:0] rf_rdata_b,
    output reg  [4:0]  rf_waddr,
    output reg  [15:0] rf_wdata,
    output reg  rf_we,

    // 连接 ALU 模块的信号
    output reg  [15:0] alu_a,
    output reg  [15:0] alu_b,
    output reg  [ 3:0] alu_op,
    input  wire [15:0] alu_y,

    // 控制信号
    input  wire        step,    // 用户按键状态脉冲
    input  wire [31:0] dip_sw,  // 32 位拨码开关状态
    output reg  [15:0] leds
);

  logic [31:0] inst_reg;  // 指令寄存器

  // 组合逻辑，解析指令中的常用部分，依赖于有效的 inst_reg 值
  logic is_rtype, is_itype, is_peek, is_poke;
  logic [15:0] imm;
  logic [4:0] rd, rs1, rs2;
  logic [3:0] opcode;

  always_comb begin
    is_rtype = (inst_reg[2:0] == 3'b001);
    is_itype = (inst_reg[2:0] == 3'b010);
    is_peek = is_itype && (inst_reg[6:3] == 4'b0010);
    is_poke = is_itype && (inst_reg[6:3] == 4'b0001);

    imm = inst_reg[31:16];
    rd = inst_reg[11:7];
    rs1 = inst_reg[19:15];
    rs2 = inst_reg[24:20];
    opcode = inst_reg[6:3];
  end

  // 使用枚举定义状态列表，数据类型为 logic [3:0]
//   这里因为有 5 种信号，所以要用 3 位进行存储
  typedef enum logic [3:0] {
    ST_INIT,
    ST_DECODE,
    ST_CALC,
    ST_READ_REG,
    ST_WRITE_REG
  } state_t;

  // 状态机当前状态寄存器
  state_t state;

  // calc 的状态
  typedef enum logic [2:0] {
    ST_READ,
    ST_TRANS,
    // ST_CALC,
    ST_WRITE
  } state_calc;

  state_calc calc;

  // peek 的状态
  logic peek;

  // 状态机逻辑
  always_ff @(posedge clk) begin
    if (reset) begin
        // 首先检查是否是 reset
        // TODO: 复位各个输出信号
        state <= ST_INIT;
        // 复位寄存器堆信号
        rf_raddr_a <= 5'b0;
        rf_raddr_b <= 5'b0;
        rf_waddr <= 5'b0;
        rf_wdata <= 16'b0;
        rf_we <= 0;
        // 复位 ALU 模块
        alu_a <= 16'b0;
        alu_b <= 16'b0;
        alu_op <= 16'b0;
        // 复位控制信号
        leds <= 16'b0;
    end else begin
        // 状态机，这里利用 clk 作为循环
      case (state)
        ST_INIT: begin
            // 只需要每次在 init 的时候把 we 设为 0
            rf_we <= 0;
            rf_waddr <= 5'b0;
            rf_wdata <= 16'b0;
          if (step) begin
            // 用户的 trigger 信号，从 init 转到 decode
            inst_reg <= dip_sw;
            state <= ST_DECODE;
          end
        end

        ST_DECODE: begin
          if (is_rtype) begin
            // 交给 ALU
            // 把寄存器地址交给寄存器堆，读取操作数
            rf_raddr_a <= rs1;
            rf_raddr_b <= rs2;

            // 进入 calc 的 origin 状态
            calc <= ST_READ;

            state <= ST_CALC;
          end else if (is_peek) begin
            // TODO: 其他指令的处理
            // read peek 将寄存器中的值打印到 led 上
            // 这一步要去问 Register File 值是什么
            rf_raddr_a <= rd; // 因为目标寄存器是 rd
            peek <= 1;
            state <= ST_READ_REG;
          end else if(is_poke) begin
            // write poke 将立即数存入寄存器
            rf_waddr <= rd;
            rf_wdata <= imm;

            state <= ST_WRITE_REG;
          end else begin
            // 未知指令，回到初始状态
            state <= ST_INIT;
          end
        end

        ST_CALC: begin
          // TODO: 将数据交给 ALU，并从 ALU 获取结果
            case (calc)
              ST_READ: begin
                calc <= ST_TRANS;
              end

              ST_TRANS: begin
                alu_a <= rf_rdata_a;
                alu_b <= rf_rdata_b;
                alu_op <= opcode;
                calc <= ST_WRITE;
              end

              ST_WRITE: begin
                // 将结果写入 rd 寄存器
                rf_waddr <= rd;
                rf_wdata <= alu_y;
                state <= ST_WRITE_REG;
              end

              default : begin
                calc <= ST_WRITE;
              end
            endcase
        end

        ST_WRITE_REG: begin
          // TODO: 将结果存入寄存器
        //   直接变 1 将数据送入 Register File
          rf_we <= 1; // 在 init 的时候把 we 关掉
          state <= ST_INIT;
        end

        ST_READ_REG: begin
          // TODO: 将数据从寄存器中读出，存入 leds
            // 由于是用 read a 进行询问的
            // 直接将 a 的结果放到 leds
            if (peek) begin
              peek <= 0;
              state <= ST_READ_REG;
            end else begin
              leds <= rf_rdata_a;
              state <= ST_INIT;
            end
            
        end

        default: begin
          state <= ST_INIT;
        end
      endcase
    end
  end
endmodule


