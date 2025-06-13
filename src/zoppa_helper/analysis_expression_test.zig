const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const Errors = @import("analysis_error.zig").AnalysisErrors;
const Value = @import("analysis_value.zig").AnalysisValue;
const Expression = @import("analysis_expression.zig").AnalysisExpression;

test "greaterExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const right2 = Value{ .Number = 5.0 };
    const result = try Expression.greaterExpression(left, right);
    try testing.expect(result.Boolean == true);
    const result2 = try Expression.greaterExpression(left, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("banana") };
    const rightStr2 = Value{ .String = &String.newAllSlice("apple") };
    const resultStr = try Expression.greaterExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == false);
    const resultStr2 = try Expression.greaterExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == false);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.greaterExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.GreaterOperatorNotSupported);
    };
}

test "greaterEqualExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const result = try Expression.greaterEqualExpression(left, right);
    try testing.expect(result.Boolean == true);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("banana") };
    const rightStr2 = Value{ .String = &String.newAllSlice("apple") };
    const resultStr = try Expression.greaterEqualExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == false);
    const resultStr2 = try Expression.greaterEqualExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == true);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.greaterEqualExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.GreaterEqualOperatorNotSupported);
    };
}

test "lessExpression test" {
    const left = Value{ .Number = 3.0 };
    const right = Value{ .Number = 5.0 };
    const right2 = Value{ .Number = 3.0 };
    const result = try Expression.lessExpression(left, right);
    try testing.expect(result.Boolean == true);
    const result2 = try Expression.lessExpression(left, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("banana") };
    const rightStr2 = Value{ .String = &String.newAllSlice("apple") };
    const resultStr = try Expression.lessExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == true);
    const resultStr2 = try Expression.lessExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == false);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.lessExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.LessOperatorNotSupported);
    };
}

test "lessEqualExpression test" {
    const left = Value{ .Number = 3.0 };
    const right = Value{ .Number = 5.0 };
    const result = try Expression.lessEqualExpression(left, right);
    try testing.expect(result.Boolean == true);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("banana") };
    const rightStr2 = Value{ .String = &String.newAllSlice("apple") };
    const resultStr = try Expression.lessEqualExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == true);
    const resultStr2 = try Expression.lessEqualExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == true);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.lessEqualExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.LessEqualOperatorNotSupported);
    };
}

test "equalExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 5.0 };
    const right2 = Value{ .Number = 3.0 };
    const result = try Expression.equalExpression(left, right);
    try testing.expect(result.Boolean == true);
    const result2 = try Expression.equalExpression(left, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr2 = Value{ .String = &String.newAllSlice("banana") };
    const resultStr = try Expression.equalExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == true);
    const resultStr2 = try Expression.equalExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == false);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = true };
    const rightBool2 = Value{ .Boolean = false };
    const resultBool = try Expression.equalExpression(leftBool, rightBool);
    try testing.expect(resultBool.Boolean == true);
    const resultBool2 = try Expression.equalExpression(leftBool, rightBool2);
    try testing.expect(resultBool2.Boolean == false);
}

test "notEqualExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const right2 = Value{ .Number = 5.0 };
    const result = try Expression.notEqualExpression(left, right);
    try testing.expect(result.Boolean == true);
    const result2 = try Expression.notEqualExpression(left, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("apple") };
    const rightStr = Value{ .String = &String.newAllSlice("banana") };
    const rightStr2 = Value{ .String = &String.newAllSlice("apple") };
    const resultStr = try Expression.notEqualExpression(leftStr, rightStr);
    try testing.expect(resultStr.Boolean == true);
    const resultStr2 = try Expression.notEqualExpression(leftStr, rightStr2);
    try testing.expect(resultStr2.Boolean == false);

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = true };
    const rightBool2 = Value{ .Boolean = false };
    const resultBool = try Expression.notEqualExpression(leftBool, rightBool);
    try testing.expect(resultBool.Boolean == false);
    const resultBool2 = try Expression.notEqualExpression(leftBool, rightBool2);
    try testing.expect(resultBool2.Boolean == true);
}

const StrCache = struct {
    allocator: Allocator,
};

