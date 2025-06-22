///! AnalysisValue.zig
///! `AnalysisValue`は、解析された値を表す構造体です。
///! この構造体は、実数値、文字列、真偽値、および配列値をサポートしています。
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const ValueError = @import("analysis_error.zig").ValueError;

/// 解析された値を表す構造体です。
pub const AnalysisValue = union(enum) {
    /// 実数値を表します。
    Number: f64,

    /// 文字列を表します。
    String: String,

    /// 真偽値を表します。
    Boolean: bool,

    /// 配列値を表します。
    Array: []const AnalysisValue,

    /// 値を解放します。
    pub fn deinit(self: *const AnalysisValue, allocator: Allocator) void {
        switch (self.*) {
            .Array => |ary| {
                for (ary) |item| {
                    item.deinit(allocator);
                }
                allocator.free(ary);
            },
            .String => |str| str.deinit(),
            else => {},
        }
    }

    // 文字列を連結して新しい文字列を生成します。
    //fn convertNumber(allocator: Allocator, left: *const String, right: f64) String {
    //    const msg = std.fmt.allocPrint(allocator, "{d}", .{right}) catch return ValueError.NumberConversionFailed;
    //    defer allocator.free(msg);
    //    return left.concat(allocator, msg) catch return ValueError.NumberConversionFailed;
    //}

    /// 文字列と実数値を連結して新しい文字列を生成します。
    /// 文字列は、実数値を文字列に変換して連結します。
    fn concatStringToNumber(allocator: Allocator, left: *const String, right: f64) ValueError!String {
        const msg = std.fmt.allocPrint(allocator, "{d}", .{right}) catch return ValueError.StringConversionFailed;
        defer allocator.free(msg);

        return left.concatLiteral(allocator, msg) catch return ValueError.StringConversionFailed;
    }

    /// 文字列同士を連結して新しい文字列を生成します。
    /// 文字列は、単純に連結されます。
    fn concatStringToString(allocator: Allocator, left: *const String, right: *const String) ValueError!String {
        return left.concat(allocator, right) catch return ValueError.StringConversionFailed;
    }

    /// 加算を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な加算を行います。
    /// 実数値と文字列の加算は、文字列として連結されます。
    pub fn add(self: *const AnalysisValue, allocator: Allocator, other: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| AnalysisValue{ .Number = self_num + other_num },
                else => return ValueError.AddOperatorNotSupported,
            },
            .String => |self_str| switch (other.*) {
                .Number => |other_num| AnalysisValue{
                    .String = try concatStringToNumber(allocator, &self_str, other_num),
                },
                .String => |other_str| AnalysisValue{
                    .String = try concatStringToString(allocator, &self_str, &other_str),
                },
                else => return ValueError.AddOperatorNotSupported,
            },
            else => return ValueError.AddOperatorNotSupported,
        };
    }

    /// 減算を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な減算を行います。
    pub fn subtract(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| AnalysisValue{ .Number = self_num - other_num },
                else => return ValueError.SubtractOperatorNotSupported,
            },
            else => return ValueError.SubtractOperatorNotSupported,
        };
    }
    /// 乗算を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な乗算を行います。
    pub fn multiply(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| AnalysisValue{ .Number = self_num * other_num },
                else => return ValueError.MultiplyOperatorNotSupported,
            },
            else => return ValueError.MultiplyOperatorNotSupported,
        };
    }

    /// 除算を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な除算を行います。
    pub fn divide(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| blk: {
                    if (other_num == 0.0) return ValueError.DivisionByZero;
                    break :blk AnalysisValue{ .Number = self_num / other_num };
                },
                else => return ValueError.DivideOperatorNotSupported,
            },
            else => return ValueError.DivideOperatorNotSupported,
        };
    }

    /// 等しい比較を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な比較を行います。
    /// 比較できない型の場合は、`Errors.EqualOperatorNotSupported`を返します。
    pub fn equal(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            // 実数値の比較
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| blk: {
                    const res = @abs(self_num - other_num);
                    break :blk res < std.math.nextAfter(f64, 0, 1);
                },
                else => return ValueError.EqualOperatorNotSupported,
            },
            // 文字列の比較
            .String => |self_str| switch (other.*) {
                .String => |other_str| self_str.eql(&other_str),
                else => return ValueError.EqualOperatorNotSupported,
            },
            // 真偽値の比較
            .Boolean => |self_bool| switch (other.*) {
                .Boolean => |other_bool| self_bool == other_bool,
                else => return ValueError.EqualOperatorNotSupported,
            },
            // 配列値の比較
            .Array => |self_array| switch (other.*) {
                .Array => |other_array| blk: {
                    if (self_array.len != other_array.len) break :blk false;
                    for (self_array, other_array) |item_self, item_other| {
                        const f = try item_self.equal(&item_other);
                        if (!f) break :blk false;
                    }
                    break :blk true;
                },
                else => return ValueError.EqualOperatorNotSupported,
            },
        };
    }

    /// 等しくない比較を行います。
    /// この関数は、`AnalysisValue`のデータ型に応じて適切な比較を行います。
    /// 比較できない型の場合は、`ValueError.NotEqualOperatorNotSupported`を返します。
    pub fn notEqual(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        const res = self.equal(other) catch return ValueError.NotEqualOperatorNotSupported;
        return !res;
    }

    /// より大きい比較を行います。
    pub fn greaterThan(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| blk: {
                    const res = @abs(self_num - other_num);
                    break :blk self_num > other_num and res > std.math.nextAfter(f64, 0, 1);
                },
                else => return ValueError.GreaterOperatorNotSupported,
            },
            .String => |self_str| switch (other.*) {
                .String => |other_str| self_str.compare(&other_str) == String.Order.greater,
                else => return ValueError.GreaterOperatorNotSupported,
            },
            else => return ValueError.GreaterOperatorNotSupported,
        };
    }

    /// より小さい比較を行います。
    pub fn lessThan(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            .Number => |self_num| switch (other.*) {
                .Number => |other_num| blk: {
                    const res = @abs(self_num - other_num);
                    break :blk self_num < other_num and res > std.math.nextAfter(f64, 0, 1);
                },
                else => return ValueError.LessOperatorNotSupported,
            },
            .String => |self_str| switch (other.*) {
                .String => |other_str| self_str.compare(&other_str) == String.Order.less,
                else => return ValueError.LessOperatorNotSupported,
            },
            else => return ValueError.LessOperatorNotSupported,
        };
    }

    /// より大きいか等しい比較を行います。
    pub fn greaterEqual(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        const res = self.lessThan(other) catch return ValueError.GreaterEqualOperatorNotSupported;
        return !res;
    }

    /// より小さいか等しい比較を行います。
    pub fn lessEqual(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        const res = self.greaterThan(other) catch return ValueError.LessEqualOperatorNotSupported;
        return !res;
    }

    /// 論理積を行います。
    pub fn andOperation(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            .Boolean => |self_bool| switch (other.*) {
                .Boolean => |other_bool| self_bool and other_bool,
                else => return ValueError.AndOperatorNotSupported,
            },
            else => return ValueError.AndOperatorNotSupported,
        };
    }

    /// 論理和を行います。
    pub fn orOperation(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            .Boolean => |self_bool| switch (other.*) {
                .Boolean => |other_bool| self_bool or other_bool,
                else => return ValueError.OrOperatorNotSupported,
            },
            else => return ValueError.OrOperatorNotSupported,
        };
    }

    /// 排他論理和を行います。
    pub fn xorOperation(self: *const AnalysisValue, other: *const AnalysisValue) ValueError!bool {
        return switch (self.*) {
            .Boolean => |self_bool| switch (other.*) {
                .Boolean => |other_bool| (self_bool != other_bool),
                else => return ValueError.XorOperatorNotSupported,
            },
            else => return ValueError.XorOperatorNotSupported,
        };
    }

    /// 前置きプラス演算子を適用します。
    pub fn unaryPlus(self: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |num| AnalysisValue{ .Number = num },
            else => return ValueError.UnaryOperatorNotSupported,
        };
    }
    /// 前置きマイナス演算子を適用します。
    pub fn unaryMinus(self: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Number => |num| AnalysisValue{ .Number = -num },
            else => return ValueError.UnaryOperatorNotSupported,
        };
    }

    /// 論理否定演算子を適用します。
    pub fn notOperation(self: *const AnalysisValue) ValueError!AnalysisValue {
        return switch (self.*) {
            .Boolean => |bool_val| AnalysisValue{ .Boolean = !bool_val },
            else => return ValueError.NotOperatorNotSupported,
        };
    }

    /// 文字列を返します。
    pub fn toString(self: *const AnalysisValue, allocator: Allocator) ValueError!String {
        return switch (self.*) {
            .Number => |num| {
                // 実数値を文字列に変換します。
                const msg = std.fmt.allocPrint(allocator, "{d}", .{num}) catch return ValueError.CannotConvertToString;
                defer allocator.free(msg);
                return String.newString(allocator, msg) catch return ValueError.CannotConvertToString;
            },
            .String => |str| {
                // 文字列をクローンして返します。
                return String.newString(allocator, str.raw()) catch return ValueError.CannotConvertToString;
            },
            .Boolean => |bool_val| {
                // 真偽値を文字列に変換します。
                const msg = if (bool_val) "true" else "false";
                return String.newAllSlice(msg);
            },
            .Array => |array| {
                // 配列値を文字列に変換します。
                var buffer = ArrayList(u8).init(allocator);
                defer buffer.deinit();

                buffer.appendSlice("[") catch return ValueError.CannotConvertToString;
                for (array, 0..) |item, i| {
                    if (i > 0) {
                        buffer.appendSlice(",") catch return ValueError.CannotConvertToString;
                    }
                    const item_str = item.toString(allocator) catch return ValueError.CannotConvertToString;
                    buffer.appendSlice(item_str.raw()) catch return ValueError.CannotConvertToString;
                }
                buffer.appendSlice("]") catch return ValueError.CannotConvertToString;

                return String.newString(allocator, buffer.items) catch return ValueError.CannotConvertToString;
            },
        };
    }
};

