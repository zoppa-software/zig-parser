const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Parser = @import("parser_analysis.zig");
const VariableEnv = @import("variable_environment.zig").VariableEnvironment;
const Expression = @import("analysis_expression.zig").AnalysisExpression;

test "計算値を取得する" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    var ans1 = try Parser.executesFromLiteral(allocator, "1 + 2 * 3");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expectEqual(7.0, value1.Number);

    var ans2 = try Parser.executesFromLiteral(allocator, "1 + 2 * 3 - 4 / 2");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expectEqual(5.0, value2.Number);

    var ans3 = try Parser.executesFromLiteral(allocator, "(1 + 2) * 3 - 4 / (1 + 3)");
    defer ans3.deinit();
    const value3 = try ans3.get(&variables);
    try std.testing.expectEqual(8.0, value3.Number);

    var ans4 = try Parser.executesFromLiteral(allocator, "10 - -5");
    defer ans4.deinit();
    const value4 = try ans4.get(&variables);
    try std.testing.expectEqual(15, value4.Number);

    var ans5 = try Parser.executesFromLiteral(allocator, "+3 + +2");
    defer ans5.deinit();
    const value5 = try ans5.get(&variables);
    try std.testing.expectEqual(5, value5.Number);
}

test "文字列の加算をする" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    var ans1 = try Parser.executesFromLiteral(allocator, "\"Hello\" + \" World!\"");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expectEqualStrings("Hello World!", value1.String.raw());

    var ans2 = try Parser.executesFromLiteral(allocator, "'Zig' + ' is awesome!'");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expectEqualStrings("Zig is awesome!", value2.String.raw());
}

test "比較値を取得する" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    var ans1 = try Parser.executesFromLiteral(allocator, "1 < 2");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expect(value1.Boolean);

    var ans1_1 = try Parser.executesFromLiteral(allocator, "5 < 3");
    defer ans1_1.deinit();
    const value1_1 = try ans1_1.get(&variables);
    try std.testing.expect(!value1_1.Boolean);

    var ans2 = try Parser.executesFromLiteral(allocator, "2 > 1");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expect(value2.Boolean);

    var ans2_1 = try Parser.executesFromLiteral(allocator, "3 > 5");
    defer ans2_1.deinit();
    const value2_1 = try ans2_1.get(&variables);
    try std.testing.expect(!value2_1.Boolean);

    var ans3 = try Parser.executesFromLiteral(allocator, "1 == 1");
    defer ans3.deinit();
    const value3 = try ans3.get(&variables);
    try std.testing.expect(value3.Boolean);

    var ans3_1 = try Parser.executesFromLiteral(allocator, "1 == 2");
    defer ans3_1.deinit();
    const value3_1 = try ans3_1.get(&variables);
    try std.testing.expect(!value3_1.Boolean);

    var ans4 = try Parser.executesFromLiteral(allocator, "1 <> 2");
    defer ans4.deinit();
    const value4 = try ans4.get(&variables);
    try std.testing.expect(value4.Boolean);

    var ans5 = try Parser.executesFromLiteral(allocator, "1 <= 2");
    defer ans5.deinit();
    const value5 = try ans5.get(&variables);
    try std.testing.expect(value5.Boolean);

    var ans5_1 = try Parser.executesFromLiteral(allocator, "2 <= 1");
    defer ans5_1.deinit();
    const value5_1 = try ans5_1.get(&variables);
    try std.testing.expect(!value5_1.Boolean);

    var ans5_2 = try Parser.executesFromLiteral(allocator, "1 <= 1");
    defer ans5_2.deinit();
    const value5_2 = try ans5_2.get(&variables);
    try std.testing.expect(value5_2.Boolean);

    var ans6 = try Parser.executesFromLiteral(allocator, "2 >= 1");
    defer ans6.deinit();
    const value6 = try ans6.get(&variables);
    try std.testing.expect(value6.Boolean);

    var ans6_1 = try Parser.executesFromLiteral(allocator, "1 >= 2");
    defer ans6_1.deinit();
    const value6_1 = try ans6_1.get(&variables);
    try std.testing.expect(!value6_1.Boolean);

    var ans6_2 = try Parser.executesFromLiteral(allocator, "1 >= 1");
    defer ans6_2.deinit();
    const value6_2 = try ans6_2.get(&variables);
    try std.testing.expect(value6_2.Boolean);
}

test "論理値を取得する" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    var ans1 = try Parser.executesFromLiteral(allocator, "true and false");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expect(!value1.Boolean);

    var ans2 = try Parser.executesFromLiteral(allocator, "true or false");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expect(value2.Boolean);

    var ans3 = try Parser.executesFromLiteral(allocator, "!true");
    defer ans3.deinit();
    const value3 = try ans3.get(&variables);
    try std.testing.expect(!value3.Boolean);

    var ans4 = try Parser.executesFromLiteral(allocator, "!false");
    defer ans4.deinit();
    const value4 = try ans4.get(&variables);
    try std.testing.expect(value4.Boolean);

    var ans5 = try Parser.executesFromLiteral(allocator, "true and true or false");
    defer ans5.deinit();
    const value5 = try ans5.get(&variables);
    try std.testing.expect(value5.Boolean);
}

test "変数の値を取得する" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    try variables.registNumber(&String.newAllSlice("x"), 10);
    try variables.registNumber(&String.newAllSlice("y"), 5);

    var ans1 = try Parser.executesFromLiteral(allocator, "x + y");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expectEqual(15.0, value1.Number);

    var ans2 = try Parser.executesFromLiteral(allocator, "x - y");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expectEqual(5.0, value2.Number);

    var ans3 = try Parser.executesFromLiteral(allocator, "x * y");
    defer ans3.deinit();
    const value3 = try ans3.get(&variables);
    try std.testing.expectEqual(50.0, value3.Number);

    var ans4 = try Parser.executesFromLiteral(allocator, "x / y");
    defer ans4.deinit();
    const value4 = try ans4.get(&variables);
    try std.testing.expectEqual(2.0, value4.Number);
}

test "変数の値を取得する（文字列）" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    try variables.registString(&String.newAllSlice("str1"), String.newAllSlice("Hello"));
    try variables.registString(&String.newAllSlice("str2"), String.newAllSlice("World"));

    var ans1 = try Parser.executesFromLiteral(allocator, "str1 + str2");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expectEqualStrings("HelloWorld", value1.String.raw());
}

test "三項演算子を使用する" {
    const allocator = std.testing.allocator;
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    try variables.registNumber(&String.newAllSlice("x"), 10);
    try variables.registNumber(&String.newAllSlice("y"), 5);

    var ans1 = try Parser.executesFromLiteral(allocator, "x > y ? x : y");
    defer ans1.deinit();
    const value1 = try ans1.get(&variables);
    try std.testing.expectEqual(10.0, value1.Number);

    var ans2 = try Parser.executesFromLiteral(allocator, "(x < y ? x : y) + 2");
    defer ans2.deinit();
    const value2 = try ans2.get(&variables);
    try std.testing.expectEqual(7.0, value2.Number);
}
