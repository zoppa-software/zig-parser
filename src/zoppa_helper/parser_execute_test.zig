const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexical = @import("lexical_analysis.zig");
const Parser = @import("parser_analysis.zig");
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;

test "三項演算子の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "x ? 1 : 2");
    defer ans1.deinit();
    try std.testing.expect(ans1.root_expr.TernaryExpress.condition.IdentifierExpress.eqlLiteral("x"));
    try std.testing.expectEqual(1.0, ans1.root_expr.TernaryExpress.true_expr.NumberExpress);
    try std.testing.expectEqual(2.0, ans1.root_expr.TernaryExpress.false_expr.NumberExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "true ? 3 : false");
    defer ans2.deinit();
    try std.testing.expectEqual(true, ans2.root_expr.TernaryExpress.condition.BooleanExpress);
    try std.testing.expectEqual(3.0, ans2.root_expr.TernaryExpress.true_expr.NumberExpress);
    try std.testing.expectEqual(false, ans2.root_expr.TernaryExpress.false_expr.BooleanExpress);
}

test "論理式の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "true and false");
    defer ans1.deinit();
    try std.testing.expectEqual(true, ans1.root_expr.BinaryExpress.left.BooleanExpress);
    try std.testing.expectEqual(Lexical.WordType.AndOperator, ans1.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(false, ans1.root_expr.BinaryExpress.right.BooleanExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "false or true");
    defer ans2.deinit();
    try std.testing.expectEqual(false, ans2.root_expr.BinaryExpress.left.BooleanExpress);
    try std.testing.expectEqual(Lexical.WordType.OrOperator, ans2.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(true, ans2.root_expr.BinaryExpress.right.BooleanExpress);

    var ans5 = try Parser.executesFromLiteral(allocator, "true xor false");
    defer ans5.deinit();
    try std.testing.expectEqual(true, ans5.root_expr.BinaryExpress.left.BooleanExpress);
    try std.testing.expectEqual(Lexical.WordType.XorOperator, ans5.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(false, ans5.root_expr.BinaryExpress.right.BooleanExpress);
}

test "比較式の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "1 == 2");
    defer ans1.deinit();
    try std.testing.expectEqual(1.0, ans1.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Equal, ans1.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(2.0, ans1.root_expr.BinaryExpress.right.NumberExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "3 <> 4");
    defer ans2.deinit();
    try std.testing.expectEqual(3.0, ans2.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.NotEqual, ans2.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(4.0, ans2.root_expr.BinaryExpress.right.NumberExpress);

    var ans3 = try Parser.executesFromLiteral(allocator, "5 < 6");
    defer ans3.deinit();
    try std.testing.expectEqual(5.0, ans3.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.LessThan, ans3.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(6.0, ans3.root_expr.BinaryExpress.right.NumberExpress);

    var ans4 = try Parser.executesFromLiteral(allocator, "7 <= 8");
    defer ans4.deinit();
    try std.testing.expectEqual(7.0, ans4.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.LessEqual, ans4.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(8.0, ans4.root_expr.BinaryExpress.right.NumberExpress);

    var ans5 = try Parser.executesFromLiteral(allocator, "9 > 10");
    defer ans5.deinit();
    try std.testing.expectEqual(9.0, ans5.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.GreaterThan, ans5.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(10.0, ans5.root_expr.BinaryExpress.right.NumberExpress);

    var ans6 = try Parser.executesFromLiteral(allocator, "11 >= 12");
    defer ans6.deinit();
    try std.testing.expectEqual(11.0, ans6.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.GreaterEqual, ans6.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(12.0, ans6.root_expr.BinaryExpress.right.NumberExpress);
}

test "加算、減算式の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "1 + 2");
    defer ans1.deinit();
    try std.testing.expectEqual(1.0, ans1.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Plus, ans1.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(2.0, ans1.root_expr.BinaryExpress.right.NumberExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "5 - 3");
    defer ans2.deinit();
    try std.testing.expectEqual(5.0, ans2.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Minus, ans2.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(3.0, ans2.root_expr.BinaryExpress.right.NumberExpress);
}

test "乗算、除算式の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "2 * 3");
    defer ans1.deinit();
    try std.testing.expectEqual(2.0, ans1.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Multiply, ans1.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(3.0, ans1.root_expr.BinaryExpress.right.NumberExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "10 / 2");
    defer ans2.deinit();
    try std.testing.expectEqual(10.0, ans2.root_expr.BinaryExpress.left.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Divide, ans2.root_expr.BinaryExpress.kind);
    try std.testing.expectEqual(2.0, ans2.root_expr.BinaryExpress.right.NumberExpress);
}

test "要素式の作成" {
    const allocator = std.testing.allocator;

    var ans1 = try Parser.executesFromLiteral(allocator, "true");
    defer ans1.deinit();
    try std.testing.expectEqual(true, ans1.root_expr.BooleanExpress);

    var ans2 = try Parser.executesFromLiteral(allocator, "false");
    defer ans2.deinit();
    try std.testing.expectEqual(false, ans2.root_expr.BooleanExpress);

    var ans3 = try Parser.executesFromLiteral(allocator, "x");
    defer ans3.deinit();
    try std.testing.expect(ans3.root_expr.IdentifierExpress.eqlLiteral("x"));

    var ans4 = try Parser.executesFromLiteral(allocator, "42");
    defer ans4.deinit();
    try std.testing.expectEqual(42.0, ans4.root_expr.NumberExpress);

    var ans5 = try Parser.executesFromLiteral(allocator, "\"Hello, World!\"");
    defer ans5.deinit();
    try std.testing.expect(ans5.root_expr.StringExpress.eqlLiteral("\"Hello, World!\""));

    var ans6 = try Parser.executesFromLiteral(allocator, "-42");
    defer ans6.deinit();
    try std.testing.expectEqual(42.0, ans6.root_expr.UnaryExpress.expr.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Minus, ans6.root_expr.UnaryExpress.kind);

    var ans7 = try Parser.executesFromLiteral(allocator, "+42");
    defer ans7.deinit();
    try std.testing.expectEqual(42.0, ans7.root_expr.UnaryExpress.expr.NumberExpress);
    try std.testing.expectEqual(Lexical.WordType.Plus, ans7.root_expr.UnaryExpress.kind);

    var ans8 = try Parser.executesFromLiteral(allocator, "!true");
    defer ans8.deinit();
    try std.testing.expectEqual(true, ans8.root_expr.UnaryExpress.expr.BooleanExpress);
    try std.testing.expectEqual(Lexical.WordType.Not, ans8.root_expr.UnaryExpress.kind);

    var ans9 = try Parser.executesFromLiteral(allocator, "!false");
    defer ans9.deinit();
    try std.testing.expectEqual(false, ans9.root_expr.UnaryExpress.expr.BooleanExpress);
    try std.testing.expectEqual(Lexical.WordType.Not, ans9.root_expr.UnaryExpress.kind);

    var ans10 = try Parser.executesFromLiteral(allocator, "(x)");
    defer ans10.deinit();
    try std.testing.expect(ans10.root_expr.ParenExpress.IdentifierExpress.eqlLiteral("x"));

    var ans11 = try Parser.executesFromLiteral(allocator, "[1,2,3]");
    defer ans11.deinit();
    try std.testing.expect(ans11.root_expr.ArrayVariableExpress.len == 3);
    try std.testing.expectEqual(1.0, ans11.root_expr.ArrayVariableExpress[0].NumberExpress);
    try std.testing.expectEqual(2.0, ans11.root_expr.ArrayVariableExpress[1].NumberExpress);
    try std.testing.expectEqual(3.0, ans11.root_expr.ArrayVariableExpress[2].NumberExpress);

    var ans12 = try Parser.executesFromLiteral(allocator, "now()");
    defer ans12.deinit();
    try std.testing.expect(ans12.root_expr.FunctionExpress.name.IdentifierExpress.eqlLiteral("now"));
}
