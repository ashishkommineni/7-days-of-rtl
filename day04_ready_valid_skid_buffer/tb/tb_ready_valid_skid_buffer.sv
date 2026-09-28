`timescale 1ns/1ps

module tb_ready_valid_skid_buffer;
    localparam int DW = 16;
    logic clk;
    logic reset_n;
    logic in_valid;
    logic in_ready;
    logic [DW-1:0] in_data;
    logic out_valid;
    logic out_ready;
    logic [DW-1:0] out_data;

    logic [DW-1:0] expected [0:255];
    int read_ptr, write_ptr, count;
    int accepted, delivered, cycles;

    ready_valid_skid_buffer #(.DATA_WIDTH(DW)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic run_cycle(
        input bit drive_valid,
        input logic [DW-1:0] drive_data,
        input bit drive_ready,
        input string label
    );
        begin
            @(negedge clk);
            in_valid = drive_valid;
            in_data  = drive_data;
            out_ready = drive_ready;
            #1;

            if (out_valid && out_ready) begin
                assert (count > 0) else $fatal(1, "%s: DUT produced an unexpected item", label);
                assert (out_data === expected[read_ptr])
                    else $fatal(1, "%s: expected %h, got %h", label, expected[read_ptr], out_data);
                read_ptr = (read_ptr + 1) % 256;
                count--;
                delivered++;
            end
            if (in_valid && in_ready) begin
                expected[write_ptr] = in_data;
                write_ptr = (write_ptr + 1) % 256;
                count++;
                accepted++;
            end

            @(posedge clk);
            #1;
            cycles++;
            assert (out_valid === (count != 0))
                else $fatal(1, "%s: occupancy/valid mismatch count=%0d", label, count);
            if (count != 0)
                assert (out_data === expected[read_ptr])
                    else $fatal(1, "%s: front item mismatch after clock", label);
        end
    endtask

    initial begin
        reset_n = 0; in_valid = 0; in_data = '0; out_ready = 0;
        read_ptr = 0; write_ptr = 0; count = 0;
        accepted = 0; delivered = 0; cycles = 0;
        repeat (2) @(posedge clk);
        @(negedge clk) reset_n = 1;

        run_cycle(1, 16'h1001, 0, "load while downstream blocked");
        run_cycle(1, 16'h2002, 0, "full buffer applies backpressure");
        run_cycle(1, 16'h2002, 1, "simultaneous dequeue and enqueue");
        run_cycle(0, '0,       0, "hold replacement under stall");
        run_cycle(0, '0,       1, "drain replacement");

        for (int test = 0; test < 80; test++)
            run_cycle(1'($urandom_range(0, 1)), DW'($urandom()),
                      1'($urandom_range(0, 1)), "random ready/valid traffic");

        while (count != 0)
            run_cycle(0, '0, 1, "final drain");
        assert (accepted == delivered)
            else $fatal(1, "conservation failed accepted=%0d delivered=%0d", accepted, delivered);
        $display("[DAY 4] PASS: %0d cycles, accepted=%0d delivered=%0d, no loss/reorder",
                 cycles, accepted, delivered);
        $finish;
    end
endmodule
