const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const ParserError = @import("parser_analysis.zig").ParserError;
const String = @import("strings/string.zig").String;

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
