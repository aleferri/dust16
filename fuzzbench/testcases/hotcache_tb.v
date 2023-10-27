module hotcache_tb;

reg clk;
reg a_rst;
reg[2:0] rd_reg;
reg[15:0] rd_offset;
wire[15:0] rd_data;
wire rd_cached;
reg[2:0] crb_reg;
reg crb_commit;
reg cmd_cache;
reg[2:0] cmd_reg;
reg[15:0] cmd_offset;
reg[15:0] cmd_data;

hotcache tb_object(
    .clk(clk),
    .a_rst(a_rst),
    .rd_reg(rd_reg),
    .rd_offset(rd_offset),
    .rd_data(rd_data),
    .rd_cached(rd_cached),
    .crb_reg(crb_reg),
    .crb_commit(crb_commit),
    .cmd_cache(cmd_cache),
    .cmd_reg(cmd_reg),
    .cmd_offset(cmd_offset),
    .cmd_data(cmd_data)
);


always begin
    clk = #1000 ~clk;
end

initial begin
    clk = 1'b0;
    a_rst = 1'b1;
    rd_reg = 2'b00;
    rd_offset = 15'b000000000000000;
    crb_reg = 2'b00;
    crb_commit = 1'b0;
    cmd_cache = 1'b0;
    cmd_reg = 2'b00;
    cmd_offset = 15'b000000000000000;
    cmd_data = 15'b000000000000000;
    a_rst = #2000 1'b0;
    a_rst = #2000 1'b1;
end

endmodule
