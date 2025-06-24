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
    const if_block = ans3.root_expr.ListExpress.exprs[0].IfExpress[0];
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

test "埋め込み式の解析 - 変数の参照" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 変数の登録
    try variables.registNumber(&String.newAllSlice("x"), 42);
    try variables.registNumber(&String.newAllSlice("y"), 100);

    // 埋め込み式の解析
    var result = try Parser.translateFromLiteral(allocator, "変数参照 #{x} と #{y} の合計は #{x + y}");
    defer result.deinit();

    const ans = try result.get(&variables);
    try std.testing.expectEqualStrings("変数参照 42 と 100 の合計は 142", ans.String.raw());
}

test "埋め込み式の解析 - 条件分岐" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 条件分岐の埋め込み式
    var result = try Parser.translateFromLiteral(allocator, "条件分岐 {if a > b}aはbより大きい{else}aはb以下{/if}");
    defer result.deinit();

    // 変数の設定
    try variables.registNumber(&String.newAllSlice("a"), 100);
    try variables.registNumber(&String.newAllSlice("b"), 2);

    // a > b
    const ans1 = try result.get(&variables);
    try std.testing.expectEqualStrings("条件分岐 aはbより大きい", ans1.String.raw());

    // 変数の設定
    try variables.registNumber(&String.newAllSlice("a"), 5);
    try variables.registNumber(&String.newAllSlice("b"), 50);

    // a > b
    const ans2 = try result.get(&variables);
    try std.testing.expectEqualStrings("条件分岐 aはb以下", ans2.String.raw());
}

test "埋め込み式の解析 - 変数の初期化" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 変数の初期化
    var result = try Parser.translateFromLiteral(allocator, "変数初期化${x = 10; y = 20} x=#{x}, y=#{y}");
    defer result.deinit();

    // 変数の登録
    const ans = try result.get(&variables);
    try std.testing.expectEqualStrings("変数初期化 x=10, y=20", ans.String.raw());
}

test "if埋め込み式 - else if ブロックのテスト" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 条件分岐: else if
    var result = try Parser.translateFromLiteral(allocator, "判定 {if a > b}a>b{else if a == b}a==b{else}a<b{/if}");
    defer result.deinit();

    // a > b
    try variables.registNumber(&String.newAllSlice("a"), 10);
    try variables.registNumber(&String.newAllSlice("b"), 5);
    const ans1 = try result.get(&variables);
    try std.testing.expectEqualStrings("判定 a>b", ans1.String.raw());

    // a == b
    try variables.registNumber(&String.newAllSlice("a"), 7);
    try variables.registNumber(&String.newAllSlice("b"), 7);
    const ans2 = try result.get(&variables);
    try std.testing.expectEqualStrings("判定 a==b", ans2.String.raw());

    // a < b
    try variables.registNumber(&String.newAllSlice("a"), 3);
    try variables.registNumber(&String.newAllSlice("b"), 8);
    const ans3 = try result.get(&variables);
    try std.testing.expectEqualStrings("判定 a<b", ans3.String.raw());
}

test "if埋め込み式 - ネストしたifブロック" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // ネストしたif
    var result = try Parser.translateFromLiteral(allocator, "外{if a > 0}内{if b > 0}b正{else}b負{/if}{else}a負{/if}");
    defer result.deinit();

    // a > 0, b > 0
    try variables.registNumber(&String.newAllSlice("a"), 1);
    try variables.registNumber(&String.newAllSlice("b"), 2);
    const ans1 = try result.get(&variables);
    try std.testing.expectEqualStrings("外内b正", ans1.String.raw());

    // a > 0, b <= 0
    try variables.registNumber(&String.newAllSlice("a"), 1);
    try variables.registNumber(&String.newAllSlice("b"), -2);
    const ans2 = try result.get(&variables);
    try std.testing.expectEqualStrings("外内b負", ans2.String.raw());

    // a <= 0
    try variables.registNumber(&String.newAllSlice("a"), 0);
    try variables.registNumber(&String.newAllSlice("b"), 100);
    const ans3 = try result.get(&variables);
    try std.testing.expectEqualStrings("外a負", ans3.String.raw());
}

test "if埋め込み式 - else if 省略時の挙動" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // else if なし
    var result = try Parser.translateFromLiteral(allocator, "{if x}yes{/if}");
    defer result.deinit();

    // x = 真
    try variables.registBoolean(&String.newAllSlice("x"), true);
    const ans1 = try result.get(&variables);
    try std.testing.expectEqualStrings("yes", ans1.String.raw());

    // x = 偽
    try variables.registBoolean(&String.newAllSlice("x"), false);
    const ans2 = try result.get(&variables);
    try std.testing.expectEqualStrings("", ans2.String.raw());
}

