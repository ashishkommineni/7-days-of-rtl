`timescale 1ns/1ps

module tb_pipelined_mac;
    localparam int OW = 8;
    localparam int AW = 24;
    logic clk;
    logic reset_n;
    logic clear_acc;
    logic in_valid;
    logic signed [OW-1:0] operand_a, operand_b;
    logic out_valid;
    logic signed [AW-1:0] result;

    bit pending_valid;
    int signed pending_product;
    int signed expected_acc;
    int checks;

    pipelined_mac #(.OPERAND_WIDTH(OW), .ACC_WIDTH(AW)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic mac_cycle(input bit valid_i, input int signed a_i,
                             input int signed b_i, input string label);
        begin
            @(negedge clk);
            clear_acc = 0;
            in_valid = valid_i;
            operand_a = OW'(a_i);
            operand_b = OW'(b_i);
            @(posedge clk);
            #1;
            checks++;
            if (pending_valid) begin
                expected_acc += pending_product;
                assert (out_valid) else $fatal(1, "%s: missing out_valid", label);
                assert ($signed(result) == $signed(AW'(expected_acc)))
                    else $fatal(1, "%s: expected accumulated %0d, got %0d",
                                label, expected_acc, $signed(result));
            end else begin
                assert (!out_valid) else $fatal(1, "%s: unexpected out_valid", label);
            end
            pending_valid = valid_i;
            pending_product = a_i * b_i;
        end
    endtask

    task automatic clear_pipeline;
        begin
            @(negedge clk);
            clear_acc = 1; in_valid = 0; operand_a = '0; operand_b = '0;
            @(posedge clk); #1;
            assert (!out_valid && (result == 0)) else $fatal(1, "clear did not flush MAC");
            clear_acc = 0;
            pending_valid = 0;
            pending_product = 0;
            expected_acc = 0;
        end
    endtask

    initial begin
        reset_n = 0; clear_acc = 0; in_valid = 0; operand_a = '0; operand_b = '0;
        pending_valid = 0; pending_product = 0; expected_acc = 0; checks = 0;
        repeat (2) @(posedge clk);
        @(negedge clk) reset_n = 1;

        mac_cycle(1,   3,   4, "positive product");
        mac_cycle(1,  -2,   5, "negative product");
        mac_cycle(0,   0,   0, "pipeline bubble");
        mac_cycle(1, -128, 127, "signed corner");
        mac_cycle(1, 127, 127, "positive corner");
        mac_cycle(0,   0,   0, "final directed drain");
        mac_cycle(0,   0,   0, "empty pipeline");

        clear_pipeline();
        for (int test = 0; test < 50; test++)
            mac_cycle(1'($urandom_range(0, 1)), int'($signed(OW'($urandom()))),
                      int'($signed(OW'($urandom()))), "random signed MAC");
        mac_cycle(0, 0, 0, "random drain one");
        mac_cycle(0, 0, 0, "random drain two");

        $display("[DAY 6] PASS: %0d pipeline cycles, final signed accumulator=%0d",
                 checks, expected_acc);
        $finish;
    end
endmodule
