const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// 単語、ブロックのイテレータ。
pub fn Iterator(comptime T: type) type {
    return struct {
        /// 単語のリスト
        items: []T,
        index: usize,

        pub fn init(items: []T, index: usize) @This() {
            return .{ .items = items, .index = index };
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
