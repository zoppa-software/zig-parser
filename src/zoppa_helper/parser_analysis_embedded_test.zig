const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const ParserError = @import("analysis_error.zig").ParserError;

test "translate test" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("Hello, #{'World \\{\\}'}!");
    const expr1 = try parser.translate(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqualStrings("Hello, World {}!", ans1.String.raw());

    const inp2 = String.newAllSlice("1.1 + 1 = #{1.1 + 1}");
    const expr2 = try parser.translate(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqualStrings("1.1 + 1 = 2.1", ans2.String.raw());
}

test "if block test" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("始めました{if 1 + 2 > 0}あいうえお{else}かきくけこ{/if}終わりました");
    const expr1 = try parser.translate(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqualStrings("始めましたあいうえお終わりました", ans1.String.raw());

    const inp2 = String.newAllSlice("どれが一致する? {if false}A{elseif true}{if   false   }B_1{else}B_2{/if}{else}C{/if}");
    const expr2 = try parser.translate(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqualStrings("どれが一致する? B_2", ans2.String.raw());
}

test "variables block test" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("変数の値は ${a = 10; b = 20}a + b = #{a + b}です");
    const expr1 = try parser.translate(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqualStrings("変数の値は a + b = 30です", ans1.String.raw());

    const inp2 = String.newAllSlice("名前は${name = '造田'}#{name}です");
    const expr2 = try parser.translate(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqualStrings("名前は造田です", ans2.String.raw());

    const inp3 = String.newAllSlice("空の変数${}は無視されます");
    const expr3 = try parser.translate(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqualStrings("空の変数は無視されます", ans3.String.raw());
}

test "error handling test" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("無効な変数名は${invalid variable name}");
    const expr1 = parser.translate(&inp1);
    try testing.expectError(ParserError.VariableAssignmentMissing, expr1);

    const inp2 = String.newAllSlice("変数の値がない場合は${a = }エラーになります");
    const expr2 = parser.translate(&inp2);
    try testing.expectError(ParserError.VariableValueMissing, expr2);

    const inp3 = String.newAllSlice("セミコロンで区切られていない変数${a = 10 b = 20}");
    const expr3 = parser.translate(&inp3);
    try testing.expectError(ParserError.VariableNotSemicolonSeparated, expr3);

    const inp4 = String.newAllSlice("無効な変数名は${0 = 10}");
    const expr4 = parser.translate(&inp4);
    try testing.expectError(ParserError.InvalidVariableName, expr4);
}
