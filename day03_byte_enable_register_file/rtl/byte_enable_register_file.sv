`timescale 1ns/1ps

module byte_enable_register_file #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 3,
    localparam int DEPTH = 1 << ADDR_WIDTH,
    localparam int BYTE_LANES = DATA_WIDTH / 8
) (
    input  logic                      clk,
    input  logic                      reset_n,
    input  logic                      wr_en,
    input  logic [ADDR_WIDTH-1:0]     wr_addr,
    input  logic [DATA_WIDTH-1:0]     wr_data,
    input  logic [BYTE_LANES-1:0]     byte_en,
    input  logic [ADDR_WIDTH-1:0]     rd_addr_a,
    input  logic [ADDR_WIDTH-1:0]     rd_addr_b,
    output logic [DATA_WIDTH-1:0]     rd_data_a,
    output logic [DATA_WIDTH-1:0]     rd_data_b
);
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int word = 0; word < DEPTH; word++)
                mem[word] <= '0;
        end else if (wr_en) begin
            for (int lane = 0; lane < BYTE_LANES; lane++) begin
                if (byte_en[lane])
                    mem[wr_addr][lane*8 +: 8] <= wr_data[lane*8 +: 8];
            end
        end
    end

    // Asynchronous reads with byte-accurate write-through forwarding.
    always_comb begin
        rd_data_a = mem[rd_addr_a];
        rd_data_b = mem[rd_addr_b];
        if (wr_en && (rd_addr_a == wr_addr)) begin
            for (int lane = 0; lane < BYTE_LANES; lane++)
                if (byte_en[lane]) rd_data_a[lane*8 +: 8] = wr_data[lane*8 +: 8];
        end
        if (wr_en && (rd_addr_b == wr_addr)) begin
            for (int lane = 0; lane < BYTE_LANES; lane++)
                if (byte_en[lane]) rd_data_b[lane*8 +: 8] = wr_data[lane*8 +: 8];
        end
    end

    generate
        for (genvar lane = 0; lane < BYTE_LANES; lane++) begin : g_bypass_assertions
            property p_port_a_byte_bypass;
                @(posedge clk) disable iff (!reset_n)
                    (wr_en && byte_en[lane] && (rd_addr_a == wr_addr))
                    |-> (rd_data_a[lane*8 +: 8] == wr_data[lane*8 +: 8]);
            endproperty
            assert property (p_port_a_byte_bypass);

            property p_port_b_byte_bypass;
                @(posedge clk) disable iff (!reset_n)
                    (wr_en && byte_en[lane] && (rd_addr_b == wr_addr))
                    |-> (rd_data_b[lane*8 +: 8] == wr_data[lane*8 +: 8]);
            endproperty
            assert property (p_port_b_byte_bypass);
        end
    endgenerate
endmodule
