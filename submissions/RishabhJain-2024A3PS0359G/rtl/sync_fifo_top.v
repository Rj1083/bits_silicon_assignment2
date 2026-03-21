module sync_fifo #(parameter integer DATA_WIDTH=8, parameter integer DEPTH=16)(
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire wr_full,
    input  wire rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire rd_empty,
    output wire [clog2(DEPTH):0] count );

    function integer clog2(input integer depth);
        integer i;
        begin
            clog2=0;
            for (i=depth-1;i>0;i=(i/2))
                clog2=clog2+1;
        end
    endfunction

    localparam ADDR_WIDTH=clog2(DEPTH);

    sync_fifo #(.DATA_WIDTH(DATA_WIDTH),.DEPTH(DEPTH),.ADDR_WIDTH(ADDR_WIDTH)) 
    fifo_inst (.clk(clk),.rst_n(rst_n),.wr_en(wr_en),.wr_data(wr_data),.wr_full(wr_full),.rd_en(rd_en),.rd_data(rd_data),.rd_empty(rd_empty),.count(count));


endmodule
