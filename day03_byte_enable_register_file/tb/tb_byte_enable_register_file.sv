`timescale 1ns/1ps

module tb_byte_enable_register_file;
    localparam int DW = 32;
    localparam int AW = 3;
    localparam int DEPTH = 1 << AW;
    logic clk;
    logic reset_n;
    logic wr_en;
    logic [AW-1:0] wr_addr;
    logic [DW-1:0] wr_data;
    logic [3:0] byte_en;
    logic [AW-1:0] rd_addr_a, rd_addr_b;
    logic [DW-1:0] rd_data_a, rd_data_b;
    logic [DW-1:0] model [0:DEPTH-1];
    int checks;

    byte_enable_register_file #(.DATA_WIDTH(DW), .ADDR_WIDTH(AW)) dut (.*);
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [DW-1:0] merged_word(
        input logic [DW-1:0] old_word,
        input logic [DW-1:0] new_word,
        input logic [3:0] enables
    );
        logic [DW-1:0] result;
        begin
            result = old_word;
            for (int lane = 0; lane < 4; lane++)
                if (enables[lane]) result[lane*8 +: 8] = new_word[lane*8 +: 8];
            return result;
        end
    endfunction

    task automatic transaction(
        input bit write,
        input logic [AW-1:0] wa,
        input logic [DW-1:0] wd,
        input logic [3:0] be,
        input logic [AW-1:0] ra,
        input logic [AW-1:0] rb,
        input string label
    );
        logic [DW-1:0] exp_a, exp_b;
        begin
            @(negedge clk);
            wr_en = write; wr_addr = wa; wr_data = wd; byte_en = be;
            rd_addr_a = ra; rd_addr_b = rb;
            #1;
            exp_a = model[ra];
            exp_b = model[rb];
            if (write && (ra == wa)) exp_a = merged_word(exp_a, wd, be);
            if (write && (rb == wa)) exp_b = merged_word(exp_b, wd, be);
            assert ((rd_data_a === exp_a) && (rd_data_b === exp_b))
                else $fatal(1, "%s bypass/read mismatch A=%h/%h B=%h/%h",
                            label, rd_data_a, exp_a, rd_data_b, exp_b);
            @(posedge clk);
            if (write) model[wa] = merged_word(model[wa], wd, be);
            #1;
            checks++;
            assert ((rd_data_a === model[ra]) && (rd_data_b === model[rb]))
                else $fatal(1, "%s committed read mismatch", label);
        end
    endtask

    initial begin
        reset_n = 0; wr_en = 0; wr_addr = '0; wr_data = '0; byte_en = '0;
        rd_addr_a = '0; rd_addr_b = '0; checks = 0;
        for (int i = 0; i < DEPTH; i++) model[i] = '0;
        repeat (2) @(posedge clk);
        @(negedge clk) reset_n = 1;

        transaction(1, 3, 32'h1122_3344, 4'b1111, 3, 0, "full write and bypass");
        transaction(1, 3, 32'hAABB_CCDD, 4'b0101, 3, 3, "partial byte merge");
        transaction(1, 6, 32'hDEAD_BEEF, 4'b1010, 3, 6, "independent read ports");
        transaction(0, 0, '0, 4'b0000, 6, 3, "read-only cycle");

        for (int test = 0; test < 60; test++) begin
            transaction(1'($urandom_range(0, 1)), AW'($urandom_range(0, DEPTH-1)),
                        $urandom(), 4'($urandom_range(0, 15)),
                        AW'($urandom_range(0, DEPTH-1)), AW'($urandom_range(0, DEPTH-1)),
                        "random model comparison");
        end
        $display("[DAY 3] PASS: %0d register-file transactions with byte bypass", checks);
        $finish;
    end
endmodule
