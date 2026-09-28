`timescale 1ns/1ps

module tb_nyc_clock;
    logic [15:0] utc_year;
    logic [3:0]  utc_month;
    logic [5:0]  utc_day;
    logic [4:0]  utc_hour;
    logic [5:0]  utc_minute;
    logic valid_datetime;
    logic is_dst;
    logic [15:0] local_year;
    logic [3:0]  local_month;
    logic [5:0]  local_day;
    logic [4:0]  local_hour;
    logic [5:0]  local_minute;
    int checks;

    nyc_clock dut (.*);

    task automatic check_time(
        input logic [15:0] uy, input logic [3:0] um, input logic [5:0] ud,
        input logic [4:0] uh, input logic [5:0] umin,
        input bit exp_valid, input bit exp_dst,
        input logic [15:0] ly, input logic [3:0] lm, input logic [5:0] ld,
        input logic [4:0] lh, input logic [5:0] lmin,
        input string label
    );
        begin
            utc_year = uy; utc_month = um; utc_day = ud;
            utc_hour = uh; utc_minute = umin;
            #1;
            checks++;
            assert (valid_datetime === exp_valid)
                else $fatal(1, "%s: validity mismatch", label);
            if (exp_valid) begin
                assert (is_dst === exp_dst) else $fatal(1, "%s: DST mismatch", label);
                assert ((local_year == ly) && (local_month == lm) && (local_day == ld) &&
                        (local_hour == lh) && (local_minute == lmin))
                    else $fatal(1, "%s: got %0d-%02d-%02d %02d:%02d dst=%0b",
                                label, local_year, local_month, local_day,
                                local_hour, local_minute, is_dst);
            end else begin
                assert ({local_year, local_month, local_day, local_hour, local_minute} == '0)
                    else $fatal(1, "%s: invalid input must produce zero outputs", label);
            end
        end
    endtask

    initial begin
        checks = 0;
        check_time(2026, 1, 15, 15, 30, 1, 0, 2026, 1, 15, 10, 30, "winter EST");
        check_time(2026, 7, 4, 16, 45, 1, 1, 2026, 7, 4, 12, 45, "summer EDT");
        check_time(2026, 3, 8, 6, 59, 1, 0, 2026, 3, 8, 1, 59, "spring before");
        check_time(2026, 3, 8, 7,  0, 1, 1, 2026, 3, 8, 3,  0, "spring transition");
        check_time(2026, 11, 1, 5, 59, 1, 1, 2026, 11, 1, 1, 59, "fall before");
        check_time(2026, 11, 1, 6,  0, 1, 0, 2026, 11, 1, 1,  0, "fall transition");
        check_time(2026, 1, 1, 2, 10, 1, 0, 2025, 12, 31, 21, 10, "year borrow");
        check_time(2024, 3, 1, 3,  5, 1, 0, 2024, 2, 29, 22,  5, "leap borrow");
        check_time(2026, 2, 29, 12, 0, 0, 0, 0, 0, 0, 0, 0, "invalid non-leap day");
        check_time(2026, 13, 1, 12, 0, 0, 0, 0, 0, 0, 0, 0, "invalid month");
        $display("[DAY 1] PASS: %0d NYC clock checks, including both DST boundaries", checks);
        $finish;
    end
endmodule
