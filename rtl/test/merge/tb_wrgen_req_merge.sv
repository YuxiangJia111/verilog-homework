`timescale 1ns/1ps

module tb_wrgen_req_merge;

    parameter int MERGE_NUM  = 2;
    parameter int DATA_WIDTH = 512;
    parameter int MASK_WIDTH = 64;
    parameter int ADDR_WIDTH = 34;
    parameter int ADDR_STEP  = 64;

    logic                                    clk;
    logic                                    rst_n;
    logic                                    in_vld;
    logic [ADDR_WIDTH-1:0]                   in_addr;
    logic [DATA_WIDTH-1:0]                   in_dat;
    logic [MASK_WIDTH-1:0]                   in_msk;
    logic                                    in_lst;
    logic                                    in_rdy;
    logic                                    out_vld;
    logic [ADDR_WIDTH-1:0]                   out_addr;
    logic [MERGE_NUM*DATA_WIDTH-1:0]         out_dat;
    logic [MERGE_NUM*MASK_WIDTH-1:0]         out_msk;
    logic                                    out_lst;
    logic                                    out_rdy;

    wrgen_req_merge #(
        .MERGE_NUM(MERGE_NUM),
        .DATA_WIDTH(DATA_WIDTH),
        .MASK_WIDTH(MASK_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ADDR_STEP(ADDR_STEP)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_vld(in_vld),
        .in_addr(in_addr),
        .in_dat(in_dat),
        .in_msk(in_msk),
        .in_lst(in_lst),
        .in_rdy(in_rdy),
        .out_vld(out_vld),
        .out_addr(out_addr),
        .out_dat(out_dat),
        .out_msk(out_msk),
        .out_lst(out_lst),
        .out_rdy(out_rdy)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_req(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] dat, input [MASK_WIDTH-1:0] msk, input logic lst);
        logic accepted;
        accepted = 0;
        in_vld <= 1;
        in_addr <= addr;
        in_dat <= dat;
        in_msk <= msk;
        in_lst <= lst;
        
        do begin
            @(posedge clk);
            if (in_rdy) accepted = 1;
        end while (!accepted);
        
        in_vld <= 0;
        in_dat <= '0;
        in_lst <= 0;
    endtask

    integer input_file, golden_file, scan_ret;
    logic [ADDR_WIDTH-1:0] expected_addr;
    logic expected_lst;
    logic [MERGE_NUM*DATA_WIDTH-1:0] expected_dat;
    logic [MERGE_NUM*MASK_WIDTH-1:0] expected_msk;
    logic golden_eof;

    // Temporary variables for binary read (sized to byte boundaries)
    logic [7:0]   bin_in_vld;
    logic [63:0]  bin_in_addr; // 8 bytes
    logic [DATA_WIDTH-1:0] bin_in_dat; // 512 bits = 64 bytes
    logic [MASK_WIDTH-1:0] bin_in_msk; // 64 bits = 8 bytes
    logic [7:0]   bin_in_lst;

    logic [63:0]  bin_exp_addr;
    logic [7:0]   bin_exp_lst;
    logic [MERGE_NUM*DATA_WIDTH-1:0] bin_exp_dat;
    logic [MERGE_NUM*MASK_WIDTH-1:0] bin_exp_msk;

    initial begin
        rst_n = 0;
        in_vld = 0;
        in_addr = 0;
        in_dat = 0;
        in_msk = 0;
        in_lst = 0;
        out_rdy = 0;

        #20 rst_n = 1;
        #10;
        
        out_rdy = 1;

        $display("Starting Test...");
        
        input_file = $fopen("../../data/input_data.bin", "rb");
        golden_file = $fopen("../../data/golden_data.bin", "rb");
        golden_eof = 0;

        if (input_file == 0 || golden_file == 0) begin
            $display("Error: Could not open data files.");
            $finish;
        end

        while (!$feof(input_file)) begin
            // Read 82 bytes: Vld(1) Addr(8) Dat(64) Msk(8) Lst(1)
            scan_ret = $fread(bin_in_vld, input_file);
            if (scan_ret != 0) begin
                void'($fread(bin_in_addr, input_file));
                void'($fread(bin_in_dat, input_file));
                void'($fread(bin_in_msk, input_file));
                void'($fread(bin_in_lst, input_file));
                
                send_req(bin_in_addr[ADDR_WIDTH-1:0], bin_in_dat, bin_in_msk, bin_in_lst[0]);
            end
        end
        
        // Wait for last transactions to drain
        #200;
        
        $fclose(input_file);
        $fclose(golden_file);
        $display("Test Done");
        $finish;
    end

    // Monitor and Checker
    always @(posedge clk) begin
        if (out_vld && out_rdy) begin
            // Read next golden vector
            // Format: addr(8B), last(1B), data(128B), mask(16B) = 153 Bytes
            
            if (!$feof(golden_file)) begin
                scan_ret = $fread(bin_exp_addr, golden_file);
                
                if (scan_ret != 0) begin
                    void'($fread(bin_exp_lst, golden_file));
                    void'($fread(bin_exp_dat, golden_file));
                    void'($fread(bin_exp_msk, golden_file));
                    
                    expected_addr = bin_exp_addr[ADDR_WIDTH-1:0];
                    expected_lst  = bin_exp_lst[0];
                    expected_dat  = bin_exp_dat;
                    expected_msk  = bin_exp_msk;

                    if (out_addr !== expected_addr || out_lst !== expected_lst || out_dat !== expected_dat || out_msk !== expected_msk) begin
                        $display("Error at time %t:", $time);
                        $display("  Expected: Addr=%x, Last=%b, Data=%x, Mask=%x", expected_addr, expected_lst, expected_dat, expected_msk);
                        $display("  Actual:   Addr=%x, Last=%b, Data=%x, Mask=%x", out_addr, out_lst, out_dat, out_msk);
                        $finish; // Stop on first error
                    end else begin
                        $display("Match at time %t: Addr=%x", $time, out_addr);
                    end
                end else begin
                    $display("Error: Golden file ended prematurely or format error.");
                end
            end else begin
                 $display("Error: received output but golden file is empty.");
            end
        end
    end

    initial begin
        $fsdbDumpfile("tb_wrgen_req_merge.fsdb");
        $fsdbDumpvars(0, tb_wrgen_req_merge);
    end

endmodule
