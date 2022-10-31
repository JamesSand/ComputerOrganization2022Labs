


module lab6_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // wishbone master
    output reg wb_cyc_o, // start when both cyc and stb are 1
    output reg wb_stb_o, // start when both cyc and stb are 1
    input wire wb_ack_i, // ack signal
    output reg [ADDR_WIDTH-1:0] wb_addr_o,
    output reg [DATA_WIDTH-1:0] wb_data_o,
    input wire [DATA_WIDTH-1:0] wb_data_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o // 0 for read, 1 for write

);


// lab6 code below

// model instantiation

// Register File & Controller
logic [4:0] rf_raddr_a_o;
logic [31:0] rf_rdata_a_i;
logic [4:0] rf_raddr_b_o;
logic [31:0] rf_rdata_b_i;

logic [4:0] rf_waddr_o;
logic [31:0] rf_wdata_o;
logic rf_we_o;

register_lab6 u_register_lab6(
  .clk(clk_i),
  .rst(rst_i),

  .raddr_a(rf_raddr_a_o),
  .rdata_a(rf_rdata_a_i),
  .raddr_b(rf_raddr_b_o),
  .rdata_b(rf_rdata_b_i),
  
  .waddr(rf_waddr_o),
  .wdata(rf_wdata_o),
  .we(rf_we_o)
);

// ALU & controller
logic [31:0] alu_operand1_o;
logic [31:0] alu_operand2_o;
logic [3:0] alu_op_o;
logic [31:0] alu_result_i;

alu_lab6 u_alu_lab6(
  .a(alu_operand1_o),
  .b(alu_operand2_o),
  .op(alu_op_o),
  .y(alu_result_i)
);

// type enum
// status machine
typedef enum logic [1:0] {
    STATE_IF = 0,
    STATE_ID = 1,
    STATE_EXE = 2,
    STATE_WB = 3
} state_t;

state_t state;

typedef enum logic [3:0]{
  ALU_OP_ADD = 4'd1,
  ALU_OP_SUB = 4'd2,
  ALU_OP_AND = 4'd3,
  ALU_OP_OR = 4'd4,
  ALU_OP_XOR = 4'd5,
  ALU_OP_NOT = 4'd6,
  ALU_OP_SLL = 4'd7,
  ALU_OP_SRL = 4'd8,
  ALU_OP_SRA = 4'd9,
  ALU_OP_ROL = 4'd10,
  ALU_OP_SETB = 4'd11
} alu_op_type;

// instruction opcode
typedef enum logic[6:0] { 
  LUI_OP = 7'b0110111,
  BEQ_OP = 7'b1100011,
  LB_OP = 7'b0000011,
  SB_SW_OP = 7'b0100011,
  ADDI_ANDI_OP = 7'b0010011,
  ADD_OP = 7'b0110011
} instr_opcode;

typedef enum logic[2:0] { 
  TYPE_I = 0,
  TYPE_S = 1,
  TYPE_B = 2,
  TYPE_R = 3,
  TYPE_U = 4
} instr_type;

// other signals and ff logics

// IF stage
reg [31:0] pc_reg;
reg [31:0] pc_now_reg;
reg [31:0] inst_reg;


// ID stage
logic [31:0] rs1_value;
logic [31:0] rs2_value;

// EXE stage
logic if_wirte_reg; // 1 for write back, 0 for not
logic [31:0] write_reg_data_o;
logic [4:0] write_reg_addr_o;

logic if_write_sram;
logic [31:0] write_sram_data_o;
logic [31:0] write_sram_addr_o;
logic [3:0] write_sram_sel_o;

// instruction parser
logic [6:0] opcode;
logic [2:0] funct3;
logic [4:0] rd, rs1, rs2;

logic [2:0] instruction_type;

logic [11:0] imm_i;
logic [11:0] imm_s;
logic [12:0] imm_b;
logic [31:0] imm_u;

logic [31:0] imm_gen_result_i;

