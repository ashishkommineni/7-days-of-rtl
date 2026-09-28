`timescale 1ns/1ps

module tb_round_robin_arbiter;
    localparam int N = 4;
    logic clk;
    logic reset_n;
    logic [N-1:0] req;
    logic [N-1:0] grant;
    int model_last;
    int checks;

    round_robin_arbiter #(.NUM_REQUESTERS(N)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [N-1:0] expected_grant(input logic [N-1:0] request);
        logic [N-1:0] result;
        bit found;
        int idx;
        begin
            result = '0;
            found = 0;
            for (int step = 1; step <= N; step++) begin
                idx = model_last + step;
                if (idx >= N) idx -= N;
                if (!found && request[idx]) begin
                    result[idx] = 1'b1;
                    found = 1;
                end
            end
            return result;
        end
    endfunction

    task automatic apply_and_check(input logic [N-1:0] request, input string label);
        logic [N-1:0] expected;
        begin
            @(negedge clk);
            req = request;
            #1;
            expected = expected_grant(request);
            checks++;
            assert (grant === expected)
                else $fatal(1, "%s: req=%b expected=%b actual=%b last=%0d",
                            label, request, expected, grant, model_last);
            @(posedge clk);
            #1;
            for (int i = 0; i < N; i++)
                if (expected[i]) model_last = i;
        end
    endtask

    initial begin
        reset_n = 0;
        req = '0;
        model_last = N - 1;
        checks = 0;
        repeat (2) @(posedge clk);
        @(negedge clk) reset_n = 1;

        repeat (2) begin
            apply_and_check(4'b1111, "full contention rotation");
            apply_and_check(4'b1111, "full contention rotation");
            apply_and_check(4'b1111, "full contention rotation");
            apply_and_check(4'b1111, "full contention rotation");
        end
        apply_and_check(4'b0000, "idle");
        apply_and_check(4'b1010, "sparse request");
        apply_and_check(4'b1010, "sparse rotation");
        apply_and_check(4'b0100, "single request");
        for (int test = 0; test < 40; test++)
            apply_and_check(N'($urandom()), "random request");

        $display("[DAY 2] PASS: %0d arbitration checks; one-hot and fairness assertions active", checks);
        $finish;
    end
endmodule