test "AnalysisValue 生成と解放" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 3.14 };
    defer value1.deinit(allocator);
    try std.testing.expect(value1.Number == 3.14);

    // 文字列の確認
    var str = String.newAllSlice("Hello, World!");
    defer str.deinit();
    var value2 = AnalysisValue{ .String = str };
    defer value2.deinit(allocator);
    try std.testing.expect(value2.String.eqlLiteral("Hello, World!"));

    // 真偽値の確認
    var value3 = AnalysisValue{ .Boolean = true };
    defer value3.deinit(allocator);
    try std.testing.expect(value3.Boolean == true);

    // 配列値の確認
    var array = try allocator.alloc(AnalysisValue, 2);
    array[0] = AnalysisValue{ .Number = 1.0 };
    array[1] = AnalysisValue{ .String = str };
    var value4 = AnalysisValue{ .Array = array };
    defer value4.deinit(allocator);
    try std.testing.expect(value4.Array.len == 2);
    try std.testing.expect(value4.Array[0].Number == 1.0);
    try std.testing.expect(value4.Array[1].String.eqlLiteral("Hello, World!"));
}

test "等しい比較、等しくない比較" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 3.14 };
    defer value1.deinit(allocator);
    var value2 = AnalysisValue{ .Number = 3.14 };
    defer value2.deinit(allocator);
    try std.testing.expect(try value1.equal(&value2));
    try std.testing.expect(!try value1.notEqual(&value2));

    // 実数の比較で等しくない場合の確認
    var value1_1 = AnalysisValue{ .Number = 3.14 };
    defer value1_1.deinit(allocator);
    var value1_2 = AnalysisValue{ .Number = 3.24 };
    defer value1_2.deinit(allocator);
    try std.testing.expect(!try value1_1.equal(&value1_2));
    try std.testing.expect(try value1_1.notEqual(&value1_2));

    // 文字列の確認
    var str1 = String.newAllSlice("Hello");
    defer str1.deinit();
    var str2 = String.newAllSlice("Hello");
    defer str2.deinit();
    var value3 = AnalysisValue{ .String = str1 };
    defer value3.deinit(allocator);
    var value4 = AnalysisValue{ .String = str2 };
    defer value4.deinit(allocator);
    try std.testing.expect(try value3.equal(&value4));
    try std.testing.expect(!try value3.notEqual(&value4));

    // 文字列の比較で等しくない場合の確認
    var str3 = String.newAllSlice("World");
    defer str3.deinit();
    var str4 = String.newAllSlice("Hello");
    defer str4.deinit();
    var value3_1 = AnalysisValue{ .String = str3 };
    defer value3_1.deinit(allocator);
    var value3_2 = AnalysisValue{ .String = str4 };
    defer value3_2.deinit(allocator);
    try std.testing.expect(!try value3_1.equal(&value3_2));
    try std.testing.expect(try value3_1.notEqual(&value3_2));

    // 真偽値の確認
    var value5 = AnalysisValue{ .Boolean = true };
    defer value5.deinit(allocator);
    var value6 = AnalysisValue{ .Boolean = true };
    defer value6.deinit(allocator);
    try std.testing.expect(try value5.equal(&value6));
    try std.testing.expect(!try value5.notEqual(&value6));

    // 配列値の確認
    var array1 = try allocator.alloc(AnalysisValue, 2);
    array1[0] = AnalysisValue{ .Number = 1.0 };
    array1[1] = AnalysisValue{ .String = str1 };
    var value7 = AnalysisValue{ .Array = array1 };
    defer value7.deinit(allocator);
    var array2 = try allocator.alloc(AnalysisValue, 2);
    array2[0] = AnalysisValue{ .Number = 1.0 };
    array2[1] = AnalysisValue{ .String = str2 };
    var value8 = AnalysisValue{ .Array = array2 };
    defer value8.deinit(allocator);
    try std.testing.expect(try value7.equal(&value8));
    try std.testing.expect(!try value7.notEqual(&value8));

    // 配列値の比較で等しくない場合の確認
    var array3 = try allocator.alloc(AnalysisValue, 2);
    array3[0] = AnalysisValue{ .Number = 1.0 };
    array3[1] = AnalysisValue{ .String = str3 };
    var value9 = AnalysisValue{ .Array = array3 };
    defer value9.deinit(allocator);
    var array4 = try allocator.alloc(AnalysisValue, 2);
    array4[0] = AnalysisValue{ .Number = 2.0 };
    array4[1] = AnalysisValue{ .String = str4 };
    var value10 = AnalysisValue{ .Array = array4 };
    defer value10.deinit(allocator);
    try std.testing.expect(!try value9.equal(&value10));
    try std.testing.expect(try value9.notEqual(&value10));
}

