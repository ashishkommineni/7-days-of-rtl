`timescale 1ns/1ps

module two_by_two_router #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                  clk,
    input  logic                  reset_n,
    input  logic [1:0]            in_valid,
    input  logic [1:0]            in_dest,
    input  logic [DATA_WIDTH-1:0] in_data [0:1],
    output logic [1:0]            in_ready,
    output logic [1:0]            out_valid,
    output logic [DATA_WIDTH-1:0] out_data [0:1],
    input  logic [1:0]            out_ready
);
    logic [1:0] full;
    logic [DATA_WIDTH-1:0] data_q [0:1];
    logic [1:0] last_winner;
    logic [1:0] slot_ready;
    logic [1:0] grant [0:1]; // grant[output][input]

    always_comb begin
        slot_ready = ~full | out_ready;
        grant[0] = '0;
        grant[1] = '0;

        for (int output_port = 0; output_port < 2; output_port++) begin
            if (slot_ready[output_port]) begin
                if (in_valid[0] && (in_dest[0] == output_port[0]) &&
                    in_valid[1] && (in_dest[1] == output_port[0])) begin
                    if (last_winner[output_port] == 1'b0)
                        grant[output_port][1] = 1'b1;
                    else
                        grant[output_port][0] = 1'b1;
                end else if (in_valid[0] && (in_dest[0] == output_port[0])) begin
                    grant[output_port][0] = 1'b1;
                end else if (in_valid[1] && (in_dest[1] == output_port[0])) begin
                    grant[output_port][1] = 1'b1;
                end
            end
        end

        in_ready[0] = grant[in_dest[0]][0];
        in_ready[1] = grant[in_dest[1]][1];
        out_valid = full;
        out_data[0] = data_q[0];
        out_data[1] = data_q[1];
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            full <= '0;
            data_q[0] <= '0;
            data_q[1] <= '0;
            // Input zero wins the first two-way contention.
            last_winner <= 2'b11;
        end else begin
            for (int output_port = 0; output_port < 2; output_port++) begin
                if (slot_ready[output_port]) begin
                    full[output_port] <= |grant[output_port];
                    if (grant[output_port][0]) begin
                        data_q[output_port] <= in_data[0];
                        last_winner[output_port] <= 1'b0;
                    end else if (grant[output_port][1]) begin
                        data_q[output_port] <= in_data[1];
                        last_winner[output_port] <= 1'b1;
                    end
                end
            end
        end
    end

    generate
        for (genvar output_port = 0; output_port < 2; output_port++) begin : g_output_assertions
            property p_stable_while_stalled;
                @(posedge clk) disable iff (!reset_n)
                    (out_valid[output_port] && !out_ready[output_port])
                    |=> (out_valid[output_port] && $stable(out_data[output_port]));
            endproperty
            assert property (p_stable_while_stalled);
        end
    endgenerate

    property p_single_winner_on_contention;
        @(posedge clk) disable iff (!reset_n)
            (in_valid[0] && in_valid[1] && (in_dest[0] == in_dest[1]))
            |-> !(in_ready[0] && in_ready[1]);
    endproperty
    assert property (p_single_winner_on_contention);

    cover property (@(posedge clk) disable iff (!reset_n)
                    in_valid[0] && in_valid[1] && (in_dest[0] == in_dest[1]));
endmodule
