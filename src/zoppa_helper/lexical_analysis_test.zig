const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Lexical = @import("lexical_analysis.zig");
const LexicalError = @import("analysis_error.zig").LexicalError;

test "splitWords test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice(" +123 + -456 - 789");
    defer input.deinit();

    const tokens = try Lexical.splitWords(allocator, &input);
    defer allocator.free(tokens);

    try testing.expectEqual(7, tokens.len);
    try testing.expectEqualSlices(u8, "+", tokens[0].str.raw());
    try testing.expect(tokens[0].kind == Lexical.WordType.Plus);
    try testing.expectEqualSlices(u8, "123", tokens[1].str.raw());
    try testing.expect(tokens[1].kind == Lexical.WordType.Number);
    try testing.expectEqualSlices(u8, "+", tokens[2].str.raw());
    try testing.expect(tokens[2].kind == Lexical.WordType.Plus);
    try testing.expectEqualSlices(u8, "-", tokens[3].str.raw());
    try testing.expect(tokens[3].kind == Lexical.WordType.Minus);
    try testing.expectEqualSlices(u8, "456", tokens[4].str.raw());
    try testing.expect(tokens[4].kind == Lexical.WordType.Number);
    try testing.expectEqualSlices(u8, "-", tokens[5].str.raw());
    try testing.expect(tokens[5].kind == Lexical.WordType.Minus);
    try testing.expectEqualSlices(u8, "789", tokens[6].str.raw());
    try testing.expect(tokens[6].kind == Lexical.WordType.Number);
}

test "splitWords empty input" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("");
    defer input.deinit();

    const tokens = try Lexical.splitWords(allocator, &input);
    defer allocator.free(tokens);

    try testing.expectEqual(0, tokens.len);
}

test "splitWords keyword input" {
    const allocator = std.testing.allocator;

    const inp1 = String.newAllSlice("true-false");
    defer inp1.deinit();
    const tokens1 = try Lexical.splitWords(allocator, &inp1);
    defer allocator.free(tokens1);

    try testing.expect(tokens1.len == 3);
    try testing.expect(tokens1[0].kind == Lexical.WordType.TrueLiteral);
    try testing.expectEqualSlices(u8, "true", tokens1[0].str.raw());
    try testing.expect(tokens1[2].kind == Lexical.WordType.FalseLiteral);
    try testing.expectEqualSlices(u8, "false", tokens1[2].str.raw());
}

test "splitBlocks test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("abcd#{123}efg");
    defer input.deinit();

    const ans1 = try Lexical.splitEmbeddedText(allocator, &input);
    defer allocator.free(ans1);
    try std.testing.expectEqual(3, ans1.len);
    try std.testing.expectEqualSlices(u8, "abcd", ans1[0].str.raw());
    try std.testing.expect(ans1[0].kind == Lexical.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "#{123}", ans1[1].str.raw());
    try std.testing.expect(ans1[1].kind == Lexical.EmbeddedType.Unfold);
    try std.testing.expectEqualSlices(u8, "efg", ans1[2].str.raw());
    try std.testing.expect(ans1[2].kind == Lexical.EmbeddedType.None);

    const input2 = String.newAllSlice("{if 1 + 2 > 0}あいうえお{else}かきくけこ{/if}");
    defer input2.deinit();

    const ans2 = try Lexical.splitEmbeddedText(allocator, &input2);
    defer allocator.free(ans2);
    try std.testing.expectEqual(5, ans2.len);
    try std.testing.expectEqualSlices(u8, "1 + 2 > 0", ans2[0].str.raw());
    try std.testing.expect(ans2[0].kind == Lexical.EmbeddedType.IfBlock);
    try std.testing.expectEqualSlices(u8, "あいうえお", ans2[1].str.raw());
    try std.testing.expect(ans2[1].kind == Lexical.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{else}", ans2[2].str.raw());
    try std.testing.expect(ans2[2].kind == Lexical.EmbeddedType.ElseBlock);
    try std.testing.expectEqualSlices(u8, "かきくけこ", ans2[3].str.raw());
    try std.testing.expect(ans2[3].kind == Lexical.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{/if}", ans2[4].str.raw());
    try std.testing.expect(ans2[4].kind == Lexical.EmbeddedType.EndIfBlock);

    const input3 = String.newAllSlice("${a=123; b='あいう'}{if a = 123}aは123です{/if}");
    defer input3.deinit();
    const ans3 = try Lexical.splitEmbeddedText(allocator, &input3);
    defer allocator.free(ans3);
    try std.testing.expectEqual(4, ans3.len);
    try std.testing.expectEqualSlices(u8, "${a=123; b='あいう'}", ans3[0].str.raw());
    try std.testing.expect(ans3[0].kind == Lexical.EmbeddedType.Variables);
    try std.testing.expectEqualSlices(u8, "a = 123", ans3[1].str.raw());
    try std.testing.expect(ans3[1].kind == Lexical.EmbeddedType.IfBlock);
    try std.testing.expectEqualSlices(u8, "aは123です", ans3[2].str.raw());
    try std.testing.expect(ans3[2].kind == Lexical.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "{/if}", ans3[3].str.raw());
    try std.testing.expect(ans3[3].kind == Lexical.EmbeddedType.EndIfBlock);
}

test "escape test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("波括弧エスケープは \\{, \\}, \\#{, \\!{, \\${ = ${a = '\\{,\\},#\\{,!\\{,$\\{'}#{a}");
    defer input.deinit();

    const ans = try Lexical.splitEmbeddedText(allocator, &input);
    defer allocator.free(ans);
    try std.testing.expectEqual(3, ans.len);
    try std.testing.expectEqualSlices(u8, "波括弧エスケープは \\{, \\}, \\#{, \\!{, \\${ = ", ans[0].str.raw());
    try std.testing.expect(ans[0].kind == Lexical.EmbeddedType.None);
    try std.testing.expectEqualSlices(u8, "${a = '\\{,\\},#\\{,!\\{,$\\{'}", ans[1].str.raw());
    try std.testing.expect(ans[1].kind == Lexical.EmbeddedType.Variables);
    try std.testing.expectEqualSlices(u8, "#{a}", ans[2].str.raw());
    try std.testing.expect(ans[2].kind == Lexical.EmbeddedType.Unfold);
}