test "より大きい比較" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 5.0 };
    defer value1.deinit(allocator);
    var value2 = AnalysisValue{ .Number = 3.0 };
    defer value2.deinit(allocator);
    try std.testing.expect(try value1.greaterThan(&value2));

    // 文字列の確認
    var str1 = String.newAllSlice("banana");
    defer str1.deinit();
    var str2 = String.newAllSlice("apple");
    defer str2.deinit();
    var value3 = AnalysisValue{ .String = str1 };
    defer value3.deinit(allocator);
    var value4 = AnalysisValue{ .String = str2 };
    defer value4.deinit(allocator);
    try std.testing.expect(try value3.greaterThan(&value4));
}

test "より小さい比較" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 3.0 };
    defer value1.deinit(allocator);
    var value2 = AnalysisValue{ .Number = 5.0 };
    defer value2.deinit(allocator);
    try std.testing.expect(try value1.lessThan(&value2));

    // 文字列の確認
    var str1 = String.newAllSlice("apple");
    defer str1.deinit();
    var str2 = String.newAllSlice("banana");
    defer str2.deinit();
    var value3 = AnalysisValue{ .String = str1 };
    defer value3.deinit(allocator);
    var value4 = AnalysisValue{ .String = str2 };
    defer value4.deinit(allocator);
    try std.testing.expect(try value3.lessThan(&value4));
}

