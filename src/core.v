
// STATUS:
// 000: KEEP
// 001: PRE-FETCH
// 010: FETCH
// 011: DECODE
// 100: LD_BYTE_L
// 101: LD_BYTE_H
// 110: ST_BYTE_L
// 111: ST_BYTE_H

module core#(
    parameter ADR_MSB = 15,
    parameter DAT_MSB = 15
)(
    input       wire            clk,
    input       wire            rst,
    
    input       wire            m_wait,
    input       wire[7:0]       m_idata,
    output      wire[7:0]       m_odata,
    output      wire[ADR_MSB:0] m_addr,
    output      wire            m_cs,
    output      wire            m_we
);

localparam CS_HOLD      = 3'b000;
localparam CS_PRE_FETCH = 3'b001;
localparam CS_FETCH     = 3'b010;
localparam CS_DECODE    = 3'b011;
localparam CS_LD_BYTE_L = 3'b100;
localparam CS_LD_BYTE_H = 3'b101;
localparam CS_ST_BYTE_L = 3'b110;
localparam CS_ST_BYTE_H = 3'b111;


localparam OP_LDI = 3'b000; // 4'b0001
localparam OP_LDM = 3'b001; // 4'b001w
localparam OP_STM = 3'b010; // 4'b010w
localparam OP_ALU = 3'b100; // operate alu
localparam OP_MVX = 3'b101; // move DR to ix
localparam OP_MVT = 3'b101; // move ix/ac to TR
localparam OP_JMP = 3'b110; // direct jump to dr address, if ir[0] is 1, PC is saved to LR
localparam OP_JPC = 3'b111; // 4'b111c where c = condition (0: carry, 1: ac == 0)

reg [DAT_MSB:0] dr;         // Data register, target of every load
reg [DAT_MSB:0] ac;         // Accumulator, is the first source and the destination of all ALU ops
reg [DAT_MSB:0] tr;         // Transfer register

reg [ADR_MSB:0] ix;         // Index register, point to the address of any memory instruction
reg [ADR_MSB:0] pc;         // Program counter, point to the next instruction
reg [5:0]       ir;         // Instruction register, hold the current opcode
reg [7:0]       db;         // Data buffer, buffer either the top 8 bit or the lower 8 bit of the register
reg             ac_isz;     // AC is zero
reg             ac_carry;   // Carry is present

reg [2:0]       status;     // Status of the core

reg             ar_sel;     // Select IX/PC for the address output
reg             ar_set_bit; // Force Set the LSB of the address
reg             mem_req;    // Memory required
reg             mem_wr;     // Memory write

assign m_addr = ar_sel ? pc[ADR_MSB:0] : { ix[ADR_MSB:1], ix[0] | ar_set_bit };
assign m_odata = db;
assign m_cs = mem_req;
assign m_we = mem_wr;

reg is_fetch;
reg is_decode;
reg is_ld_byte;
reg is_ld_byte_l;

wire is_ldi = ~ir[5] & ~ir[4] & ~ir[3];
wire is_ldm = ~ir[5] & ~ir[4] & ir[3];
wire is_stm = ~ir[5] & ir[4] & ~ir[3];
wire is_stl = ~ir[5] & ir[4] & ir[3];
wire is_alu = ir[5] & ~ir[4] & ~ir[3];
wire is_mvx = ir[5] & ~ir[4] & ir[3] & ~ir[2] & ~ir[1];
wire is_inx = ir[5] & ~ir[4] & ir[3] & ~ir[2] & ir[1];
wire is_mvt = ir[5] & ~ir[4] & ir[3] & ir[2];
wire is_jmp = ir[5] & ir[4] & ~ir[3];
wire is_jpc = ir[5] & ir[4] & ir[3];

wire is_mem_op = ~ir[5];
wire is_full_word = ir[2];
wire[2:0] next_mem_status  = { 1'b1, ir[4], 1'b0 };     

always @(posedge clk) begin
    if (is_ld_byte_l) begin     // NOTE, if m_idata is garbage (so m_wait is zero) the read will be repeated
        dr[7:0] <= m_idata;
    end
    if (is_ld_byte) begin       // NOTE, if m_idata is garbage (so m_wait is zero) the read will be repeated
        dr[DAT_MSB:8] <= m_idata & { status[0], status[0], status[0], status[0], status[0], status[0], status[0], status[0] };
    end
end

wire use_alu_sel = is_decode & is_alu;
wire[2:0] alu_sel = ir[2:0] & { use_alu_sel, use_alu_sel, use_alu_sel };

