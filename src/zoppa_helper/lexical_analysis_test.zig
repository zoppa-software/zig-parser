const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const LexicalAnalysis = @import("lexical_analysis.zig");

test "splitWords test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice(" +123 + -456 - 789");
    defer input.deinit();

    const tokens = try LexicalAnalysis.splitWords(&input, allocator);
    defer allocator.free(tokens);

    try testing.expectEqual(7, tokens.len);
    try testing.expectEqualSlices(u8, "+", tokens[0].str.raw());
    try testing.expect(tokens[0].kind == LexicalAnalysis.WordType.Plus);
    try testing.expectEqualSlices(u8, "123", tokens[1].str.raw());
    try testing.expect(tokens[1].kind == LexicalAnalysis.WordType.Number);
    try testing.expectEqualSlices(u8, "+", tokens[2].str.raw());
    try testing.expect(tokens[2].kind == LexicalAnalysis.WordType.Plus);
    try testing.expectEqualSlices(u8, "-", tokens[3].str.raw());
    try testing.expect(tokens[3].kind == LexicalAnalysis.WordType.Minus);
    try testing.expectEqualSlices(u8, "456", tokens[4].str.raw());
    try testing.expect(tokens[4].kind == LexicalAnalysis.WordType.Number);
    try testing.expectEqualSlices(u8, "-", tokens[5].str.raw());
    try testing.expect(tokens[5].kind == LexicalAnalysis.WordType.Minus);
    try testing.expectEqualSlices(u8, "789", tokens[6].str.raw());
    try testing.expect(tokens[6].kind == LexicalAnalysis.WordType.Number);
}

test "splitWords empty input" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("");
    defer input.deinit();

    const tokens = try LexicalAnalysis.splitWords(&input, allocator);
    defer allocator.free(tokens);

    try testing.expectEqual(0, tokens.len);
}

test "splitWords keyword input" {
    const allocator = std.testing.allocator;

    const inp1 = String.newAllSlice("true-false");
    defer inp1.deinit();
    const tokens1 = try LexicalAnalysis.splitWords(&inp1, allocator);
    defer allocator.free(tokens1);

    try testing.expect(tokens1.len == 3);
    try testing.expect(tokens1[0].kind == LexicalAnalysis.WordType.TrueLiteral);
    try testing.expectEqualSlices(u8, "true", tokens1[0].str.raw());
    try testing.expect(tokens1[2].kind == LexicalAnalysis.WordType.FalseLiteral);
    try testing.expectEqualSlices(u8, "false", tokens1[2].str.raw());
}

test "splitBlocks test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("abcd#{123}efg");
    defer input.deinit();

    const ans1 = try LexicalAnalysis.splitEmbeddedText(&input, allocator);
    defer allocator.free(ans1);
    try std.testing.expectEqual(3, ans1.len);
    try std.testing.expectEqualSlices(u8, "abcd", ans1[0].str.raw());
    try std.testing.expect(ans1[0].kind == LexicalAnalysis.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "#{123}", ans1[1].str.raw());
    try std.testing.expect(ans1[1].kind == LexicalAnalysis.EmbeddedType.Unfold);
    try std.testing.expectEqualSlices(u8, "efg", ans1[2].str.raw());
    try std.testing.expect(ans1[2].kind == LexicalAnalysis.EmbeddedType.None);

    const input2 = String.newAllSlice("{if 1 + 2 > 0}あいうえお{else}かきくけこ{/if}");
    defer input2.deinit();

    const ans2 = try LexicalAnalysis.splitEmbeddedText(&input2, allocator);
    defer allocator.free(ans2);
    try std.testing.expectEqual(5, ans2.len);
    try std.testing.expectEqualSlices(u8, "1 + 2 > 0", ans2[0].str.raw());
    try std.testing.expect(ans2[0].kind == LexicalAnalysis.EmbeddedType.IfBlock);
    try std.testing.expectEqualSlices(u8, "あいうえお", ans2[1].str.raw());
    try std.testing.expect(ans2[1].kind == LexicalAnalysis.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{else}", ans2[2].str.raw());
    try std.testing.expect(ans2[2].kind == LexicalAnalysis.EmbeddedType.ElseBlock);
    try std.testing.expectEqualSlices(u8, "かきくけこ", ans2[3].str.raw());
    try std.testing.expect(ans2[3].kind == LexicalAnalysis.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{/if}", ans2[4].str.raw());
    try std.testing.expect(ans2[4].kind == LexicalAnalysis.EmbeddedType.EndIfBlock);

    const input3 = String.newAllSlice("${a=123; b='あいう'}{if a = 123}aは123です{/if}");
    defer input3.deinit();
    const ans3 = try LexicalAnalysis.splitEmbeddedText(&input3, allocator);
    defer allocator.free(ans3);
    try std.testing.expectEqual(4, ans3.len);
    try std.testing.expectEqualSlices(u8, "${a=123; b='あいう'}", ans3[0].str.raw());
    try std.testing.expect(ans3[0].kind == LexicalAnalysis.EmbeddedType.Variables);
    try std.testing.expectEqualSlices(u8, "a = 123", ans3[1].str.raw());
    try std.testing.expect(ans3[1].kind == LexicalAnalysis.EmbeddedType.IfBlock);
    try std.testing.expectEqualSlices(u8, "aは123です", ans3[2].str.raw());
    try std.testing.expect(ans3[2].kind == LexicalAnalysis.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{/if}", ans3[3].str.raw());
    try std.testing.expect(ans3[3].kind == LexicalAnalysis.EmbeddedType.EndIfBlock);
}
