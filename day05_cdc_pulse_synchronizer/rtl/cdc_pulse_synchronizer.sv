`timescale 1ns/1ps

module cdc_pulse_synchronizer (
    input  logic src_clk,
    input  logic src_reset_n,
    input  logic src_pulse,
    input  logic dst_clk,
    input  logic dst_reset_n,
    output logic dst_pulse
);
    logic src_toggle;
    (* ASYNC_REG = "TRUE" *) logic dst_sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic dst_sync_ff2;
    logic dst_sync_ff2_d;

    always_ff @(posedge src_clk or negedge src_reset_n) begin
        if (!src_reset_n)
            src_toggle <= 1'b0;
        else if (src_pulse)
            src_toggle <= ~src_toggle;
    end

    always_ff @(posedge dst_clk or negedge dst_reset_n) begin
        if (!dst_reset_n) begin
            dst_sync_ff1   <= 1'b0;
            dst_sync_ff2   <= 1'b0;
            dst_sync_ff2_d <= 1'b0;
        end else begin
            dst_sync_ff1   <= src_toggle;
            dst_sync_ff2   <= dst_sync_ff1;
            dst_sync_ff2_d <= dst_sync_ff2;
        end
    end

    assign dst_pulse = dst_sync_ff2 ^ dst_sync_ff2_d;

    // The source-side usage contract: pulses are not adjacent source cycles.
    property p_source_spacing;
        @(posedge src_clk) disable iff (!src_reset_n) src_pulse |=> !src_pulse;
    endproperty
    assert property (p_source_spacing);

    property p_destination_one_cycle;
        @(posedge dst_clk) disable iff (!dst_reset_n) dst_pulse |=> !dst_pulse;
    endproperty
    assert property (p_destination_one_cycle);

    cover property (@(posedge dst_clk) disable iff (!dst_reset_n) dst_pulse);
endmodule