// pseudo reg
reg[DAT_MSB:0] alu_rs;
reg carry;

always @(*) begin
    case(alu_sel)
        3'b000: { carry, alu_rs } = { ac_carry, ac };
        3'b001: { carry, alu_rs } = { 1'b0, dr };
        3'b010: { carry, alu_rs } = ac + dr;
        3'b011: { carry, alu_rs } = ac + ~dr + 1'b1;
        3'b100: { carry, alu_rs } = { 1'b0, ac & dr };
        3'b101: { carry, alu_rs } = { 1'b0, ac | dr };
        3'b110: { carry, alu_rs } = { 1'b0, ac ^ dr };
        3'b111: { carry, alu_rs } = { ac[0], ac_carry, ac[DAT_MSB:1] };
    endcase
end

always @(posedge clk) begin
    if (is_fetch) begin         // NOTE, even if memory is garbage, the opcode will be fetched again next cycle because ~m_wait
        ir <= m_idata[7:2];
    end
end

// pseudo
reg[2:0] next_status;

wire hold_status = rst | mem_req & m_wait;
wire[2:0] masked_status = status & { ~hold_status, ~hold_status, ~hold_status };

always @(*) begin
    case (masked_status)
        CS_HOLD      : next_status = rst ? CS_PRE_FETCH : status;
        CS_PRE_FETCH : next_status = CS_FETCH;
        CS_FETCH     : next_status = CS_DECODE;
        CS_DECODE    : next_status = is_mem_op ? next_mem_status : CS_PRE_FETCH;
        CS_LD_BYTE_L : next_status = is_full_word ? CS_LD_BYTE_H : CS_PRE_FETCH;
        CS_LD_BYTE_H : next_status = CS_PRE_FETCH;
        CS_ST_BYTE_L : next_status = is_full_word ? CS_ST_BYTE_H : CS_PRE_FETCH;
        CS_ST_BYTE_H : next_status = CS_PRE_FETCH;
        default      : next_status = CS_PRE_FETCH;
    endcase
end

wire will_write_mem = (next_status[2] & next_status[1]);

always @(posedge clk) begin
    mem_wr <= will_write_mem;
    mem_req <= next_status[2] | (next_status == CS_FETCH);
	 
    ar_set_bit <= next_status[2] & next_status[0];    
    ar_sel <= ( ~next_status[2] & ( ~next_status[1] ^ ~next_status[2] ) ) | (next_status[2] & is_ldi) | rst;

    db <= next_status ? tr[DAT_MS:8] : tr[7:0];
	
	`ifdef SIM_DEBUG
	
	$display("From status %b", status);
	$display("To status %b\n", next_status);
	$display("Is mem op %b %b", is_mem_op, is_full_word);
	
	`endif
    
    status <= next_status;
    
    is_fetch <= next_status == CS_FETCH;
    is_decode <= next_status == CS_DECODE;
    is_ld_byte <= next_status[2] & ~next_status[1];
    is_ld_byte_l <= next_status == CS_LD_BYTE_L;
end

always @(posedge clk) begin
    if (is_decode & is_mvx) begin
        ix <= dr;
    end else begin
        ix <= ix + (is_decode & is_inx);
    end
end 

wire is_jal = is_jmp & ir[0];

always @(posedge clk) begin
    case ({ is_decode & is_mvt, is_decode & (is_mvt | is_jal)})
    2'b00: tr <= tr;
    2'b01: tr <= pc;
    2'b10: tr <= ac;
    2'b11: tr <= ix;
    endcase
end

always @(posedge clk) begin
    ac <= alu_rs;
    ac_isz <= (ac == 16'b0);
	ac_carry <= carry;
end

wire do_jpc = ac_isz & ~ir[2] | ac_carry & ir[2];

wire ld_pc = (is_decode & (is_jmp | is_jpc & do_jpc)) | rst;
wire inc_pc = (is_fetch | is_ld_byte) & ar_sel & ~m_wait;

always @(posedge clk) begin
	if (ld_pc) begin
        pc <= rst ? 16'b0 : dr;
    end else begin
        pc <= pc + inc_pc;
    end
end

`ifdef SIM_DEBUG

always @(negedge clk) begin
	$display("ASEL: %d", ar_sel);
	$display("ADR: %d", m_addr);
	$display("PC: %d", pc);
	$display("IR: %d", ir);
	$display("AC: %d", ac);
    $display("TR: %d", tr);
	$display("DR: %b", dr);
	$display("IX: %d\n", ix);
end

`endif

endmodule
