const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");

const AllErrors = LexicalAnalysis.LexicalError || ParserAnalysis.ParserError;

/// 式の値を表す。
/// この値は、数値、文字列、真偽値、またはエラーを含むことができます。
pub const AnalysisValue = union(enum) {
    Number: f64,
    String: *String,
    Boolean: bool,
};

/// より大きいを実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn greaterExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => blk: {
                const res = @abs(leftValue.Number - rightValue.Number);
                break :blk .{ .Boolean = leftValue.Number > rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
            },
            else => error.GreaterOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.greater },
            else => error.GreaterOperatorNotSupported,
        },
        else => error.GreaterOperatorNotSupported,
    };
}

/// 以上を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn greaterEqualExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => blk: {
                const res = @abs(leftValue.Number - rightValue.Number);
                break :blk .{ .Boolean = leftValue.Number > rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
            },
            else => error.GreaterEqualOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.less },
            else => error.GreaterEqualOperatorNotSupported,
        },
        else => error.GreaterEqualOperatorNotSupported,
    };
}

/// より小さいを実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn lessExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => blk: {
                const res = @abs(leftValue.Number - rightValue.Number);
                break :blk .{ .Boolean = leftValue.Number < rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
            },
            else => error.LessOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.less },
            else => error.LessOperatorNotSupported,
        },
        else => error.LessOperatorNotSupported,
    };
}

/// 以下を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn lessEqualExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => blk: {
                const res = @abs(leftValue.Number - rightValue.Number);
                break :blk .{ .Boolean = leftValue.Number < rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
            },
            else => error.LessEqualOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.greater },
            else => error.LessEqualOperatorNotSupported,
        },
        else => error.LessEqualOperatorNotSupported,
    };
}

/// 等価演算子を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn equalExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) <= std.math.nextAfter(f64, 0, 1) },
            else => error.EqualOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.equal },
            else => error.EqualOperatorNotSupported,
        },
        .Boolean => switch (rightValue) {
            .Boolean => .{ .Boolean = leftValue.Boolean == rightValue.Boolean },
            else => error.EqualOperatorNotSupported,
        },
    };
}

/// 不等号を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn notEqualExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) > std.math.nextAfter(f64, 0, 1) },
            else => error.NotEqualOperatorNotSupported,
        },
        .String => switch (rightValue) {
            .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.equal },
            else => error.NotEqualOperatorNotSupported,
        },
        .Boolean => switch (rightValue) {
            .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
            else => error.NotEqualOperatorNotSupported,
        },
    };
}

/// 数値、文字の加算を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn additionExpression(leftValue: AnalysisValue, rightValue: AnalysisValue, comptime T: type, instance: *const T, concat: fn (instance: *const T, left: *String, right: *String) AllErrors!*String) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => .{ .Number = leftValue.Number + rightValue.Number },
            else => error.CalculationFailed,
        },
        .String => switch (rightValue) {
            .String => .{ .String = try concat(instance, leftValue.String, rightValue.String) },
            else => error.CalculationFailed,
        },
        else => error.CalculationFailed,
    };
}

/// 数値の減算を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn subtractionExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => .{ .Number = leftValue.Number - rightValue.Number },
            else => error.CalculationFailed,
        },
        else => error.CalculationFailed,
    };
}

/// 数値の乗算を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn multiplicationExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => .{ .Number = leftValue.Number * rightValue.Number },
            else => error.CalculationFailed,
        },
        else => error.CalculationFailed,
    };
}

/// 数値の除算を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn divisionExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Number => switch (rightValue) {
            .Number => if (rightValue.Number != 0) .{ .Number = leftValue.Number / rightValue.Number } else error.InvalidExpression,
            else => error.CalculationFailed,
        },
        else => error.CalculationFailed,
    };
}

/// AND演算子を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn andExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Boolean => switch (rightValue) {
            .Boolean => .{ .Boolean = leftValue.Boolean and rightValue.Boolean },
            else => error.LogicalOperationFailed,
        },
        else => error.LogicalOperationFailed,
    };
}

/// OR演算子を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn orExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Boolean => switch (rightValue) {
            .Boolean => .{ .Boolean = leftValue.Boolean or rightValue.Boolean },
            else => error.LogicalOperationFailed,
        },
        else => error.LogicalOperationFailed,
    };
}

/// XOR演算を実行します。
/// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
pub fn xorExpression(leftValue: AnalysisValue, rightValue: AnalysisValue) AllErrors!AnalysisValue {
    return switch (leftValue) {
        .Boolean => switch (rightValue) {
            .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
            else => error.LogicalOperationFailed,
        },
        else => error.LogicalOperationFailed,
    };
}