test "getStringLiteral test" {
    const input1 = String.newAllSlice("\"Hello, World!\"");
    var iter1 = input1.iterate();
    var token1 = try Lexical.getStringLiteral('"', &input1, &iter1);
    try std.testing.expectEqualSlices(u8, "\"Hello, World!\"", token1.raw());

    const input2 = String.newAllSlice("'This is a test.'");
    var iter2 = input2.iterate();
    var token2 = try Lexical.getStringLiteral('\'', &input2, &iter2);
    try std.testing.expectEqualSlices(u8, "'This is a test.'", token2.raw());

    const input3 = String.newAllSlice("\"Another test with \\\"escaped quotes\\\".\"");
    var iter3 = input3.iterate();
    var token3 = try Lexical.getStringLiteral('\"', &input3, &iter3);
    try std.testing.expectEqualSlices(u8, "\"Another test with \\\"escaped quotes\\\".\"", token3.raw());

    const input4 = String.newAllSlice("'Unclosed string literal");
    var iter4 = input4.iterate();
    if (Lexical.getStringLiteral('\'', &input4, &iter4)) |_| {
        unreachable; // ここに到達してはならない
    } else |err| {
        try std.testing.expectEqual(LexicalError.UnclosedStringLiteralError, err);
    }
}

test "getNumberToken test" {
    const input = String.newAllSlice("123 -456.78 +3.14 123_456_789 4..2 4__5");
    defer input.deinit();

    var iter = input.iterate();

    var token = try Lexical.getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "123", token.raw());
    _ = iter.next();

    token = try Lexical.getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "-456.78", token.raw());
    _ = iter.next();

    token = try Lexical.getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "+3.14", token.raw());
    _ = iter.next();

    token = try Lexical.getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "123_456_789", token.raw());
    _ = iter.next();

    token = try Lexical.getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "4.", token.raw());
    _ = iter.next();
    _ = iter.next();
    _ = iter.next();

    if (Lexical.getNumberToken(&input, &iter)) |_| {
        unreachable;
    } else |err| {
        try std.testing.expectEqual(LexicalError.ConsecutiveUnderscoreError, err);
    }
}

test "for test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("{for i in [1,2,3]}{/for}");
    defer input.deinit();

    const tokens = try Lexical.splitEmbeddedText(allocator, &input);
    defer allocator.free(tokens);

    try testing.expectEqual(2, tokens.len);
    try testing.expectEqualSlices(u8, "i in [1,2,3]", tokens[0].str.raw());
    try testing.expect(tokens[0].kind == Lexical.EmbeddedType.ForBlock);
    try testing.expectEqualSlices(u8, "{/for}", tokens[1].str.raw());
    try testing.expect(tokens[1].kind == Lexical.EmbeddedType.EndForBlock);
}

test "select test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("{select a}aは1です{case 1}aは2です{/select}");
    defer input.deinit();

    const tokens = try Lexical.splitEmbeddedText(allocator, &input);
    defer allocator.free(tokens);

    try testing.expectEqual(5, tokens.len);
    try testing.expectEqualSlices(u8, "a", tokens[0].str.raw());
    try testing.expect(tokens[0].kind == Lexical.EmbeddedType.SelectBlock);
    try testing.expectEqualSlices(u8, "aは1です", tokens[1].str.raw());
    try testing.expect(tokens[1].kind == Lexical.EmbeddedType.None);
    try testing.expectEqualSlices(u8, "1", tokens[2].str.raw());
    try testing.expect(tokens[2].kind == Lexical.EmbeddedType.SelectCaseBlock);
    try testing.expectEqualSlices(u8, "aは2です", tokens[3].str.raw());
    try testing.expect(tokens[3].kind == Lexical.EmbeddedType.None);
}
