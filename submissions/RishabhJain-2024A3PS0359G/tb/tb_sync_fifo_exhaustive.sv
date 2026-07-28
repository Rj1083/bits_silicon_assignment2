`timescale 1ns / 1ps

module tb_sync_fifo_exhaustive;

    parameter integer DATA_WIDTH=8;
    parameter integer DEPTH=16;
    
    localparam ADDR_WIDTH=$clog2(DEPTH);

    // DUT Signals
    reg                   clk;
    reg                   rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire                  wr_full;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  rd_empty;
    wire [ADDR_WIDTH:0]   dut_count;

    // Golden Model Variables (Queue)
    reg [DATA_WIDTH-1:0] expected_data;
    integer mem_queue[$];
    
    // Test parameters
    integer cycle_count=0;
    integer errors=0;
    integer MAX_CYCLES=100000;

    // Instantiate DUT
    sync_fifo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_full(wr_full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_empty(rd_empty),
        .count(dut_count)
    );

    // Clock Generation
    initial begin
        clk=0;
        forever #5 clk=~clk;
    end
    
    // Cycle Count
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count=cycle_count+1;
        end
    end

    // Golden Model and Verification
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_queue={};
        end
        else begin
            reg write_executed;
            reg read_executed;
            
            write_executed=wr_en && !wr_full;
            read_executed=rd_en && !rd_empty;
            
            if (write_executed && read_executed) begin
                mem_queue.push_back(wr_data);
                expected_data=mem_queue.pop_front();
            end
            else if (write_executed) begin
                mem_queue.push_back(wr_data);
            end
            else if (read_executed) begin
                expected_data=mem_queue.pop_front();
            end

            #1; // Wait for DUT to update
            
            // Check outputs
            if (dut_count!==mem_queue.size()) begin
                $display("ERROR at cycle %0d: Count mismatch. Expected=%0d, Got=%0d. Inputs: wr_en=%b wr_full=%b rd_en=%b rd_empty=%b. Write_exec=%b, read_exec=%b", cycle_count, mem_queue.size(), dut_count, wr_en, wr_full, rd_en, rd_empty, write_executed, read_executed);
                errors=errors+1;
            end
            
            if (rd_empty!==(mem_queue.size()==0)) begin
                $display("ERROR at cycle %0d: rd_empty mismatch. Expected=%b, Got=%b", cycle_count, (mem_queue.size()==0), rd_empty);
                errors=errors+1;
            end
            
            if (wr_full!==(mem_queue.size()==DEPTH)) begin
                $display("ERROR at cycle %0d: wr_full mismatch. Expected=%b, Got=%b", cycle_count, (mem_queue.size()==DEPTH), wr_full);
                errors=errors+1;
            end
            
            if (read_executed) begin
                if (rd_data!==expected_data) begin
                    $display("ERROR at cycle %0d: rd_data mismatch. Expected=%h, Got=%h", cycle_count, expected_data, rd_data);
                    errors=errors+1;
                end
            end
            
            if (errors>10) begin
                $display("Too many errors. Stopping simulation.");
                $finish;
            end
        end
    end

    // Test Sequence
    initial begin
        $display("Starting EXHAUSTIVE FIFO Verification...");
        
        rst_n=0;
        wr_en=0;
        rd_en=0;
        wr_data=0;
        #25;
        rst_n=1;
        
        // 1. Extensive Random Testing
        $display("Running Phase 1: High Write Probability (Fill up)");
        repeat(100) begin
            @(negedge clk);
            wr_en=($random%100)<80; // 80% write
            rd_en=($random%100)<20; // 20% read
            wr_data=$random;
        end
        
        $display("Running Phase 2: High Read Probability (Drain down)");
        repeat(100) begin
            @(negedge clk);
            wr_en=($random%100)<20; // 20% write
            rd_en=($random%100)<80; // 80% read
            wr_data=$random;
        end
        
        $display("Running Phase 3: Balanced Random R/W (Steady state)");
        repeat(5000) begin
            @(negedge clk);
            wr_en=$random;
            rd_en=$random;
            wr_data=$random;
        end

        $display("Running Phase 4: Consecutive Full/Empty Transitions");
        repeat(10) begin
            // Fill completely
            while(!wr_full) begin
                @(negedge clk);
                wr_en=1;
                rd_en=0;
                wr_data=$random;
            end
            // Simultaneous while full
            repeat(5) begin
                @(negedge clk);
                wr_en=1;
                rd_en=1;
                wr_data=$random;
            end
            // Drain completely
            while(!rd_empty) begin
                @(negedge clk);
                wr_en=0;
                rd_en=1;
            end
            // Simultaneous while empty
            repeat(5) begin
                @(negedge clk);
                wr_en=1;
                rd_en=1;
                wr_data=$random;
            end
        end
        
        $display("Running Phase 5: Fast alternating R/W");
        repeat(500) begin
            @(negedge clk);
            wr_en=~wr_en;
            rd_en=~rd_en;
            wr_data=$random;
        end
        
        $display("Running Phase 6: Reset during operation");
        repeat(10) begin
            @(negedge clk);
            wr_en=1;
            rd_en=0;
            wr_data=$random;
        end
        rst_n=0;
        #15;
        rst_n=1;
        repeat(10) begin
            @(negedge clk);
            wr_en=1;
            rd_en=1;
            wr_data=$random;
        end
        
        @(negedge clk);
        wr_en=0;
        rd_en=0;
        
        #50;
        if (errors==0) begin
            $display("========================================");
            $display("ALL EXHAUSTIVE TESTS PASSED with 0 errors!");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("TEST FAILED with %0d errors.", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
