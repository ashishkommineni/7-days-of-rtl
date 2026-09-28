`timescale 1ns/1ps

module nyc_clock (
    input  logic [15:0] utc_year,
    input  logic [3:0]  utc_month,
    input  logic [5:0]  utc_day,
    input  logic [4:0]  utc_hour,
    input  logic [5:0]  utc_minute,
    output logic         valid_datetime,
    output logic         is_dst,
    output logic [15:0] local_year,
    output logic [3:0]  local_month,
    output logic [5:0]  local_day,
    output logic [4:0]  local_hour,
    output logic [5:0]  local_minute
);

    function automatic int days_in_month(input int year, input int month);
        bit leap;
        begin
            leap = ((year % 4) == 0) && (((year % 100) != 0) || ((year % 400) == 0));
            case (month)
                1, 3, 5, 7, 8, 10, 12: days_in_month = 31;
                4, 6, 9, 11:            days_in_month = 30;
                2:                       days_in_month = leap ? 29 : 28;
                default:                 days_in_month = 0;
            endcase
        end
    endfunction

    // Gregorian/Sakamoto formula. Return value: Sunday=0 ... Saturday=6.
    function automatic int day_of_week(input int year, input int month, input int day);
        int adjusted_year;
        int month_offset;
        begin
            case (month)
                1:  month_offset = 0;
                2:  month_offset = 3;
                3:  month_offset = 2;
                4:  month_offset = 5;
                5:  month_offset = 0;
                6:  month_offset = 3;
                7:  month_offset = 5;
                8:  month_offset = 1;
                9:  month_offset = 4;
                10: month_offset = 6;
                11: month_offset = 2;
                12: month_offset = 4;
                default: month_offset = 0;
            endcase
            adjusted_year = (month < 3) ? (year - 1) : year;
            day_of_week = (adjusted_year + adjusted_year/4 - adjusted_year/100
                         + adjusted_year/400 + month_offset + day) % 7;
        end
    endfunction

    function automatic int nth_sunday(input int year, input int month, input int nth);
        int first_sunday;
        begin
            first_sunday = 1 + ((7 - day_of_week(year, month, 1)) % 7);
            nth_sunday   = first_sunday + (7 * (nth - 1));
        end
    endfunction

    int year_i;
    int month_i;
    int day_i;
    int hour_i;
    int minute_i;
    int start_day;
    int end_day;
    int signed local_hour_work;
    int local_year_work;
    int local_month_work;
    int local_day_work;

    always_comb begin
        year_i   = int'(utc_year);
        month_i  = int'(utc_month);
        day_i    = int'(utc_day);
        hour_i   = int'(utc_hour);
        minute_i = int'(utc_minute);

        valid_datetime = (year_i >= 1900) &&
                         (month_i >= 1) && (month_i <= 12) &&
                         (day_i >= 1) && (day_i <= days_in_month(year_i, month_i)) &&
                         (hour_i <= 23) && (minute_i <= 59);

        start_day = nth_sunday(year_i, 3, 2);
        end_day   = nth_sunday(year_i, 11, 1);
        is_dst    = 1'b0;

        if (valid_datetime) begin
            if ((month_i > 3) && (month_i < 11)) begin
                is_dst = 1'b1;
            end else if (month_i == 3) begin
                is_dst = (day_i > start_day) ||
                         ((day_i == start_day) && (hour_i >= 7));
            end else if (month_i == 11) begin
                is_dst = (day_i < end_day) ||
                         ((day_i == end_day) && (hour_i < 6));
            end
        end

        local_year_work  = year_i;
        local_month_work = month_i;
        local_day_work   = day_i;
        // This must be wider than utc_hour. A 5-bit intermediate overflows here.
        local_hour_work  = hour_i + (is_dst ? -4 : -5);

        if (valid_datetime && (local_hour_work < 0)) begin
            local_hour_work = local_hour_work + 24;
            local_day_work  = local_day_work - 1;
            if (local_day_work == 0) begin
                local_month_work = local_month_work - 1;
                if (local_month_work == 0) begin
                    local_month_work = 12;
                    local_year_work  = local_year_work - 1;
                end
                local_day_work = days_in_month(local_year_work, local_month_work);
            end
        end

        if (valid_datetime) begin
            local_year   = 16'(local_year_work);
            local_month  = 4'(local_month_work);
            local_day    = 6'(local_day_work);
            local_hour   = 5'(local_hour_work);
            local_minute = 6'(minute_i);
        end else begin
            local_year   = '0;
            local_month  = '0;
            local_day    = '0;
            local_hour   = '0;
            local_minute = '0;
        end
    end

    // Immediate design invariants remain active in simulation and formal runs.
    always_comb begin : output_range_assertions
        if (valid_datetime) begin
            assert ((local_month >= 1) && (local_month <= 12));
            assert ((local_day >= 1) && (local_day <= 31));
            assert (local_hour <= 23);
            assert (local_minute <= 59);
        end
    end

endmodule
