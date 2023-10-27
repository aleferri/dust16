
// Hot cache for memory value, instruction pattern indexed [RX, Offset]

module hotcache(
    input   wire        clk,            /* Clock */
    input   wire        a_rst,          /* Reset */
    
    input   wire[2:0]   rd_reg,         /* Index register (Cache Read) */
    input   wire[15:0]  rd_offset,      /* Relative offset (Cache Read) */
    output  wire[15:0]  rd_data,        /* Data at address */
    output  wire        rd_cached,      /* Data at address is cached */
    
    input   wire[2:0]   crb_reg,        /* Common Result Bus write register */
    input   wire        crb_commit,     /* Common Result Bus commit */
    
    input   wire        cmd_cache,      /* Cache command */
    input   wire[2:0]   cmd_reg,        /* Cache index register command */
    input   wire[15:0]  cmd_offset,     /* Cache offset */
    input   wire[15:0]  cmd_data        /* Cache data to write */
);

reg[15:0] cache[0:32];
reg[7:0]  cache_line_valid_rs;
reg[7:0]  cache_line_valid_rx;
reg[7:0]  cache_line_valid_ry;
reg[7:0]  cache_line_valid_rz;

reg[3:0]  comb_rd_decoded;
reg[7:0]  comb_offset_decoded;
reg[7:0]  comb_cmd_offset_decoded;

always @(*) begin
    case ( rd_reg[1:0] )
    2'b00: comb_rd_decoded = 4'b0001;
    2'b01: comb_rd_decoded = 4'b0010;
    2'b10: comb_rd_decoded = 4'b0100;
    2'b11: comb_rd_decoded = 4'b1000;
    endcase
end

always @(*) begin
    case ( rd_offset[2:0] )
    3'b000: comb_offset_decoded = 8'b00000001;
    3'b001: comb_offset_decoded = 8'b00000010;
    3'b010: comb_offset_decoded = 8'b00000100;
    3'b011: comb_offset_decoded = 8'b00001000;
    3'b100: comb_offset_decoded = 8'b00010000;
    3'b101: comb_offset_decoded = 8'b00100000;
    3'b110: comb_offset_decoded = 8'b01000000;
    3'b111: comb_offset_decoded = 8'b10000000;
    endcase
end

always @(*) begin
    case ( cmd_offset[3:1] )
    3'b000: comb_cmd_offset_decoded = 8'b00000001;
    3'b001: comb_cmd_offset_decoded = 8'b00000010;
    3'b010: comb_cmd_offset_decoded = 8'b00000100;
    3'b011: comb_cmd_offset_decoded = 8'b00001000;
    3'b100: comb_cmd_offset_decoded = 8'b00010000;
    3'b101: comb_cmd_offset_decoded = 8'b00100000;
    3'b110: comb_cmd_offset_decoded = 8'b01000000;
    3'b111: comb_cmd_offset_decoded = 8'b10000000;
    endcase
end

wire is_in_range = rd_reg[2] & ~rd_offset[15] & ~rd_offset[14] & ~rd_offset[13] & ~rd_offset[12] & ~rd_offset[11] & ~rd_offset[10] & ~rd_offset[9] & ~rd_offset[8] & ~rd_offset[7] & ~rd_offset[6] & ~rd_offset[5] & ~rd_offset[4] & ~rd_offset[0];

wire comb_rd_rs = comb_rd_decoded[0] & is_in_range & ( ( cache_line_valid_rs & comb_offset_decoded ) != 8'b00000000 );
wire comb_rd_rx = comb_rd_decoded[1] & is_in_range & ( ( cache_line_valid_rx & comb_offset_decoded ) != 8'b00000000 );
wire comb_rd_ry = comb_rd_decoded[2] & is_in_range & ( ( cache_line_valid_ry & comb_offset_decoded ) != 8'b00000000 );
wire comb_rd_rz = comb_rd_decoded[3] & is_in_range & ( ( cache_line_valid_rz & comb_offset_decoded ) != 8'b00000000 );

wire affected_commit = crb_commit & crb_reg[2];

wire commit_invalidate = affected_commit & ( crb_reg[1:0] == rd_reg[1:0] ); 
wire commit_dispute    = affected_commit & ( crb_reg[1:0] == cmd_reg[1:0] );
wire[7:0] commit_dispute_mask = { ~commit_dispute, ~commit_dispute, ~commit_dispute, ~commit_dispute, ~commit_dispute, ~commit_dispute, ~commit_dispute, ~commit_dispute };

reg[15:0] comb_rd_data;
reg       comb_rd_cached;

always @(*) begin
    comb_rd_data = cache[ { rd_reg[1:0], rd_offset[3:1] } ];
    comb_rd_cached = ~commit_invalidate & ( comb_rd_rs | comb_rd_rx | comb_rd_ry | comb_rd_rz );
end

assign rd_data = comb_rd_data;
assign rd_cached = comb_rd_cached;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        cache_line_valid_rs = 8'b0;
        cache_line_valid_rx = 8'b0;
        cache_line_valid_ry = 8'b0;
        cache_line_valid_rz = 8'b0;
    end else begin
        if ( cmd_cache ) begin
            cache_line_valid_rs <= (cmd_reg[1:0] == 2'b00) ? ( ( cache_line_valid_rs | comb_cmd_offset_decoded ) & commit_dispute_mask ) : cache_line_valid_rs;
            cache_line_valid_rx <= (cmd_reg[1:0] == 2'b01) ? ( ( cache_line_valid_rx | comb_cmd_offset_decoded ) & commit_dispute_mask ) : cache_line_valid_rx;
            cache_line_valid_ry <= (cmd_reg[1:0] == 2'b10) ? ( ( cache_line_valid_ry | comb_cmd_offset_decoded ) & commit_dispute_mask ) : cache_line_valid_ry;
            cache_line_valid_rz <= (cmd_reg[1:0] == 2'b11) ? ( ( cache_line_valid_rz | comb_cmd_offset_decoded ) & commit_dispute_mask ) : cache_line_valid_rz;
        end else begin
            cache_line_valid_rs <= ( crb_commit & crb_reg[2] & (cmd_reg[1:0] == 2'b00) ) ? 8'b0 : cache_line_valid_rs;
            cache_line_valid_rx <= ( crb_commit & crb_reg[2] & (cmd_reg[1:0] == 2'b01) ) ? 8'b0 : cache_line_valid_rx;
            cache_line_valid_ry <= ( crb_commit & crb_reg[2] & (cmd_reg[1:0] == 2'b10) ) ? 8'b0 : cache_line_valid_ry;
            cache_line_valid_rz <= ( crb_commit & crb_reg[2] & (cmd_reg[1:0] == 2'b11) ) ? 8'b0 : cache_line_valid_rz;
        end
    end
end

always @(posedge clk) begin
    if ( cmd_cache ) begin
        cache[ { cmd_reg[1:0], cmd_offset[3:1] } ] <= cmd_data;
    end
end

endmodule