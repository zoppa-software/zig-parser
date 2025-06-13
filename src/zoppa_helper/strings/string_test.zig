const std = @import("std");
const testing = std.testing;
const String = @import("string.zig").String;
const Char = @import("string.zig").Char;
const Allocator = std.mem.Allocator;

test "newString/newSlice test" {
    const allocator = std.testing.allocator;
    const s0 = try String.newString(allocator, "Hello, World!");
    defer s0.deinit();

    try testing.expectEqual(13, s0.byteLen());
    try testing.expectEqualStrings("Hello, World!", s0.raw());

    const s1 = s0.mid(1, 3);
    defer s1.deinit();
    try testing.expectEqualSlices(u8, "ell", s1.raw());

    const s2 = String.newSlice("happy word", 6, 5);
    defer s2.deinit();
    try testing.expectEqualSlices(u8, "word", s2.raw());
}

test "concat test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello");
    defer s1.deinit();
    const s2 = try String.newString(allocator, ", World!");
    defer s2.deinit();

    const s3 = try s1.concat(allocator, &s2);
    defer s3.deinit();
    try testing.expectEqualStrings("Hello, World!", s3.raw());

    const s4 = try String.empty.concat(allocator, &String.empty);
    defer s4.deinit();
    try testing.expectEqualStrings("", s4.raw());
}

test "mid test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    const s2 = s1.mid(7, 5);
    defer s2.deinit();
    try testing.expectEqualStrings("World", s2.raw());

    const s3 = s1.mid(0, 5);
    defer s3.deinit();
    try testing.expectEqualStrings("Hello", s3.raw());

    const s4 = s1.mid(13, 5);
    defer s4.deinit();
    try testing.expectEqualSlices(u8, "", s4.raw());

    const s5 = s1.mid(0, 0);
    defer s5.deinit();
    try testing.expectEqualSlices(u8, "", s5.raw());

    const s6 = s1.mid(0, 13);
    defer s6.deinit();
    try testing.expectEqualStrings("Hello, World!", s6.raw());

    const s7 = s1.mid(0, 14);
    defer s7.deinit();
    try testing.expectEqualStrings("Hello, World!", s7.raw());

    const m1 = try String.newString(allocator, "雨にも負けず、風にも負けず、雪にも夏の暑さにも負けぬ、丈夫なからだを持ち、欲はなく、決して怒らず、いつも静かに笑っている。");
    defer m1.deinit();

    const m2 = m1.mid(0, 6);
    defer m2.deinit();
    try testing.expectEqualStrings("雨にも負けず", m2.raw());
    try testing.expectEqual(0, m2.start());
    try testing.expectEqual(6, m2.len());

    const m3 = m1.mid(14, 12);
    defer m3.deinit();
    try testing.expectEqualStrings("雪にも夏の暑さにも負けぬ", m3.raw());
    try testing.expectEqual(42, m3.start());
    try testing.expectEqual(12, m3.len());
}

test "len test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    try testing.expectEqual(13, s1.byteLen());
}

test "raw test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    const raw = s1.raw();
    try testing.expectEqualSlices(u8, "Hello, World!", raw);
}

test "at test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    const char1 = s1.at(0) orelse unreachable;
    try testing.expectEqualSlices(u8, "H", char1.value());

    const char2 = s1.at(7) orelse unreachable;
    try testing.expectEqualSlices(u8, "W", char2.value());

    const char3 = s1.at(13);
    try testing.expect(char3 == null);

    const s2 = String.newAllSlice("Zigは静的型付けのコンパイル型システムプログラミング言語");
    defer s2.deinit();
    const char4 = s2.at(0) orelse unreachable;
    try testing.expectEqualSlices(u8, "Z", char4.value());
    const char5 = s2.at(5) orelse unreachable;
    try testing.expectEqualSlices(u8, "的", char5.value());
    const char6 = s2.at(10) orelse unreachable;
    try testing.expectEqualSlices(u8, "コ", char6.value());
    try testing.expectEqual(29, s2.len());
}

test "compare test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "あいうえお");
    defer s1.deinit();
    const s2 = try String.newString(allocator, "あいうえお");
    defer s2.deinit();
    const s3 = try String.newString(allocator, "あいえおか");
    defer s3.deinit();

    try testing.expect(s1.compare(&s2) == String.Order.equal);
    try testing.expect(s1.compare(&s3) == String.Order.less);
    try testing.expect(s3.compare(&s1) == String.Order.greater);
}

test "iterate test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    var iter = s1.iterate();
    var count: usize = 0;

    while (iter.next()) |char| {
        try testing.expectEqualSlices(u8, s1.at(count).?.value(), char.value());
        count += 1;
    }
    try testing.expectEqual(13, count);
}

test "iterate with mid test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    const mid_s1 = s1.mid(7, 5);
    defer mid_s1.deinit();

    var iter = mid_s1.iterate();
    var count: usize = 0;

    while (iter.next()) |char| {
        try testing.expectEqualSlices(u8, mid_s1.at(count).?.value(), char.value());
        count += 1;
    }
    try testing.expectEqual(5, count);
}

test "isEmpty test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "");
    defer s1.deinit();

    try testing.expect(s1.isEmpty());

    const s2 = try String.newString(allocator, "Hello");
    defer s2.deinit();

    try testing.expect(!s2.isEmpty());
}

test "eql test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();
    const s2 = try String.newString(allocator, "Hello, World!");
    defer s2.deinit();
    const s3 = try String.newString(allocator, "Hello, Zig!");
    defer s3.deinit();

    try testing.expect(s1.eql(&s2));
    try testing.expect(!s1.eql(&s3));
}

test "eqlLiteral test" {
    const allocator = std.testing.allocator;
    const s1 = try String.newString(allocator, "Hello, World!");
    defer s1.deinit();

    try testing.expect(s1.eqlLiteral("Hello, World!"));
    try testing.expect(!s1.eqlLiteral("Hello, Zig!"));
    try testing.expect(!s1.eqlLiteral("HEllo, World!"));
}
