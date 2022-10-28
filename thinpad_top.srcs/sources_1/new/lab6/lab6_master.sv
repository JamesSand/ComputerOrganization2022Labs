


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
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o // 0 for read, 1 for write
);


// lab6 code below

reg [31:0] pc_reg;
reg [31:0] pc_now_reg;
reg [31:0] inst_reg;

// instruction parser
logic [6 : 0] opcode;
logic [2 : 0] funct3;
logic [4 : 0] rd, rs1, rs2;

logic [11:0] imm_i;
logic [11:0] imm_s;
logic [12:0] imm_b;
logic [31:0] imm_u;


// instruction should be wb_dat_i
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

end

// status machine
// four states required
typedef enum logic [3:0] {
    STATE_IF = 0,
    STATE_ID = 1,
    STATE_EXE = 2,
    STATE_WB = 3
} state_t;

state_t state;

// cpu
always_comb begin
    ...
    case(state)
        STATE_IF: begin
            wb_addr_o = pc_reg;
            wb_cyc_o = 1'b1;
            alu_operand1_o = pc_reg;
            alu_operand2_o = 32'h00000004;
            alu_op_o = ALU_ADD;
        end

        STATE_ID : begin

        end

        STATE_EXE : begin

        end

        STATE_WB : begin

        end
    endcase
end
always_ff @ (posedge clk) begin
  if (rst_i) begin
    // reset all signals
    ...
  end else begin
    case(state)
      STATE_IF: begin
          inst_reg <= wb_data_i;
          pc_now_reg <= pc_reg;
          ...
          if (wb_ack_i) begin
              pc_reg <= alu_result_i; // 注意更新的位置, wishbone请求时, addr地址不能变
              state <= STATE_ID;
          end
      ...
      end

      STATE_ID :begin

      end

      STATE_EXE : begin

      end

      STATE_WB : begin

      end
    endcase
  end
end                    


// lab5 code below



reg [3 : 0] counter;
reg [31 : 0] addr_reg; 

// additional reg
reg read_able;
reg write_able;
reg [7 : 0] read_data;

always_ff @( posedge clk_i ) begin
  if (rst_i) begin
    // reset all signal
    state <= READ_WAIT_ACTION;

    // reset output signal
    wb_cyc_o <= 0;
    wb_stb_o <= 0;
    wb_adr_o <= 32'b0;
    wb_dat_o <= 32'b0;
    wb_sel_o <= 4'b0;
    wb_we_o <= 0;

    // get address
    // addr_reg <= (addr_i & 32'hFFFFFFFC);
    addr_reg <= {addr_i[31 : 2] , 2'b0};

    // reset counter
    counter <= 4'd0;
    read_able <= 0;
    write_able <= 0;
    read_data <= 32'b0;

  end else begin
      case (state)
        // read uart
        READ_WAIT_ACTION: begin
          // 读串口需要循环读取串口控制器的状态寄存器
          // （地�?�? 0x1000_0005�?

          // check ack
          if (wb_ack_i == 1) begin
            // 0x10000005	[0]	只读�?
            // �? 1 时表示串口收到数�?
            read_able <= wb_dat_i[0];
            // read signal check
            state <= READ_WAIT_CHECK;
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;
          end else begin
            // wait for ack
            wb_adr_o <= 32'h1000_0005;
            wb_we_o <= 0; // read
            wb_sel_o <= 4'b1111;
            // operation code
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            // keep wait for ack
            state <= READ_WAIT_ACTION;
          end
        end

        READ_WAIT_CHECK: begin
          if (read_able == 1) begin
            // start to read
            state <= READ_DATA_ACTION;
          end else begin
            // can not read 
            state <= READ_WAIT_ACTION;
          end
        end

        READ_DATA_ACTION: begin
          // check ack
          if (wb_ack_i == 1) begin
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;
            // save data
            read_data <= wb_dat_i[7 : 0];
            // read data done
            state <= READ_DATA_DONE;
          end else begin
            // 0x10000000	[7:0]	串口数据�?
            // 读�?�写地址分别表示串口接收、发送一个字�?
            // wait for ack
            wb_adr_o <= 32'h1000_0000;
            wb_we_o <= 0; // read
            wb_sel_o <= 4'b0001;
            // operation code
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            // keep wait for ack
            state <= READ_DATA_ACTION;
          end
        end

        READ_DATA_DONE: begin
          // write read data to sram
          state <= WRITE_SRAM_ACTION;
          // read able reg done
          read_able <= 0;
        end

        // write sram
        WRITE_SRAM_ACTION: begin
          // check ack
          if (wb_ack_i == 1) begin
            // write sram done
            // add 4 to addr
            addr_reg <= addr_reg + 32'd4;
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;

            state <= WRITE_SRAM_DONE;
          end else begin
            // wait for ack
            wb_adr_o <= addr_reg;
            wb_we_o <= 1; // write
            wb_dat_o <= read_data; // write data
            wb_sel_o <= 4'b0001;
            // operation code
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            // keep wait ack
            state <= WRITE_SRAM_ACTION;
          end
        end

        WRITE_SRAM_DONE: begin
          // write back to uart
          state <= WRITE_WAIT_ACTION;
        end

        // write uart
        WRITE_WAIT_ACTION: begin
          // 0x10000005	[5]	只读�?
          // �? 1 时表示串口空闲，可发送数�?
          // check ack
          if (wb_ack_i == 1) begin
            write_able <= wb_dat_i[5];
            state <= WRITE_WAIT_CHECK;
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;
          end else begin
            // wait for ack
            wb_adr_o <= 32'h1000_0005;
            wb_we_o <= 0; // read
             wb_sel_o <= 4'b1111;
            // operation code
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            state <= WRITE_WAIT_ACTION;
          end
        end

        WRITE_WAIT_CHECK: begin
          if (write_able == 1) begin
            state <= WRITE_DATA_ACTION;
          end else begin
            state <= WRITE_WAIT_ACTION;
          end
        end

        WRITE_DATA_ACTION: begin
          if(wb_ack_i == 1) begin
            // close operation code
            wb_cyc_o <= 0;
            wb_stb_o <= 0;
            wb_sel_o <= 4'b0000;
            state <= WRITE_DATA_DONE;
          end else begin
            wb_adr_o <= 32'h1000_0000;
            wb_we_o <= 1; // write
            wb_dat_o <= read_data;
            wb_sel_o <= 4'b0001;
            // operation code
            wb_cyc_o <= 1;
            wb_stb_o <= 1;
            // keep wait for ack
            state <= WRITE_DATA_ACTION;
          end
        end

        WRITE_DATA_DONE: begin
          // write able done
          write_able <= 0;
          if (counter < 4'd10) begin
            state <= READ_WAIT_ACTION;
            counter <= counter + 4'd1;
          end else begin
            // all done
            state <= WRITE_DATA_DONE;
          end
        end

      endcase
    end
end

endmodule
