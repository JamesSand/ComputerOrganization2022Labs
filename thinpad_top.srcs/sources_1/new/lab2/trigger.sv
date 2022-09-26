module trigger(
    // 时钟与复位信号，每个时序模块都必须包含
  input wire clk,
  input wire reset,
  input wire push_btn,

  // 计数触发信号
  output wire trigger
);

reg xiaodou_reg;
reg trigger_reg;

always_ff @ (posedge clk) begin
    // if(push_btn) begin
    //     trigger_reg <= 1'd1;
    // end else begin
    //     trigger_reg <= 1'd0;
    // end

    if(xiaodou_reg == 1'd0) begin
        if(push_btn == 1'd1) begin
            // push button 的上升沿
            trigger_reg <= 1'd1;
            xiaodou_reg <= 1'd1;
        end else begin
            trigger_reg <= 1'd0;
        end
    end else begin
        trigger_reg <= 1'd0;
        if(push_btn == 1'd0) begin
            xiaodou_reg <= 1'd0;
        end
    end
end

assign trigger = trigger_reg;

endmodule

