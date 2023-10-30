module core_tb;

reg[7:0] sram[0:4096];

reg clk;
reg rst;
reg m_wait;
reg[7:0] m_idata;
wire[7:0] m_odata;
wire[15:0] m_addr;
wire m_cs;
wire m_we;

localparam OP_LDI_W = 8'b00010000;
localparam OP_LDI_B = 8'b00000000;
localparam OP_LDM_W = 8'b00110000;
localparam OP_LDM_B = 8'b00100000;
localparam OP_STM_W = 8'b01010000;
localparam OP_STM_B = 8'b01000000;
localparam OP_JAL_W = 8'b01110000;
localparam OP_NOP   = 8'b10000000;
localparam OP_MVA   = 8'b10000100;
localparam OP_ADD   = 8'b10001000;
localparam OP_SUB   = 8'b10001100;
localparam OP_AND   = 8'b10010000;
localparam OP_ORA   = 8'b10010100;
localparam OP_XOR   = 8'b10011000;
localparam OP_ROR   = 8'b10011100;
localparam OP_MVX   = 8'b10100000;
localparam OP_JMP   = 8'b11000000;
localparam OP_JCS   = 8'b11100000;
localparam OP_JZA   = 8'b11110000;

core tb_object(
    .clk(clk),
    .rst(rst),
    .m_wait(m_wait),
    .m_idata(m_idata),
    .m_odata(m_odata),
    .m_addr(m_addr),
    .m_cs(m_cs),
    .m_we(m_we)
);


always @(posedge clk) begin
    clk = #10 1'b0;
end

always @(negedge clk) begin
	clk = #10 1'b1;
end

always @(negedge clk) begin
	m_idata = sram[m_addr[3:0]];
	
	$display("rd @%d value %d\n", m_addr[3:0], m_idata);
	
	if (m_cs & m_we) begin
		$display("wr @%d value %d\n", m_addr[3:0], m_odata);
		sram[m_addr[3:0]] = m_odata;
	end
end

initial begin
    clk = 1'b0;
    rst = 1'b1;
    m_wait = 1'b0;
    m_idata = 8'b0;

    // PROGRAM
	$readmemb( "./test/test.bin", sram );
    // Reset logic
	#30 rst = 1'b0;
	
	#600 $finish();
end

endmodule