test "if埋め込み式 - elseブロックのみ" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // elseのみ
    var result = try Parser.translateFromLiteral(allocator, "{if flag}ON{else}OFF{/if}");
    defer result.deinit();

    // flag = 真
    try variables.registBoolean(&String.newAllSlice("flag"), true);
    const ans1 = try result.get(&variables);
    try std.testing.expectEqualStrings("ON", ans1.String.raw());

    // flag = 偽
    try variables.registBoolean(&String.newAllSlice("flag"), false);
    const ans2 = try result.get(&variables);
    try std.testing.expectEqualStrings("OFF", ans2.String.raw());
}

test "埋め込み式の解析 - 未対応の埋め込み式エラー" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // 未対応の埋め込み式
    var result = Parser.translateFromLiteral(allocator, "未対応の埋め込み式 {unknown}") catch |err| {
        try std.testing.expectEqual(Errors.InvalidCommandError, err);
        return;
    };
    defer result.deinit();
}

test "埋め込み式の解析 - ifブロックの未終了エラー" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // ifブロックが閉じられていない
    var result = Parser.translateFromLiteral(allocator, "{if x}閉じられていない") catch |err| {
        try std.testing.expectEqual(Errors.IfBlockNotClosed, err);
        return;
    };
    defer result.deinit();
}

test "埋め込み式の解析 - else if/elseの不正な位置エラー" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // else ifのみ
    var result = Parser.translateFromLiteral(allocator, "{else if x == 1}NG{/if}") catch |err| {
        try std.testing.expectEqual(Errors.IfBlockNotStarted, err);
        return;
    };
    defer result.deinit();

    // elseのみ
    var result2 = Parser.translateFromLiteral(allocator, "{else}NG{/if}") catch |err| {
        try std.testing.expectEqual(Errors.IfBlockNotStarted, err);
        return;
    };
    defer result2.deinit();
}

test "埋め込み式の解析 - 変数宣言エラー" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // 変数名が無効な場合のエラー
    var result1 = Parser.translateFromLiteral(allocator, "${1invalid = 10}") catch |err| {
        try std.testing.expectEqual(Errors.InvalidVariableName, err);
        return;
    };
    defer result1.deinit();

    // 変数の代入記号が無い場合のエラー
    var result2 = Parser.translateFromLiteral(allocator, "${invalid 10}") catch |err| {
        try std.testing.expectEqual(Errors.VariableAssignmentMissing, err);
        return;
    };
    defer result2.deinit();

    // 変数の値が無い場合のエラー
    var result3 = Parser.translateFromLiteral(allocator, "${valid = }") catch |err| {
        try std.testing.expectEqual(Errors.VariableValueMissing, err);
        return;
    };
    defer result3.deinit();

    // セミコロンが抜けている
    var result4 = Parser.translateFromLiteral(allocator, "${a = 1 b = 2}") catch |err| {
        try std.testing.expectEqual(Errors.VariableNotSemicolonSeparated, err);
        return;
    };
    defer result4.deinit();
}

test "埋め込み式の解析 - 変数の初期化と参照" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    // 変数の初期化
    var result = try Parser.translateFromLiteral(allocator, "${x = 42; y = 100} x=#{x}, y=#{y}");
    defer result.deinit();

    // 変数の登録
    const ans = try result.get(&variables);
    try std.testing.expectEqualStrings(" x=42, y=100", ans.String.raw());
}

test "埋め込み式の解析 - 変数の初期化と参照 - エラーケース" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // 変数の初期化でエラー
    var result = Parser.translateFromLiteral(allocator, "${x = 10; y = }") catch |err| {
        try std.testing.expectEqual(Errors.VariableValueMissing, err);
        return;
    };
    defer result.deinit();
}

test "for埋め込み式の解析" {
    const allocator = std.testing.allocator;
    var store: ExpressionStore = try ExpressionStore.init(allocator);
    defer store.deinit();

    // forブロックの解析
    var result = try Parser.translateFromLiteral(allocator, "{for i in [1,2,3,4,5]}i=#{i}{/for}");
    defer result.deinit();

    // 変数の登録
    var variables = try VariableEnv.init(allocator);
    defer variables.deinit();

    const ans = try result.get(&variables);
    try std.testing.expectEqualStrings("i=1i=2i=3i=4i=5", ans.String.raw());
}
