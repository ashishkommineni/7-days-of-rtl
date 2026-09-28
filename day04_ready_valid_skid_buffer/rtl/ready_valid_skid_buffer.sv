`timescale 1ns/1ps

module ready_valid_skid_buffer #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  reset_n,
    input  logic                  in_valid,
    output logic                  in_ready,
    input  logic [DATA_WIDTH-1:0] in_data,
    output logic                  out_valid,
    input  logic                  out_ready,
    output logic [DATA_WIDTH-1:0] out_data
);
    logic full;
    logic [DATA_WIDTH-1:0] data_q;

    assign in_ready  = !full || out_ready;
    assign out_valid = full;
    assign out_data  = data_q;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            full   <= 1'b0;
            data_q <= '0;
        end else if (in_ready) begin
            // Covers empty load, simultaneous dequeue/enqueue, and dequeue to empty.
            full <= in_valid;
            if (in_valid)
                data_q <= in_data;
        end
    end

    property p_hold_during_backpressure;
        @(posedge clk) disable iff (!reset_n)
            (out_valid && !out_ready) |=> (out_valid && $stable(out_data));
    endproperty
    assert property (p_hold_during_backpressure);

    property p_full_blocks_without_dequeue;
        @(posedge clk) disable iff (!reset_n)
            (out_valid && !out_ready) |-> !in_ready;
    endproperty
    assert property (p_full_blocks_without_dequeue);

    cover property (@(posedge clk) disable iff (!reset_n)
                    in_valid && in_ready && out_valid && out_ready);
endmodule
