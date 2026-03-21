
`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter integer DATA_WIDTH=8;
    parameter integer DEPTH=16;
    
    function integer clog2(input integer depth);
        integer i;
        begin
            clog2=0;
            for (i=depth-1;i>0;i=(i/2))
                clog2=clog2+1;
        end
    endfunction
    localparam ADDR_WIDTH=clog2(DEPTH);

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

    // Golden Model Variables
    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    integer model_wr_ptr;
    integer model_rd_ptr;
    integer model_count;
    reg [DATA_WIDTH-1:0] model_rd_data;

    // Simulation Cycle Counter
    integer cycle;

    // Manual Coverage Counters
    integer cov_full;
    integer cov_empty;
    integer cov_wrap;
    integer cov_simul;
    integer cov_overflow;
    integer cov_underflow;

    // Instantiate the DUT (Device Under Test)
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
        forever #5 clk=~clk; // 10ns time period
    end

    // Cycle Counter & Coverage Tracker
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle <= 0;
            cov_full      <= 0;
            cov_empty     <= 0;
            cov_wrap      <= 0;
            cov_simul     <= 0;
            cov_overflow  <= 0;
            cov_underflow <= 0;
        end else begin
            cycle <= cycle + 1;
            
            // Coverage logic
            if (dut_count == DEPTH) cov_full = cov_full + 1;
            if (dut_count == 0)     cov_empty = cov_empty + 1;
            if (wr_en && wr_full)   cov_overflow = cov_overflow + 1;
            if (rd_en && rd_empty)  cov_underflow = cov_underflow + 1;
            if (wr_en && !wr_full && rd_en && !rd_empty) cov_simul = cov_simul + 1;
            
            // Track wrap events (Write or Read pointer wraps to 0)
            if (wr_en && !wr_full && (model_wr_ptr == DEPTH-1)) cov_wrap = cov_wrap + 1;
            if (rd_en && !rd_empty && (model_rd_ptr == DEPTH-1)) cov_wrap = cov_wrap + 1;
        end
    end

    // Golden Model Update Block
    always @(posedge clk) begin
        if (!rst_n) begin
            model_wr_ptr  = 0;
            model_rd_ptr  = 0;
            model_count   = 0;
            model_rd_data = 0;
        end else begin
            // Simultaneous Read and Write
            if (wr_en && model_count < DEPTH && rd_en && model_count > 0) begin
                model_mem[model_wr_ptr] = wr_data;
                model_rd_data = model_mem[model_rd_ptr];
                model_wr_ptr = (model_wr_ptr + 1) % DEPTH;
                model_rd_ptr = (model_rd_ptr + 1) % DEPTH;
                // Net model_count remains unchanged
            end
            // Write only
            else if (wr_en && model_count < DEPTH) begin
                model_mem[model_wr_ptr] = wr_data;
                model_wr_ptr = (model_wr_ptr + 1) % DEPTH;
                model_count = model_count + 1;
            end
            // Read only
            else if (rd_en && model_count > 0) begin
                model_rd_data = model_mem[model_rd_ptr];
                model_rd_ptr = (model_rd_ptr + 1) % DEPTH;
                model_count = model_count - 1;
            end
        end
    end

    // Scoreboard Block
    always @(posedge clk) begin
        if (rst_n) begin
            #1; // Small delay to allow DUT signals to settle before comparison
            
            // Compare Count
            if (dut_count !== model_count) begin
                $display("========================================");
                $display("ERROR at cycle %0d", cycle);
                $display("Mismatch in COUNT");
                $display("Expected count = %0d, Got = %0d", model_count, dut_count);
                $display("Inputs: wr_en=%b, rd_en=%b, wr_data=%h", wr_en, rd_en, wr_data);
                $display("========================================");
                $finish;
            end
            
            // Compare Empty Flag
            if (rd_empty !== (model_count == 0)) begin
                $display("ERROR at cycle %0d: rd_empty mismatch! Expected=%b, Got=%b", cycle, (model_count == 0), rd_empty);
                $finish;
            end
            
            // Compare Full Flag
            if (wr_full !== (model_count == DEPTH)) begin
                $display("ERROR at cycle %0d: wr_full mismatch! Expected=%b, Got=%b", cycle, (model_count == DEPTH), wr_full);
                $finish;
            end
            
            // Compare Read Data (only check when a valid read occurs)
            if (rd_en && (model_count >= 0) && (rd_data !== model_rd_data)) begin
                // Note: using (model_count >= 0) to verify data during the read cycle
                $display("ERROR at cycle %0d: rd_data mismatch! Expected=%h, Got=%h", cycle, model_rd_data, rd_data);
                $finish;
            end
        end
    end

    // Directed Tests Generation
    initial begin
        $display("Starting FIFO Verification...");

        // 1. Reset Test
        rst_n = 0; wr_en = 0; rd_en = 0; wr_data = 0;
        #25; 
        rst_n = 1;
        @(posedge clk);
        $display("Reset Test: PASS");

        // 2. Single Write / Read Test
        wr_en = 1; wr_data = 8'hAA; @(posedge clk);
        wr_en = 0; @(posedge clk);
        rd_en = 1; @(posedge clk);
        rd_en = 0; @(posedge clk);
        $display("Single Write/Read Test: PASS");

        // 3. Fill Test (Full Condition Test)
        wr_en = 1;
        repeat (DEPTH) begin
            wr_data = $random;
            @(posedge clk);
        end
        wr_en = 0; 
        @(posedge clk);
        $display("Fill Test: PASS");

        // 4. Overflow Attempt Test
        wr_en = 1; wr_data = 8'hFF; // Attempt write while full
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);
        $display("Overflow Attempt Test: PASS");

        // 5. Drain Test (Empty Condition Test)
        rd_en = 1;
        repeat (DEPTH) @(posedge clk);
        rd_en = 0; 
        @(posedge clk);
        $display("Drain Test: PASS");

        // 6. Underflow Attempt Test
        rd_en = 1; // Attempt read while empty
        @(posedge clk);
        rd_en = 0;
        @(posedge clk);
        $display("Underflow Attempt Test: PASS");

        // 7. Simultaneous Read/Write Test
        // First, put some data in so it's not empty
        wr_en = 1; wr_data = 8'h11; @(posedge clk);
        wr_data = 8'h22; @(posedge clk);
        
        // Now read and write concurrently
        wr_en = 1; rd_en = 1; wr_data = 8'h33; @(posedge clk);
        wr_data = 8'h44; @(posedge clk);
        wr_en = 0; rd_en = 0; @(posedge clk);
        $display("Simultaneous Read/Write Test: PASS");

        // 8. Pointer Wrap-Around Test
        // Fill it near the brim to force pointers to cross DEPTH-1
        wr_en = 1;
        repeat (DEPTH - 2) begin
            wr_data = $random;
            @(posedge clk);
        end
        // Now do simultaneous read/writes to march the pointers over the boundary
        rd_en = 1;
        repeat (5) begin
            wr_data = $random;
            @(posedge clk);
        end
        wr_en = 0; rd_en = 0;
        @(posedge clk);
        $display("Pointer Wrap-Around Test: PASS");

        // Drain remaining to clean up
        rd_en = 1;
        repeat (DEPTH) @(posedge clk);
        rd_en = 0;

        // End of Simulation Summary
        $display("========================================");
        $display("ALL DIRECTED TESTS PASSED!");
        $display("--- Coverage Summary ---");
        $display("Full Condition Hit   : %0d times", cov_full);
        $display("Empty Condition Hit  : %0d times", cov_empty);
        $display("Wrap Events Hit      : %0d times", cov_wrap);
        $display("Simultaneous R/W Hit : %0d times", cov_simul);
        $display("Overflow Attempts Hit: %0d times", cov_overflow);
        $display("Underflow Attempts Hit:%0d times", cov_underflow);
        $display("========================================");
        
        // Final sanity check on coverage
        if (cov_full && cov_empty && cov_wrap && cov_simul && cov_overflow && cov_underflow)
            $display("100%% MANUAL COVERAGE ACHIEVED.");
        else
            $display("WARNING: Some coverage buckets are 0!");

        $finish;
    end

endmodule