module sync_fifo #(parameter integer DATA_WIDTH=8, parameter integer DEPTH=16, parameter integer ADDR_WIDTH=4)(
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire wr_full,
    input  wire rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire rd_empty,
    output wire [ADDR_WIDTH:0] count );


    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   internal_count;

    assign count=internal_count;

    assign rd_empty=(internal_count==0);
    assign wr_full=(internal_count==DEPTH);

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr<=0;
            rd_ptr<=0;
            internal_count<=0;
            rd_data<=0;
        end
	else begin
            case ({wr_en && !wr_full, rd_en && !rd_empty})
                2'b10: begin
                    mem[wr_ptr]<=wr_data;
                    wr_ptr<=(wr_ptr==DEPTH-1)?0:wr_ptr+1;
                    internal_count<=internal_count+1;
                end
                2'b01: begin
                    rd_data<=mem[rd_ptr];
                    rd_ptr<=(rd_ptr==DEPTH-1)?0:rd_ptr+1;
                    internal_count<=internal_count-1;
                end
                2'b11: begin
                    mem[wr_ptr]<=wr_data;
                    rd_data<=mem[rd_ptr];
                    wr_ptr<=(wr_ptr==DEPTH-1)?0:wr_ptr+1;
                    rd_ptr<=(rd_ptr==DEPTH-1)?0:rd_ptr+1;
                end
                default: ;
            endcase
        end
    end

endmodule
