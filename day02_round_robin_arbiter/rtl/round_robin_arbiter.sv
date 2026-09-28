`timescale 1ns/1ps

module round_robin_arbiter #(
    parameter int NUM_REQUESTERS = 4,
    localparam int INDEX_WIDTH = (NUM_REQUESTERS <= 1) ? 1 : $clog2(NUM_REQUESTERS)
) (
    input  logic                      clk,
    input  logic                      reset_n,
    input  logic [NUM_REQUESTERS-1:0] req,
    output logic [NUM_REQUESTERS-1:0] grant
);
    logic [INDEX_WIDTH-1:0] last_grant;
    integer offset;
    integer index;
    logic found;

    always_comb begin
        grant = '0;
        found = 1'b0;
        index = 0;
        for (offset = 1; offset <= NUM_REQUESTERS; offset = offset + 1) begin
            index = int'(last_grant) + offset;
            if (index >= NUM_REQUESTERS)
                index = index - NUM_REQUESTERS;
            if (!found && req[index]) begin
                grant[index] = 1'b1;
                found = 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Makes requester zero the first priority after reset.
            last_grant <= INDEX_WIDTH'(NUM_REQUESTERS - 1);
        end else begin
            for (int i = 0; i < NUM_REQUESTERS; i++) begin
                if (grant[i])
                    last_grant <= INDEX_WIDTH'(i);
            end
        end
    end

    property p_onehot_or_idle;
        @(posedge clk) disable iff (!reset_n) $onehot0(grant);
    endproperty
    assert property (p_onehot_or_idle);

    property p_grant_requires_request;
        @(posedge clk) disable iff (!reset_n) ((grant & ~req) == '0);
    endproperty
    assert property (p_grant_requires_request);

    property p_idle_has_no_grant;
        @(posedge clk) disable iff (!reset_n) (req == '0) |-> (grant == '0);
    endproperty
    assert property (p_idle_has_no_grant);
endmodule
