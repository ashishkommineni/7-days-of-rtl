`timescale 1ns/1ps

module tb_two_by_two_router;
    localparam int DW = 16;
    logic clk;
    logic reset_n;
    logic [1:0] in_valid;
    logic [1:0] in_dest;
    logic [DW-1:0] in_data [0:1];
    logic [1:0] in_ready;
    logic [1:0] out_valid;
    logic [DW-1:0] out_data [0:1];
    logic [1:0] out_ready;

    logic [DW-1:0] expected [0:1][0:255];
    int read_ptr [0:1];
    int write_ptr [0:1];
    int count [0:1];
    logic [1:0] last_accept;
    int accepted_packets, delivered_packets, cycles;

    logic [1:0] pending_valid;
    logic [1:0] pending_dest;
    logic [DW-1:0] pending_data [0:1];

    two_by_two_router #(.DATA_WIDTH(DW)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic run_cycle(
        input bit v0, input bit d0, input logic [DW-1:0] data0,
        input bit v1, input bit d1, input logic [DW-1:0] data1,
        input logic [1:0] ready_o,
        input string label
    );
        logic destination;
        begin
            @(negedge clk);
            in_valid = {v1, v0};
            in_dest  = {d1, d0};
            in_data[0] = data0;
            in_data[1] = data1;
            out_ready = ready_o;
            #1;

            for (int output_port = 0; output_port < 2; output_port++) begin
                if (out_valid[output_port] && out_ready[output_port]) begin
                    assert (count[output_port] > 0)
                        else $fatal(1, "%s: unexpected packet on output %0d", label, output_port);
                    assert (out_data[output_port] === expected[output_port][read_ptr[output_port]])
                        else $fatal(1, "%s: output %0d expected=%h actual=%h", label,
                                    output_port, expected[output_port][read_ptr[output_port]],
                                    out_data[output_port]);
                    read_ptr[output_port] = (read_ptr[output_port] + 1) % 256;
                    count[output_port]--;
                    delivered_packets++;
                end
            end

            last_accept = in_valid & in_ready;
            for (int input_port = 0; input_port < 2; input_port++) begin
                if (last_accept[input_port]) begin
                    destination = int'(in_dest[input_port]);
                    expected[destination][write_ptr[destination]] = in_data[input_port];
                    write_ptr[destination] = (write_ptr[destination] + 1) % 256;
                    count[destination]++;
                    accepted_packets++;
                end
            end

            @(posedge clk);
            #1;
            cycles++;
            for (int output_port = 0; output_port < 2; output_port++) begin
                assert (out_valid[output_port] === (count[output_port] != 0))
                    else $fatal(1, "%s: output %0d occupancy mismatch", label, output_port);
                if (count[output_port] != 0)
                    assert (out_data[output_port] === expected[output_port][read_ptr[output_port]])
                        else $fatal(1, "%s: output %0d queue-front mismatch", label, output_port);
            end
        end
    endtask

    initial begin
        reset_n = 0; in_valid = '0; in_dest = '0;
        in_data[0] = '0; in_data[1] = '0; out_ready = '0;
        accepted_packets = 0; delivered_packets = 0; cycles = 0;
        for (int output_port = 0; output_port < 2; output_port++) begin
            read_ptr[output_port] = 0;
            write_ptr[output_port] = 0;
            count[output_port] = 0;
        end
        repeat (2) @(posedge clk);
        @(negedge clk) reset_n = 1;

        // Keep this first so the reset priority is measured before any winner history exists.
        run_cycle(1, 0, 16'hC010, 1, 0, 16'hC020, 2'b11, "contention first winner");
        assert (last_accept == 2'b01) else $fatal(1, "input zero must win first contention");
        run_cycle(1, 0, 16'hC011, 1, 0, 16'hC020, 2'b11, "contention rotates winner");
        assert (last_accept == 2'b10) else $fatal(1, "round-robin did not rotate to input one");
        run_cycle(1, 0, 16'hC011, 0, 0, '0,       2'b11, "accept previously blocked input");
        run_cycle(0, 0, '0,       0, 0, '0,       2'b11, "drain contention traffic");

        run_cycle(1, 0, 16'hA001, 1, 1, 16'hB001, 2'b11, "independent routes");
        run_cycle(0, 0, '0,       0, 0, '0,       2'b11, "drain independent routes");

        run_cycle(1, 1, 16'hD100, 0, 0, '0,       2'b11, "load output one");
        run_cycle(0, 0, '0,       0, 0, '0,       2'b01, "backpressure hold one");
        run_cycle(0, 0, '0,       0, 0, '0,       2'b01, "backpressure hold two");
        run_cycle(0, 0, '0,       0, 0, '0,       2'b11, "release backpressure");

        pending_valid = '0;
        pending_dest = '0;
        pending_data[0] = '0;
        pending_data[1] = '0;
        for (int test = 0; test < 100; test++) begin
            for (int input_port = 0; input_port < 2; input_port++) begin
                if (!pending_valid[input_port] && $urandom_range(0, 2) != 0) begin
                    pending_valid[input_port] = 1'b1;
                    pending_dest[input_port] = 1'($urandom_range(0, 1));
                    pending_data[input_port] = DW'($urandom());
                end
            end
            run_cycle(pending_valid[0], pending_dest[0], pending_data[0],
                      pending_valid[1], pending_dest[1], pending_data[1],
                      2'($urandom_range(0, 3)), "random held-valid traffic");
            pending_valid &= ~last_accept;
        end

        // Accept any pending sources, then drain both output queues.
        while (pending_valid != 0) begin
            run_cycle(pending_valid[0], pending_dest[0], pending_data[0],
                      pending_valid[1], pending_dest[1], pending_data[1],
                      2'b11, "accept pending packet");
            pending_valid &= ~last_accept;
        end
        while ((count[0] != 0) || (count[1] != 0))
            run_cycle(0, 0, '0, 0, 0, '0, 2'b11, "final router drain");

        assert (accepted_packets == delivered_packets)
            else $fatal(1, "packet conservation failed accepted=%0d delivered=%0d",
                        accepted_packets, delivered_packets);
        $display("[DAY 7] PASS: %0d cycles, %0d packets routed without loss/reorder",
                 cycles, delivered_packets);
        $finish;
    end
endmodule
