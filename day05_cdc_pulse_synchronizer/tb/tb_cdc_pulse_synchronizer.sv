`timescale 1ns/1ps

module tb_cdc_pulse_synchronizer;
    logic src_clk;
    logic dst_clk;
    logic src_reset_n;
    logic dst_reset_n;
    logic src_pulse;
    logic dst_pulse;
    int sent_count;
    int received_count;

    cdc_pulse_synchronizer dut (.*);
    initial begin
        src_clk = 1'b0;
        forever #4 src_clk = ~src_clk; // 125 MHz
    end
    initial begin
        dst_clk = 1'b0;
        forever #7 dst_clk = ~dst_clk; // ~71.4 MHz, intentionally unrelated
    end

    always @(posedge src_clk)
        if (src_reset_n && src_pulse) sent_count <= sent_count + 1;

    always @(posedge dst_clk)
        if (dst_reset_n && dst_pulse) received_count <= received_count + 1;

    task automatic send_event(input int quiet_dst_cycles);
        begin
            @(negedge src_clk);
            src_pulse = 1'b1;
            @(negedge src_clk);
            src_pulse = 1'b0;
            repeat (quiet_dst_cycles) @(posedge dst_clk);
        end
    endtask

    initial begin
        src_reset_n = 0; dst_reset_n = 0; src_pulse = 0;
        sent_count = 0; received_count = 0;
        repeat (3) @(posedge src_clk);
        repeat (2) @(posedge dst_clk);
        @(negedge src_clk) src_reset_n = 1;
        @(negedge dst_clk) dst_reset_n = 1;

        send_event(5);
        send_event(4);
        send_event(7);
        send_event(5);
        send_event(6);
        send_event(4);
        repeat (6) @(posedge dst_clk);

        assert (sent_count == 6) else $fatal(1, "source count mismatch: %0d", sent_count);
        assert (received_count == sent_count)
            else $fatal(1, "CDC lost/duplicated events sent=%0d received=%0d",
                        sent_count, received_count);
        $display("[DAY 5] PASS: %0d source events crossed unrelated clocks exactly once", received_count);
        $finish;
    end
endmodule
