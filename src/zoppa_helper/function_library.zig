///! fuction_library.zig
/// 関数ライブラリを提供します。
const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const VariableEnv = @import("variable_environment.zig").VariableEnvironment;
const Value = @import("analisys_value.zig").AnalysisValue;
const Errors = @import("analysis_error.zig").AnalysisErrors;

const DateTime = struct {
    year: u32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16,
};

fn isLeapYear(year: u32) bool {
    return (@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0);
}

fn daysInMonth(month: u8, year: u32) u8 {
    return switch (month) {
        1 => 31,
        2 => if (isLeapYear(year)) 29 else 28,
        3 => 31,
        4 => 30,
        5 => 31,
        6 => 30,
        7 => 31,
        8 => 31,
        9 => 30,
        10 => 31,
        11 => 30,
        12 => 31,
        else => unreachable,
    };
}

fn unixTimestampToUTC(timestamp: u64) DateTime {
    const MILLIS_PER_SEC = 1000;
    const SECS_PER_MIN = 60;
    const SECS_PER_HOUR = SECS_PER_MIN * 60;
    const SECS_PER_DAY = SECS_PER_HOUR * 24;

    const millisecond: u16 = @intCast(@rem(timestamp, MILLIS_PER_SEC));
    const seconds = @divTrunc(timestamp, MILLIS_PER_SEC);

    // Compute the time of day.
    const hour: u8 = @intCast(@divTrunc(@rem(seconds, SECS_PER_DAY), SECS_PER_HOUR));
    const minute: u8 = @intCast(@divTrunc(@rem(seconds, SECS_PER_HOUR), SECS_PER_MIN));
    const second: u8 = @intCast(@rem(seconds, SECS_PER_MIN));

    // Compute the date.
    var days = @divTrunc(seconds, SECS_PER_DAY);
    var year: u32 = 1970;

    while (true) {
        const days_in_year: u16 = if (isLeapYear(year)) 366 else 365;
        if (days >= days_in_year) {
            days -= days_in_year;
            year += 1;
        } else break;
    }

    var month: u8 = 1;
    while (true) {
        const day_of_month = daysInMonth(month, year);
        if (days >= day_of_month) {
            days -= day_of_month;
            month += 1;
        } else break;
    }

    const day: u8 = @intCast(days + 1);

    return DateTime{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second,
        .millisecond = millisecond,
    };
}

pub fn callFunction(allocator: Allocator, _: *VariableEnv, name: *const Expression, _: *const Expression) !Value {
    if (name.IdentifierExpress.eqlLiteral("now")) {
        // 現在時刻を取得する関数
        const timestamp: u64 = @intCast(std.time.milliTimestamp());
        const dt = unixTimestampToUTC(timestamp);

        // 現在時刻を表す文字列を作成
        const time_str = std.fmt.allocPrint(allocator, "{}-{:0>2}-{:0>2}T{:0>2}:{:0>2}:{:0>2}.{:0>3}Z", .{ dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond }) catch return Errors.OutOfMemoryString;
        defer allocator.free(time_str);

        // Valueに変換して返す
        return Value{ .String = try String.newString(allocator, time_str) };
    }
    return Errors.FunctionCallFailed; // 未知の関数
}