imm_gen_lab6 u_imm_gen_lab6(
  .imm_i(imm_i),
  .imm_s(imm_s),
  .imm_b(imm_b),
  .imm_gen_type(instruction_type),

  .imm_o(imm_gen_result_i)
);


// instruction should be inst_reg
always_comb begin
    // opcode is 6 : 0
    opcode = inst_reg[6:0];

    // funct3 14:12
    funct3 = inst_reg[14:12];

    // registers
    rd = inst_reg[11:7];
    rs1 = inst_reg[19:15];
    rs2 = inst_reg[24:20];

    // imm
    imm_i = inst_reg[31:20];
    imm_s = {inst_reg[31:25], inst_reg[11:7]};
    imm_b = {inst_reg[31], inst_reg[7], inst_reg[30:25], inst_reg[11:8], 1'b0};
    imm_u = {inst_reg[31:12], 12'b0};

    // instruction type

    case(opcode) 
      LUI_OP : begin
        // U type
        instruction_type = TYPE_U;
      end

      BEQ_OP :begin
        // B type
        instruction_type = TYPE_B;
      end

      LB_OP : begin
        // I type
        instruction_type = TYPE_I;
      end

      SB_SW_OP : begin
        // S type
        instruction_type = TYPE_S;
      end

      ADDI_ANDI_OP : begin
        // I type
        instruction_type = TYPE_I;
      end

      ADD_OP : begin
        // R type
        instruction_type = TYPE_R;
      end

      default : begin
        instruction_type = 3'b0;
      end

    endcase
end

// cpu combination
always_comb begin
  // alu_operand1_o = 32'b0;
  // alu_operand2_o = 32'b0;
  // alu_op_o = 4'b0;

  // rf_raddr_a_o = 5'b0;
  // rf_raddr_b_o = 5'b0;
  // rf_waddr_o = 5'b0;
  // rf_wdata_o = 32'b0;
  // rf_we_o = 0;

  case(state)

    STATE_ID : begin
      rf_raddr_a_o = rs1;
      rf_raddr_b_o = rs2;
    end

    STATE_EXE : begin
      case(instruction_type)
        TYPE_I : begin
          // addi, andi
          alu_operand1_o = rs1_value;
          alu_operand2_o = imm_gen_result_i;
          if (funct3 == 3'b000) begin
            // addi
            alu_op_o = ALU_OP_ADD;
          end else begin
            // andi, funct3 = 111
            alu_op_o = ALU_OP_AND;
          end
        end

        TYPE_S : begin
          // sw, sb
          // calculate address
          alu_operand1_o = rs1_value;
          alu_operand2_o = imm_gen_result_i;
          alu_op_o = ALU_OP_ADD;
        end

        TYPE_B : begin
          // beq
          alu_operand1_o = pc_now_reg;
          alu_operand2_o = imm_gen_result_i;
          alu_op_o = ALU_OP_ADD;
        end

        TYPE_R : begin
          // add
          alu_operand1_o = rs1_value;
          alu_operand2_o = rs2_value;
          alu_op_o = ALU_OP_ADD;
        end

        // TYPE_U : begin
        //   // lui
        //   // do nothing here
        // end

        default : begin
          // alu_operand1_o = 32'b0;
          // alu_operand2_o = 32'b0;
          // alu_op_o = 4'b0;

          alu_operand1_o = 32'b0;
          alu_operand2_o = 32'b0;
          alu_op_o = 4'b0;

          rf_raddr_a_o = 5'b0;
          rf_raddr_b_o = 5'b0;
          rf_waddr_o = 5'b0;
          rf_wdata_o = 32'b0;
          rf_we_o = 0;
        end
      endcase
     end

    STATE_WB : begin
      rf_waddr_o = 5'b0;
      rf_wdata_o = 32'b0;
      rf_we_o = 0;

      if (if_wirte_reg) begin
        rf_waddr_o = write_reg_addr_o;
        rf_wdata_o = write_reg_data_o;
        rf_we_o = 1;
      end

    end

    // default : begin
    //   alu_operand1_o = 32'b0;
    //   alu_operand2_o = 32'b0;
    //   alu_op_o = 4'b0;
    //   rf_waddr_o = 5'b0;
    //   rf_wdata_o = 32'b0;
    //   rf_we_o = 0;
    // end
  endcase
end

logic from_wb_to_if_write_sram;

always_ff @ (posedge clk_i) begin
  if (rst_i) begin

    from_wb_to_if_write_sram <= 0;
    // reset all signals

    // reset model instantiation signals
    // register file
    // rf_raddr_a_o <= 5'b0;
    // rf_raddr_b_o <= 5'b0;
    // rf_waddr_o <= 5'b0;
    // rf_wdata_o <= 32'b0;
    // rf_we_o <= 0;

    // // alu
    // alu_a_o <= 32'b0;
    // alu_b_o <= 32'b0;
    // alu_op_o <= 4'b0;

    // imm generater
    // nothing to do here

    // reset wishbone master
    wb_cyc_o <= 0;
    wb_stb_o <= 0;
    wb_addr_o <= 32'b0;
    wb_data_o <= 32'b0;
    wb_sel_o <= 4'b0;
    wb_we_o <= 0;

    // reset internal registers

    // instruction_type <= 3'b0;
    // reset rs1 value and rs2 value
    rs1_value <= 32'b0;
    rs2_value <= 32'b0;

    pc_reg <= 32'h8000_0000;
    pc_now_reg <= 32'h8000_0000;
    inst_reg <= 32'b0;

    state <= STATE_IF;

    if_wirte_reg <= 0;
    write_reg_addr_o <= 5'b0;
    write_reg_data_o <= 32'b0;
    
    if_write_sram <= 0;
    write_sram_addr_o <= 32'b0;
    write_sram_data_o <= 32'b0;
    write_sram_sel_o <= 4'b0;


  end else begin
    case(state)
      STATE_IF: begin
          wb_addr_o <= pc_reg;
          wb_cyc_o <= 1'b1;
          wb_stb_o <= 1;
          wb_we_o <= 0; // read
          wb_sel_o <= 4'b1111; // read 4 bytes

          if (wb_ack_i) begin
              pc_reg <= pc_reg + 4; // 注意更新的位�?, wishbone请求�?, addr地址不能�?
              inst_reg <= wb_data_i; 
              pc_now_reg <= pc_reg;

              // close operation code
              wb_cyc_o <= 0;
              wb_stb_o <= 0;
              wb_sel_o <= 4'b0000;

              // // we have to set rf_addr_o in advance
              // rf_raddr_a_o <= rs1;
              // rf_raddr_b_o <= rs2;

              state <= STATE_ID;
          end else begin
              state <= STATE_IF;
          end
      end

      STATE_ID :begin
        // rf_raddr_a_o <= rs1;
        rs1_value <= rf_rdata_a_i;
        // rf_raddr_b_o <= rs2;
        rs2_value <= rf_rdata_b_i;
        state <= STATE_EXE;
      end

      STATE_EXE: begin

        // state <= STATE_WB;

        case(instruction_type)
          TYPE_I : begin
            // addi, andi, lb
            if (opcode == LB_OP)begin
              // lb
              // get data from sram

              if(wb_ack_i) begin
                // close operation code
                wb_cyc_o <= 0;
                wb_stb_o <= 0;
                wb_sel_o <= 4'b0;

                // get data
                if_wirte_reg <= 1;
                write_reg_data_o <= {24'b0 , wb_data_i[7:0]};
                write_reg_addr_o <= rd;

                state <= STATE_WB;
              end else begin
                // set operation code
                wb_cyc_o <= 1;
                wb_stb_o <= 1;

                wb_sel_o <= 4'b0001;

                // // sel
                // case (alu_result_i[1:0])
                //   2'b00 : begin
                //     wb_sel_o <= 4'b0001;
                //   end

                //   2'b01 : begin
                //     wb_sel_o <= 4'b0010;
                //   end

                //   2'b10 :begin
                //     wb_sel_o <= 4'b0100;
                //   end

                //   2'b11 : begin
                //     wb_sel_o <= 4'b1000;
                //   end

                // endcase

                // set specific code
                wb_addr_o <= alu_result_i;
                wb_we_o <= 0; // read
                
                state <= STATE_EXE;
              end
              
            end else begin
              // addi, andi
              if_wirte_reg <= 1;
              write_reg_data_o <= alu_result_i;
              write_reg_addr_o <= rd;

              state <= STATE_WB;
            end
          end

          TYPE_S : begin
            // store rs2 data to rs1 position
            if_write_sram <= 1;
            write_sram_data_o <= rs2_value;
            write_sram_addr_o <= alu_result_i;

            state <= STATE_WB;

            // sw, sb
            if (funct3 == 3'b000) begin
              // sb
              case (alu_result_i[1:0])
                2'b00 : begin
                  write_sram_sel_o <= 4'b0001;
                  write_sram_data_o <= rs2_value;
                end

                2'b01 : begin
                  write_sram_sel_o <= 4'b0010;
                  write_sram_data_o <= (rs2_value << 8);
                end

                2'b10 : begin
                  write_sram_sel_o <= 4'b0100;
                  write_sram_data_o <= (rs2_value << 16);
                end

                2'b11 : begin
                  write_sram_sel_o <= 4'b1000;
                  write_sram_data_o <= (rs2_value << 24);
                end
              endcase

              write_sram_sel_o <= 4'b0001;
            end else begin
              // sw funct3 = 010
              write_sram_sel_o <= 4'b1111;
            end
          end

          TYPE_B : begin
            // beq

            state <= STATE_WB;

            // 由于RISC-V指令长度必须是两个字节的倍数�?
            // 分支指令的寻�?方式�?12位的立即数乘�?2，符号扩展，
            // 然后加到PC上作为分支的跳转地址�?

            if (rs1_value == rs2_value) begin
              pc_reg <= alu_result_i;
            end
          end

          TYPE_R : begin
            // add

            state <= STATE_WB;

            if_wirte_reg <= 1;
            write_reg_data_o <= alu_result_i;
            write_reg_addr_o <= rd;

          end

          TYPE_U : begin
            // lui

            state <= STATE_WB;

            if_wirte_reg <= 1;
            write_reg_data_o <= imm_u;
            write_reg_addr_o <= rd;
          end

          default : begin
            if_wirte_reg <= 0;
            if_write_sram <= 0;

            state <= STATE_WB;
          end

        endcase

      end

      STATE_WB: begin
        // write reg down in combination logic
        // only need 1 circle

        // write sram will be done here
        if (if_write_sram) begin
          if (wb_ack_i) begin
            // write done
            wb_we_o <= 0;
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;
            // reset write signals
            if_wirte_reg <= 0;
            write_reg_addr_o <= 5'b0;
            write_reg_data_o <= 32'b0;
            
            if_write_sram <= 0;
            write_sram_addr_o <= 32'b0;
            write_sram_data_o <= 32'b0;
            write_sram_sel_o <= 4'b0;

            // so weired here
            if (from_wb_to_if_write_sram) begin
              // jump
              from_wb_to_if_write_sram <= 0;
              state <= STATE_IF;
            end else begin
              // wait for 1 cycle
              from_wb_to_if_write_sram <= 1;
              state <= STATE_WB;
            end
            // state <= STATE_IF;
          end else begin
            wb_we_o <= 1;
            // set signals
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            wb_sel_o <= write_sram_sel_o;
            wb_addr_o <= write_sram_addr_o;
            wb_data_o <= write_sram_data_o;
            state <= STATE_WB;
          end
        end else begin
          // do not need to write sram
          // reset write signals
          if_wirte_reg <= 0;
          write_reg_addr_o <= 5'b0;
          write_reg_data_o <= 32'b0;
          
          if_write_sram <= 0;
          write_sram_addr_o <= 32'b0;
          write_sram_data_o <= 32'b0;
          write_sram_sel_o <= 4'b0;
          state <= STATE_IF;
        end
        
      end
    endcase
  end
end                    

endmodule
