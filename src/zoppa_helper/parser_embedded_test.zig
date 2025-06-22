const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Embedded = @import("parser_embedded.zig");
const Parser = @import("parser_analysis.zig");
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;
const Lexical = @import("lexical_analysis.zig");
const VariableEnv = @import("variable_environment.zig").VariableEnvironment;
const Errors = @import("analysis_error.zig").AnalysisErrors;

test "埋め込み式の解析" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var ans1 = try Parser.translateFromLiteral(allocator, "Hello, #{'World \\{\\}'}!");
    defer ans1.deinit();
    try std.testing.expect(ans1.root_expr.ListExpress.exprs.len == 3);
    try std.testing.expectEqualStrings("Hello, ", ans1.root_expr.ListExpress.exprs[0].NoneEmbeddedExpress.raw());
    try std.testing.expectEqualStrings("'World \\{\\}'", ans1.root_expr.ListExpress.exprs[1].UnfoldExpress.StringExpress.raw());
    try std.testing.expectEqualStrings("!", ans1.root_expr.ListExpress.exprs[2].NoneEmbeddedExpress.raw());

    var ans2 = try Parser.translateFromLiteral(allocator, "変数の値は ${a = 10; b = 20}a + b = #{a + b}です");
    defer ans2.deinit();
    try std.testing.expect(ans2.root_expr.ListExpress.exprs.len == 5);
    try std.testing.expectEqualStrings("変数の値は ", ans2.root_expr.ListExpress.exprs[0].NoneEmbeddedExpress.raw());
    const vars = ans2.root_expr.ListExpress.exprs[1];
    try std.testing.expect(vars.VariableListExpress.len == 2);
    try std.testing.expectEqualStrings("a", vars.VariableListExpress[0].VariableExpress.name.raw());
    try std.testing.expectEqual(10, vars.VariableListExpress[0].VariableExpress.value.NumberExpress);
    try std.testing.expectEqualStrings("b", vars.VariableListExpress[1].VariableExpress.name.raw());
    try std.testing.expectEqual(20, vars.VariableListExpress[1].VariableExpress.value.NumberExpress);
    try std.testing.expectEqualStrings("a + b = ", ans2.root_expr.ListExpress.exprs[2].NoneEmbeddedExpress.raw());
    try std.testing.expectEqualStrings("a", ans2.root_expr.ListExpress.exprs[3].UnfoldExpress.BinaryExpress.left.IdentifierExpress.raw());
    try std.testing.expectEqualStrings("b", ans2.root_expr.ListExpress.exprs[3].UnfoldExpress.BinaryExpress.right.IdentifierExpress.raw());
    try std.testing.expectEqualStrings("です", ans2.root_expr.ListExpress.exprs[4].NoneEmbeddedExpress.raw());

    var ans3 = try Parser.translateFromLiteral(allocator, "{if a > b}aはbより大きい{/if}");
    defer ans3.deinit();
    try std.testing.expect(ans3.root_expr.ListExpress.exprs.len == 1);
    const if_block = ans3.root_expr.ListExpress.exprs[0].IfExpress.exprs[0];
    try std.testing.expect(if_block.IfConditionExpress.inner.ListExpress.exprs.len == 1);
    try std.testing.expect(if_block.IfConditionExpress.condition.BinaryExpress.kind == Lexical.WordType.GreaterThan);
    try std.testing.expectEqualStrings("a", if_block.IfConditionExpress.condition.BinaryExpress.left.IdentifierExpress.raw());
    try std.testing.expectEqualStrings("b", if_block.IfConditionExpress.condition.BinaryExpress.right.IdentifierExpress.raw());
    try std.testing.expectEqualStrings("aはbより大きい", if_block.IfConditionExpress.inner.ListExpress.exprs[0].NoneEmbeddedExpress.raw());
}

test "埋め込み式の解析 - エラーケース" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // 不正な埋め込み式
    var result = Parser.translateFromLiteral(allocator, "不正な埋め込み式 #{") catch |err| {
        try std.testing.expectEqual(Errors.UnclosedBlockError, err);
        return;
    };
    defer result.deinit();

    // 変数ブロックの不正な構文
    var result2 = Parser.translateFromLiteral(allocator, "変数ブロックの不正な構文 ${a = 10; b = }") catch |err| {
        try std.testing.expectEqual(Errors.UnclosedBlockError, err);
        return;
    };
    defer result2.deinit();
}

test "配列変数式のテスト" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 配列変数式の解析
    var result1 = try Parser.translateFromLiteral(allocator, "配列変数式${arr = [1, 2, 3]} arr[0]=#{arr[0]}, arr[1]=#{arr[1]}, arr[2]=#{arr[2]}");
    defer result1.deinit();
    const ans1 = try result1.get(&variables);
    try std.testing.expectEqualStrings("配列変数式 arr[0]=1, arr[1]=2, arr[2]=3", ans1.String.raw());

    //const v = try variables.getExpr(&String.newAllSlice("arr"));
    //try std.testing.expect(v.ArrayVariableExpress.exprs[0].NumberExpress == 1);

    // 配列変数式の内容を確認
    //const arr_expr = result.root_expr.ListExpress.exprs[0].VariableListExpress.exprs[0];
    //try std.testing.expectEqualStrings("arr", arr_expr.VariableExpress.name.raw());
    //try std.testing.expect(arr_expr.VariableExpress.value.ArrayVariableExpress.items.len == 3);
    //try std.testing.expectEqual(1, arr_expr.VariableExpress.value.ArrayVariableExpress.items[0].NumberExpress);
    //try std.testing.expectEqual(2, arr_expr.VariableExpress.value.ArrayVariableExpress.items[1].NumberExpress);
    //try std.testing.expectEqual(3, arr_expr.VariableExpress.value.ArrayVariableExpress.items[2].NumberExpress);
}