test "より大きいか等しい比較" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 5.0 };
    defer value1.deinit(allocator);
    var value2 = AnalysisValue{ .Number = 5.0 };
    defer value2.deinit(allocator);
    try std.testing.expect(try value1.greaterEqual(&value2));

    var value1_1 = AnalysisValue{ .Number = 5.0 };
    defer value1_1.deinit(allocator);
    var value1_2 = AnalysisValue{ .Number = 3.0 };
    defer value1_2.deinit(allocator);
    try std.testing.expect(try value1_1.greaterEqual(&value1_2));

    // 文字列の確認
    var str1 = String.newAllSlice("banana");
    defer str1.deinit();
    var str2 = String.newAllSlice("banana");
    defer str2.deinit();
    var value3 = AnalysisValue{ .String = str1 };
    defer value3.deinit(allocator);
    var value4 = AnalysisValue{ .String = str2 };
    defer value4.deinit(allocator);
    try std.testing.expect(try value3.greaterEqual(&value4));

    var str1_1 = String.newAllSlice("banana");
    defer str1_1.deinit();
    var str1_2 = String.newAllSlice("apple");
    defer str1_2.deinit();
    var value1_3 = AnalysisValue{ .String = str1_1 };
    defer value1_3.deinit(allocator);
    var value1_4 = AnalysisValue{ .String = str1_2 };
    defer value1_4.deinit(allocator);
    try std.testing.expect(try value1_3.greaterEqual(&value1_4));
}

