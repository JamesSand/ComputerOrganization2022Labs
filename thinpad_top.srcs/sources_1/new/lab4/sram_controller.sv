module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface  slave and master
    input wire wb_cyc_i, // always 0, master occupy slave 
    input wire wb_stb_i, // master send instruction 1
    output reg wb_ack_o, // slave done instruction 1
    input wire [ADDR_WIDTH-1:0] wb_adr_i, // address that master want to operate
    input wire [DATA_WIDTH-1:0] wb_dat_i, // data input
    output reg [DATA_WIDTH-1:0] wb_dat_o, // data output
    input wire [DATA_WIDTH/8-1:0] wb_sel_i, // bytes enable
    input wire wb_we_i, // master want to write or read

    // sram interface
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output reg sram_ce_n, 
    output reg sram_oe_n,
    output reg sram_we_n,
    output reg [SRAM_BYTES-1:0] sram_be_n // byter enable
);

  // TODO: 实现 SRAM 控制器

wire [31:0] sram_data_i_comb;
reg [31:0] sram_data_o_comb;
reg sram_data_t_comb;

assign sram_data = sram_data_t_comb ? 32'bz : sram_data_o_comb;
assign sram_data_i_comb = sram_data;

always_comb begin
  sram_be_n = ~wb_sel_i; // sram be
  sram_addr = wb_adr_i[21 : 2]; // sram addr
end

// automation states
typedef enum logic [2:0] {
  STATE_IDLE = 0,
  STATE_READ = 1,
  STATE_READ_2 = 2,
  STATE_WRITE = 3,
  STATE_WRITE_2 = 4,
  STATE_WRITE_3 = 5,
  STATE_DONE = 6
} state_t;

state_t state;

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        state <= STATE_IDLE;

        sram_ce_n <= 1;
        sram_oe_n <= 1;
        sram_we_n <= 1;

        wb_ack_o <= 0;
        wb_dat_o <= 32'b0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (wb_stb_i && wb_cyc_i) begin
                    if (wb_we_i) begin

                      // data
                      sram_data_o_comb <= wb_dat_i;
                      sram_data_t_comb <= 0;

                      // sram control
                      sram_ce_n <= 0;
                      sram_oe_n <= 1;
                      sram_we_n <= 1;

                      state <= STATE_WRITE;
                    end else begin

                      sram_data_t_comb <= 1;

                      // sram control
                      sram_ce_n <= 0;
                      sram_oe_n <= 0;
                      sram_we_n <= 1;

                      state <= STATE_READ;
                    end
                end
            end
            STATE_READ: begin
              // 第二个周期（b）：按照要求输出 addr, oe_n=0, ce_n=0, we_n=1, 
              // 根据 SEL_I=0b1111 可知四个字节都要读取，所以输出 be_n=0b0000，
              // 此时状态是 READ，下一个状态是 READ_2

              // do nothing here

              state <= STATE_READ_2;
            end
            STATE_READ_2: begin
              // 第三个周期（c）：这时候 SRAM 返回了数据，
              // 把数据保存到寄存器中，此时状态是 READ_2，下一个状态是 DONE

              wb_dat_o <= sram_data_i_comb; // send data to master
              sram_ce_n <= 1; // make SRAM sleep
              wb_ack_o <= 1; // tell master task complete

              state <= STATE_DONE;
            end

            STATE_WRITE: begin
              // 第二个周期（b）：按照要求输出 addr, data, oe_n=1, ce_n=0, we_n=1，
              // 根据 SEL_I=0b1111 可知四个字节都要写入，所以输出 be_n=0b0000，
              // 此时状态是 WRITE，下一个状态是 WRITE_2

              sram_we_n <= 0;

              state <= STATE_WRITE_2;
            end

            STATE_WRITE_2: begin
              // 第三个周期（c）：按照要求输出 we_n=0，
              // 此时状态是 WRITE_2，下一个状态是 WRITE_3

              sram_we_n <= 1;

              state <= STATE_WRITE_3;
            end

            STATE_WRITE_3: begin
              // 第四个周期（d）：按照要求输出 we_n=1，
              // 此时状态是 WRITE_3，下一个状态是 DONE

              sram_ce_n <= 1; // make sram sleep
              wb_ack_o <= 1; // tell master task done

              state <= STATE_DONE;
            end

            STATE_DONE: begin
              // 第四个周期（e）：输出 ce_n=1 让 SRAM 恢复空闲状态，设置 ACK_O=1，
              // 此时请求完成，状态是 DONE，下一个状态是 IDLE

              wb_ack_o <= 0; // close ack
              
              state <= STATE_IDLE;
            end
        endcase
    end
end




endmodule
