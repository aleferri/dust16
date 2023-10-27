module core_tb;

reg[7:0] cells[0:15];

reg clk;
reg rst;
reg m_wait;
reg[7:0] m_indata;
wire[7:0] m_outdata;
wire[15:0] m_addr;
wire m_req;
wire m_wr;

`define SIM_DEBUG

core tb_object(
    .clk(clk),
    .rst(rst),
    .m_wait(m_wait),
    .m_indata(m_indata),
    .m_outdata(m_outdata),
    .m_addr(m_addr),
    .m_req(m_req),
    .m_wr(m_wr)
);


always @(posedge clk) begin
    clk = #10 1'b0;
end

always @(negedge clk) begin
	clk = #10 1'b1;
end

always @(negedge clk) begin
	m_indata = cells[m_addr[3:0]];
	
	$display("rd @%d value %d\n", m_addr[3:0], m_indata);
	
	if (m_req & m_wr) begin
		$display("wr @%d value %d\n", m_addr[3:0], m_outdata);
		cells[m_addr[3:0]] = m_outdata;
	end
end

initial begin
    clk = 1'b0;
    rst = 1'b1;
    m_wait = 1'b0;
    m_indata = 8'b0;
	cells[0] = 8'b00010000; // LDI
	cells[1] = 8'b01010101; // PATTERN
	cells[2] = 8'b10101010; // PATTERN
	cells[3] = 8'b10100000; // MVX
	cells[4] = 8'b10000100; // LDA
	cells[5] = 8'b00010000; // LDI
	cells[6] = 8'b00000001; // LOW BYTE 
	cells[7] = 8'b00000000; // HIGH BYTE
	cells[8] = 8'b10001000; // ADD AC, DR
	cells[9] = 8'b10001000; // ADD AC, DR
	cells[10] = 8'b10001000; // ADD AC, DR
	cells[11] = 8'b10001000; // ADD AC, DR
	cells[12] = 8'b10001000; // ADD AC, DR
	cells[13] = 8'b10001000; // ADD AC, DR
	cells[14] = 8'b10001000; // ADD AC, DR
	cells[15] = 8'b10001000; // ADD AC, DR
	#30 rst = 1'b0;
	
	#600 $finish();
end

endmodule
