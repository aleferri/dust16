
// IR:
// 000xx -> ALU1
// 001xx -> ALU2
// 010xx -> MVX
// 011b0 -> LDB/LDW
// 01111 -> LDI
// 100bx -> STB/STW
// 1011l -> JMP/JAL
// 110xx -> JZA
// 111xx -> JCA

// STATUS:
// 000: KEEP
// 001: PRE-FETCH
// 010: FETCH
// 011: DECODE
// 100: LD_BYTE_L
// 101: LD_BYTE_H
// 110: ST_BYTE_L
// 111: ST_BYTE_H

/*
read_verilog F:\Progetti\CPU\Architetture\Developing\Dust16\core.v
proc
wreduce
opt
freduce
opt
fsm
opt
pmuxtree
opt
muxcover
opt
techmap
wreduce
freduce
opt
*/

module core#(
    parameter ADR_TOP = 15,
    parameter DAT_TOP = 15
)(
    input       wire            clk,
    input       wire            rst,
    
    input       wire            m_wait,
    input       wire[7:0]       m_indata,
    output      wire[7:0]       m_outdata,
    output      wire[ADR_TOP:0] m_addr,
    output      wire            m_req,
    output      wire            m_wr
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
localparam OP_JAL = 3'b011; // 4'b0111
localparam OP_ALU = 3'b100; // operate alu
localparam OP_MVX = 3'b101; // move to x
localparam OP_JMP = 3'b110; // direct jump
localparam OP_JPC = 3'b111; // 4'b111c where c = condition (0: ac[15], 1: ac == 0)

reg [DAT_TOP:0] dr;
reg [DAT_TOP:0] ac;
reg [ADR_TOP:0] ix;
reg [ADR_TOP:0] pc;
reg [5:0]  ir;
reg [7:0]  db;

reg [2:0] status;

reg ar_sel;
reg ar_set_bit;
reg mem_req;
reg mem_wr;

assign m_addr = ar_sel ? { pc[ADR_TOP:1], pc[0] | ar_set_bit } : { ix[ADR_TOP:1], ix[0] | ar_set_bit };
assign m_outdata = db;
assign m_req = mem_req;
assign m_wr = mem_wr;

wire is_fetch = status == CS_FETCH;
wire is_decode = status == CS_DECODE;
wire is_ld_byte_l = status == CS_LD_BYTE_L;
wire is_ld_byte_h = status == CS_LD_BYTE_H;
wire is_st_byte_l = status == CS_ST_BYTE_L;
wire is_st_byte_h = status == CS_ST_BYTE_H;

wire is_ldi = ~ir[5] & ~ir[4] & ~ir[3];
wire is_ldm = ~ir[5] & ~ir[4] & ir[3];
wire is_stm = ~ir[5] & ir[4] & ~ir[3];
wire is_jal = ~ir[5] & ir[4] & ir[3];
wire is_alu = ir[5] & ~ir[4] & ~ir[3];
wire is_mvx = ir[5] & ~ir[4] & ir[3];
wire is_jmp = ir[5] & ir[4] & ~ir[3];
wire is_jpc = ir[5] & ir[4] & ir[3];

wire is_mem_op = ~ir[5];
wire is_full_word = ir[2];
wire[2:0] next_mem_status  = { 1'b1, ir[4], 1'b0 };

wire dr_rdl = is_ld_byte_l & ~m_wait;
wire dr_rdh = is_ld_byte_h & ~m_wait;
wire ir_rd  = is_fetch & ~m_wait;

always @(posedge clk) begin
    if (dr_rdl) begin
        dr[7:0] <= m_indata;
    end
    if (dr_rdh) begin
        dr[DAT_TOP:8] <= m_indata;
    end
end

wire use_alu_sel = is_decode & is_alu;
wire[2:0] alu_sel = ir[2:0] & { use_alu_sel, use_alu_sel, use_alu_sel };

// pseudo reg
reg[DAT_TOP:0] alu_rs;

always @(*) begin
    case(alu_sel)
        3'b000: alu_rs = ac;
        3'b001: alu_rs = dr;
        3'b010: alu_rs = ac + dr;
        3'b011: alu_rs = ac + ~dr + 1'b1;
        3'b100: alu_rs = ac & dr;
        3'b101: alu_rs = ac | dr;
        3'b110: alu_rs = ac ^ dr;
        3'b111: alu_rs = { 1'b0, ac[DAT_TOP:1] };
    endcase
end

always @(posedge clk) begin
    if (ir_rd) begin
        ir <= m_indata[7:2];
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
	 ar_sel <= (next_status == CS_FETCH) | (next_status[2] & is_ldi);
    
    if (next_status == CS_ST_BYTE_H) begin
        db <= ir[2] ? pc[ADR_TOP:8] : ac[DAT_TOP:8];
    end else begin
        db <= ir[2] ? pc[7:0] : ac[7:0];
    end
    
    status <= next_status;
end

always @(posedge clk) begin
    if (is_decode & is_mvx) begin
        ix <= dr;
    end
end

always @(posedge clk) begin
    ac <= alu_rs;
end

wire ac_isz = (ac == 16'b0);
wire do_jpc = ac_isz & ~ir[2] | ac[15] & ir[2];

wire ld_pc = (is_decode & (is_jmp | is_jpc & do_jpc)) || (is_st_byte_h & is_jal & ~m_wait);
wire inc_pc = (is_fetch | is_ld_byte_l | is_ld_byte_h) & ar_sel & ~m_wait;

always @(posedge clk) begin
	 if (ld_pc) begin
        pc <= dr;
    end else begin
        pc <= pc + inc_pc;
    end
end

endmodule
