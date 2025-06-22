///! AnalysisIterator.zig
///! パースや解析のための単語やブロックのイテレータを提供します。
const std = @import("std");
const testing = std.testing;

/// 単語、ブロックのイテレータ。
pub fn AnalysisIterator(comptime T: type) type {
    return struct {
        /// 単語のリスト
        items: []T,
        index: usize,

        pub fn init(items: []T) @This() {
            return .{ .items = items, .index = 0 };
        }

        /// 次の要素が存在するかどうかを確認します。
        pub fn hasNext(self: *@This()) bool {
            return self.index < self.items.len;
        }

        /// 現在の要素を取得します。
        pub fn peek(self: *@This()) ?T {
            if (self.index < self.items.len) {
                return self.items[self.index];
            } else {
                return null;
            }
        }

        /// 次の要素を取得します。
        pub fn next(self: *@This()) ?T {
            if (self.index < self.items.len) {
                const res = self.items[self.index];
                self.index += 1;
                return res;
            } else {
                return null;
            }
        }
    };
}

test "イテレーターループテスト" {
    var values: [5]u32 = .{ 1, 2, 3, 4, 5 };
    var it = AnalysisIterator(u32).init(&values);

    try testing.expect(it.hasNext());
    try testing.expectEqual(1, it.peek());
    try testing.expectEqual(1, it.next());
    try testing.expectEqual(2, it.peek());
    try testing.expectEqual(2, it.next());
    try testing.expect(it.hasNext());
    try testing.expectEqual(3, it.peek());
    try testing.expectEqual(3, it.next());
    try testing.expect(it.hasNext());
    try testing.expectEqual(4, it.peek());
    try testing.expectEqual(4, it.next());
    try testing.expect(it.hasNext());
    try testing.expectEqual(5, it.peek());
    try testing.expectEqual(5, it.next());
    try testing.expect(!it.hasNext());
}