var new_str: String = undefined;

fn fnConcat(instance: *StrCache, left: *const String, right: *const String) Errors!*String {
    const allocator = instance.allocator;
    new_str = left.concat(allocator, right) catch {
        return error.OutOfMemoryString;
    };
    return &new_str;
}

test "additionExpression test" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();
    const expression: Expression = .{ .parser = &parser, .data = .{ .NumberExpress = 0 } };

    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const result = try expression.additionExpression(left, right);
    try testing.expect(result.Number == 8.0);

    const leftStr = Value{ .String = &String.newAllSlice("Hello ") };
    const rightStr = Value{ .String = &String.newAllSlice("World!") };
    const resultStr = try expression.additionExpression(leftStr, rightStr);
    try testing.expect(resultStr.String.eqlLiteral("Hello World!"));
}

test "subtractionExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const result = try Expression.subtractionExpression(left, right);
    try testing.expect(result.Number == 2.0);

    const leftStr = Value{ .String = &String.newAllSlice("Hello World!") };
    const rightStr = Value{ .String = &String.newAllSlice(" World!") };
    _ = Expression.subtractionExpression(leftStr, rightStr) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.subtractionExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };
}

test "multiplicationExpression test" {
    const left = Value{ .Number = 5.0 };
    const right = Value{ .Number = 3.0 };
    const result = try Expression.multiplicationExpression(left, right);
    try testing.expect(result.Number == 15.0);

    const leftStr = Value{ .String = &String.newAllSlice("Hello") };
    const rightStr = Value{ .String = &String.newAllSlice("World") };
    _ = Expression.multiplicationExpression(leftStr, rightStr) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.multiplicationExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };
}

test "divisionExpression test" {
    const left = Value{ .Number = 6.0 };
    const right = Value{ .Number = 3.0 };
    const result = try Expression.divisionExpression(left, right);
    try testing.expect(result.Number == 2.0);

    const leftStr = Value{ .String = &String.newAllSlice("Hello") };
    const rightStr = Value{ .String = &String.newAllSlice("World") };
    _ = Expression.divisionExpression(leftStr, rightStr) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };

    const leftBool = Value{ .Boolean = true };
    const rightBool = Value{ .Boolean = false };
    _ = Expression.divisionExpression(leftBool, rightBool) catch |err| {
        try testing.expectEqual(err, error.CalculationFailed);
    };
}

test "andExpression test" {
    const left = Value{ .Boolean = true };
    const right = Value{ .Boolean = false };
    const result = try Expression.andExpression(left, right);
    try testing.expect(result.Boolean == false);

    const left2 = Value{ .Boolean = true };
    const right2 = Value{ .Boolean = true };
    const result2 = try Expression.andExpression(left2, right2);
    try testing.expect(result2.Boolean == true);

    const leftStr = Value{ .String = &String.newAllSlice("Hello") };
    _ = Expression.andExpression(leftStr, right) catch |err| {
        try testing.expectEqual(err, error.LogicalOperationFailed);
    };
}

test "orExpression test" {
    const left = Value{ .Boolean = true };
    const right = Value{ .Boolean = false };
    const result = try Expression.orExpression(left, right);
    try testing.expect(result.Boolean == true);

    const left2 = Value{ .Boolean = false };
    const right2 = Value{ .Boolean = false };
    const result2 = try Expression.orExpression(left2, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("Hello") };
    _ = Expression.orExpression(leftStr, right) catch |err| {
        try testing.expectEqual(err, error.LogicalOperationFailed);
    };
}

test "xorExpression test" {
    const left = Value{ .Boolean = true };
    const right = Value{ .Boolean = false };
    const result = try Expression.xorExpression(left, right);
    try testing.expect(result.Boolean == true);

    const left2 = Value{ .Boolean = true };
    const right2 = Value{ .Boolean = true };
    const result2 = try Expression.xorExpression(left2, right2);
    try testing.expect(result2.Boolean == false);

    const leftStr = Value{ .String = &String.newAllSlice("Hello") };
    _ = Expression.xorExpression(leftStr, right) catch |err| {
        try testing.expectEqual(err, error.LogicalOperationFailed);
    };
}
