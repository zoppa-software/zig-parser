const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const Word = @import("lexical_analysis.zig").Word;
const WordType = @import("lexical_analysis.zig").WordType;
const splitWords = @import("lexical_analysis.zig").splitWords;

test "splitWords test" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice(" +123 + -456 - 789");
    defer input.deinit();

    const tokens = try splitWords(&input, allocator);
    defer allocator.free(tokens);

    try testing.expectEqual(7, tokens.len);
    try testing.expectEqualSlices(u8, "+", tokens[0].str.raw());
    try testing.expect(tokens[0].kind == WordType.Plus);
    try testing.expectEqualSlices(u8, "123", tokens[1].str.raw());
    try testing.expect(tokens[1].kind == WordType.Number);
    try testing.expectEqualSlices(u8, "+", tokens[2].str.raw());
    try testing.expect(tokens[2].kind == WordType.Plus);
    try testing.expectEqualSlices(u8, "-", tokens[3].str.raw());
    try testing.expect(tokens[3].kind == WordType.Minus);
    try testing.expectEqualSlices(u8, "456", tokens[4].str.raw());
    try testing.expect(tokens[4].kind == WordType.Number);
    try testing.expectEqualSlices(u8, "-", tokens[5].str.raw());
    try testing.expect(tokens[5].kind == WordType.Minus);
    try testing.expectEqualSlices(u8, "789", tokens[6].str.raw());
    try testing.expect(tokens[6].kind == WordType.Number);
}

test "splitWords empty input" {
    const allocator = std.testing.allocator;
    const input = String.newAllSlice("");
    defer input.deinit();

    const tokens = try splitWords(&input, allocator);
    defer allocator.free(tokens);

    try testing.expectEqual(0, tokens.len);
}

test "splitWords keyword input" {
    const allocator = std.testing.allocator;

    const inp1 = String.newAllSlice("true");
    defer inp1.deinit();
    const tokens1 = try splitWords(&inp1, allocator);
    defer allocator.free(tokens1);

    try testing.expect(tokens1.len == 1);
    try testing.expect(tokens1[0].kind == WordType.Identifier);
    try testing.expectEqualSlices(u8, "true", tokens1[0].str.raw());
}