test "より小さいか等しい比較" {
    const allocator = std.testing.allocator;

    // 実数の確認
    var value1 = AnalysisValue{ .Number = 3.0 };
    defer value1.deinit(allocator);
    var value2 = AnalysisValue{ .Number = 3.0 };
    defer value2.deinit(allocator);
    try std.testing.expect(try value1.lessEqual(&value2));

    var value1_1 = AnalysisValue{ .Number = 3.0 };
    defer value1_1.deinit(allocator);
    var value1_2 = AnalysisValue{ .Number = 5.0 };
    defer value1_2.deinit(allocator);
    try std.testing.expect(try value1_1.lessEqual(&value1_2));

    // 文字列の確認
    var str1 = String.newAllSlice("apple");
    defer str1.deinit();
    var str2 = String.newAllSlice("apple");
    defer str2.deinit();
    var value3 = AnalysisValue{ .String = str1 };
    defer value3.deinit(allocator);
    var value4 = AnalysisValue{ .String = str2 };
    defer value4.deinit(allocator);
    try std.testing.expect(try value3.lessEqual(&value4));

    var str1_1 = String.newAllSlice("apple");
    defer str1_1.deinit();
    var str1_2 = String.newAllSlice("banana");
    defer str1_2.deinit();
    var value1_3 = AnalysisValue{ .String = str1_1 };
    defer value1_3.deinit(allocator);
    var value1_4 = AnalysisValue{ .String = str1_2 };
    defer value1_4.deinit(allocator);
    try std.testing.expect(try value1_3.lessEqual(&value1_4));
}

test "比較できない型の比較" {
    const allocator = std.testing.allocator;

    // 実数と文字列の比較
    var value1 = AnalysisValue{ .Number = 3.14 };
    defer value1.deinit(allocator);
    var str = String.newAllSlice("Hello");
    defer str.deinit();
    var value2 = AnalysisValue{ .String = str };
    defer value2.deinit(allocator);
    try std.testing.expectError(ValueError.EqualOperatorNotSupported, value1.equal(&value2));
}
