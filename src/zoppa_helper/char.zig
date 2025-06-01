const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// 文字型。
/// 文字は最大6バイトのUTF-8エンコードされた文字を格納できます。
pub const Char: type = struct {

    // 文字のUTF-8エンコードされたバイト列。
    source: [6]u8 = [_]u8{ 0, 0, 0, 0, 0, 0 },

    // バイトの長さ。
    len: u8 = 0,

    /// 文字列をUTF-8エンコードされた文字列として取得します。
    pub fn init(data: []const u8) Char {
        var char = Char{
            .len = @intCast(data.len),
        };
        std.mem.copyForwards(u8, &char.source, data[0..@min(data.len, 6)]);
        return char;
    }

    /// 文字をUTF-8エンコードされた配列として取得します。
    pub fn value(self: *const Char) []const u8 {
        return self.source[0..self.len];
    }

    /// 文字が空白文字かどうかを判定します。
    /// 空白文字は、半角スペース、全角スペース、改行、タブを含みます。
    pub fn isWhiteSpace(self: *const Char) bool {
        if (self.len == 1) {
            return self.source[0] == ' ' or self.source[0] == '\n' or self.source[0] == '\t';
        } else if (self.len == 3 and self.source[0] == 0xe3 and self.source[1] == 0x80 and self.source[2] == 0x80) {
            // 全角スペース（UTF-8: 0xe3 0x80 0x80）
            return true;
        } else {
            // 複数バイトの文字は空白ではない
            return false;
        }
    }
};

test "isWhiteSpace test" {
    const char6 = Char.init("　"); // 全角スペース
    try testing.expectEqual(true, char6.isWhiteSpace());

    const char1 = Char.init(" ");
    try testing.expectEqual(true, char1.isWhiteSpace());

    const char2 = Char.init("\n");
    try testing.expectEqual(true, char2.isWhiteSpace());

    const char3 = Char.init("\t");
    try testing.expectEqual(true, char3.isWhiteSpace());

    const char4 = Char.init("a");
    try testing.expectEqual(false, char4.isWhiteSpace());

    const char5 = Char.init("あ");
    try testing.expectEqual(false, char5.isWhiteSpace());
}
