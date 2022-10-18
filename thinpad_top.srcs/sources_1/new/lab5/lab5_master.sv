module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: 添加�?要的控制信号，例如按键开关？
    input wire [ADDR_WIDTH - 1: 0] addr_i, // addr

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

  // TODO: 实现实验 5 的内�?+串口 Master

// status machine
typedef enum logic [3:0] {
  // read uart
  READ_WAIT_ACTION = 0,
  READ_WAIT_CHECK = 1,
  READ_DATA_ACTION = 2,
  READ_DATA_DONE = 3,

  // write sram
  WRITE_SRAM_ACTION = 4,
  WRITE_SRAM_DONE = 5,

  // write uart
  WRITE_WAIT_ACTION = 6,
  WRITE_WAIT_CHECK = 7,
  WRITE_DATA_ACTION = 8,
  WRITE_DATA_DONE = 9
  
} state_t;

state_t state;

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
    addr_reg <= (addr_i & 32'hFFFFFFFC);

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
