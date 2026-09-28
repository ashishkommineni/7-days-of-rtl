`timescale 1ns/1ps

module pipelined_mac #(
    parameter int OPERAND_WIDTH = 8,
    parameter int ACC_WIDTH = 24,
    localparam int PRODUCT_WIDTH = 2 * OPERAND_WIDTH
) (
    input  logic                            clk,
    input  logic                            reset_n,
    input  logic                            clear_acc,
    input  logic                            in_valid,
    input  logic signed [OPERAND_WIDTH-1:0] operand_a,
    input  logic signed [OPERAND_WIDTH-1:0] operand_b,
    output logic                            out_valid,
    output logic signed [ACC_WIDTH-1:0]     result
);
    logic valid_s1;
    logic signed [PRODUCT_WIDTH-1:0] product_s1;
    logic signed [ACC_WIDTH-1:0] accumulator;
    logic signed [ACC_WIDTH-1:0] extended_product;

    always_comb begin
        extended_product = {{(ACC_WIDTH-PRODUCT_WIDTH){product_s1[PRODUCT_WIDTH-1]}},
                            product_s1};
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_s1    <= 1'b0;
            product_s1  <= '0;
            accumulator <= '0;
            out_valid   <= 1'b0;
            result      <= '0;
        end else if (clear_acc) begin
            valid_s1    <= 1'b0;
            product_s1  <= '0;
            accumulator <= '0;
            out_valid   <= 1'b0;
            result      <= '0;
        end else begin
            valid_s1  <= in_valid;
            out_valid <= valid_s1;
            if (in_valid)
                product_s1 <= $signed(operand_a) * $signed(operand_b);
            if (valid_s1) begin
                accumulator <= accumulator + extended_product;
                result      <= accumulator + extended_product;
            end
        end
    end

    property p_valid_result_is_known;
        @(posedge clk) disable iff (!reset_n) out_valid |-> !$isunknown(result);
    endproperty
    assert property (p_valid_result_is_known);

    property p_clear_flushes_pipeline;
        @(posedge clk) disable iff (!reset_n) clear_acc |=> (!out_valid && (result == '0));
    endproperty
    assert property (p_clear_flushes_pipeline);

    cover property (@(posedge clk) disable iff (!reset_n) in_valid ##1 out_valid);
endmodule
