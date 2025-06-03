const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Char = @import("char.zig").Char;

/// 文字列型。
/// アロケートされた文字列とスライスされた文字列の2つの形式を持ちます。
/// 文字列はUTF-8エンコードされた文字列で使用されることを意図しています。
pub const String = union(enum) {
    /// エラー列挙型
    pub const Error = error{
        /// メモリ不足エラー。
        OutOfMemory,
    };

    /// 文字列の順序を表す列挙型。
    /// `less` は左側の文字列が右側の文字列より小さいこと。
    /// `equal` は両方の文字列が等しいこと。
    /// `greater` は左側の文字列が右側の文字列より大きいこと。
    pub const Order = enum(i8) {
        less = -1,
        equal = 0,
        greater = 1,
    };

    /// 空の文字列を表す定数。
    pub const empty = String{
        .slice = .{
            .size = 0,
            .start = 0,
            .value = &[_]u8{},
        },
    };

    /// アロケートされた文字列を表す。
    allocated: struct { allocator: Allocator, size: usize, value: [:0]const u8 },

    /// スライスされた文字列を表す。
    slice: struct { size: usize, start: usize, value: []const u8 },

    /// 新しい文字列をアロケートされた形式で作成します。
    /// `source` はUTF-8エンコードされた文字列でなければなりません。
    pub fn newString(allocator: Allocator, source: []const u8) !String {
        if (source.len > 0) {
            // アロケーターを使用して新しい文字列を作成します。
            const buf = allocator.alloc(u8, source.len + 1) catch {
                return Error.OutOfMemory;
            };

            // ソース文字列をバッファにコピーします。
            // 最後にヌル文字を追加します。
            std.mem.copyForwards(u8, buf[0..source.len], source);
            buf[source.len] = 0;

            // アロケートされた文字列を返します。
            return String{
                .allocated = .{
                    .allocator = allocator,
                    .size = countLen(buf[0..source.len]),
                    .value = buf[0..source.len :0],
                },
            };
        } else {
            return empty;
        }
    }

    /// 新しい文字列をスライスされた形式で作成します。
    /// `source` はUTF-8エンコードされた文字列でなければなりません。
    /// `first` はスライスの開始位置で、`length` はスライスの長さです。
    pub fn newSlice(source: []const u8, first: usize, length: usize) String {
        const charpos = range(source, first, first + length);
        return String{
            .slice = .{
                .start = charpos[0],
                .size = charpos[2],
                .value = source[charpos[0]..charpos[1]],
            },
        };
    }

    /// 新しい文字列をスライスされた形式で作成します。
    /// `source` はUTF-8エンコードされた文字列でなければなりません。
    pub fn newAllSlice(source: []const u8) String {
        return String{
            .slice = .{
                .size = countLen(source),
                .start = 0,
                .value = source,
            },
        };
    }

    /// 文字列を解放します。
    pub fn deinit(self: *const String) void {
        switch (self.*) {
            .allocated => |allocated| {
                allocated.allocator.free(allocated.value);
            },
            .slice => {},
        }
    }

    /// 文字列を連結します。
    /// `other` は別の文字列でなければなりません。
    /// 連結後の文字列はアロケーターを使用して新しい文字列を作成します。
    pub fn concat(self: *const String, allocator: Allocator, other: *const String) !String {
        return self.concatLiteral(allocator, other.raw());
    }

    /// 文字列を連結します。
    /// `other` はUTF-8エンコードされた文字列でなければなりません。
    pub fn concatLiteral(self: *const String, allocator: Allocator, other: []const u8) !String {
        // 文字列の長さを取得します。
        const total_len = self.byteLen() + other.len;

        // 連結後の文字列を格納するためのバッファをアロケーターから確保します。
        const buf = allocator.alloc(u8, total_len + 1) catch {
            return Error.OutOfMemory;
        };

        // バッファに文字列をコピーします。
        std.mem.copyForwards(u8, buf[0..self.byteLen()], self.raw());
        std.mem.copyForwards(u8, buf[self.byteLen()..total_len], other);
        buf[total_len] = 0;

        // アロケートされた文字列を返します。
        return String{
            .allocated = .{
                .allocator = allocator,
                .size = countLen(buf[0..total_len]),
                .value = buf[0..total_len :0],
            },
        };
    }

    /// 文字列の一部を取得します。
    /// `source` はUTF-8エンコードされた文字列でなければなりません。
    /// `first` はスライスの開始位置で、`length` はスライスの長さです。
    pub fn mid(source: *const String, first: usize, length: usize) String {
        // 開始位置が文字列の長さを超えている場合は空の文字列を返す。
        if (first >= source.len()) {
            return empty;
        }

        // スライスの開始位置と長さを計算します。
        const data = source.raw();
        const charpos = range(data, first, first + length);
        return String{
            .slice = .{
                .start = charpos[0],
                .size = charpos[2],
                .value = data[charpos[0]..charpos[1]],
            },
        };
    }

    /// 文字列の一部を取得します。
    /// `data` はUTF-8エンコードされた文字列でなければなりません。
    /// `first` はスライスの開始位置で、`end` はスライスの終了位置です。
    /// `first` と `end` は文字のインデックスで、0から始まります。
    fn range(data: []const u8, first: usize, end: usize) [3]usize {
        // 開始、終了位置を保持。戻り値は文字(バイトでない)の [first, end, length] の形式。
        const idxs = [_]usize{ first, end };
        var res: [3]usize = [_]usize{ data.len, data.len, 0 };

        var pos: u32 = 0;
        var i: u32 = 0;
        var j: u32 = 0;
        while (i < data.len) {
            // 現在のバイトのUTF-8シーケンスの長さを取得します。
            const ln = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;

            // 現在の位置が開始位置または終了位置に一致するか確認します。
            if (pos == idxs[j]) {
                // 開始位置または終了位置に一致した場合、結果に追加します。
                res[j] = i;
                j += 1;
                if (j >= 2) {
                    break;
                }
            } else {
                pos += 1;
                i += ln;
            }
        }
        // 結果の文字の長さを計算します。
        res[2] = @min(pos, end) - first;
        return res;
    }

    /// 文字列のバイト配列を取得します。
    pub fn raw(self: *const String) []const u8 {
        return switch (self.*) {
            .allocated => |allocated| allocated.value,
            .slice => |slice| slice.value,
        };
    }

    /// 文字列の長さを取得します。
    pub fn byteLen(self: *const String) usize {
        return switch (self.*) {
            .allocated => |allocated| allocated.value.len,
            .slice => |slice| slice.value.len,
        };
    }

    /// 文字列の開始位置で取得します。
    pub fn start(self: *const String) usize {
        return switch (self.*) {
            .allocated => |_| 0,
            .slice => |slice| slice.start,
        };
    }

    /// 文字列の長さを文字数で取得します。
    pub fn len(self: *const String) usize {
        return switch (self.*) {
            .allocated => |allocated| allocated.size,
            .slice => |slice| slice.size,
        };
    }

    /// 文字列の長さを文字数で取得します。
    fn countLen(data: []const u8) usize {
        var pos: u32 = 0;
        var i: u32 = 0;
        while (i < data.len) : (i += std.unicode.utf8ByteSequenceLength(data[i]) catch 1) {
            pos += 1;
        }
        return pos;
    }

    /// 文字列の特定のインデックスにある文字を取得します。
    /// `index` は文字のインデックスで、0から始まります。
    pub fn at(self: *const String, index: usize) ?Char {
        const data = self.raw();

        var pos: u32 = 0;
        var i: u32 = 0;
        while (i < self.byteLen()) {
            const ln = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;
            if (pos == index) {
                return Char.init(data[i .. i + ln]);
            }
            pos += 1;
            i += ln;
        }
        return null;
    }

    /// 文字列をSentinel文字列として取得します。
    /// Sentinel文字列は、アロケーターを使用して新しい文字列を作成します。
    pub fn getSentinelString(self: *const String, allocator: Allocator) !String {
        return switch (self.*) {
            .allocated => |allocated| newString(allocator, allocated.value),
            .slice => |slice| newString(allocator, slice.value),
        };
    }

    /// 文字列が空かどうかを確認します。
    pub fn isEmpty(self: *const String) bool {
        return self.len() == 0;
    }

    /// 文字列を比較します。
    /// `other` は比較対象の文字列でなければなりません。
    pub fn compare(self: *const String, other: *const String) Order {
        // 文字列の長さを比較します。
        const self_len = self.len();
        const other_len = other.len();
        const min_len = @min(self_len, other_len);

        // 文字列のバイト配列を比較します。
        var self_slice: [*]const u8 = self.raw().ptr;
        var other_slice: [*]const u8 = other.raw().ptr;
        for (0..min_len) |_| {
            const sl = std.unicode.utf8ByteSequenceLength(self_slice[0]) catch 1;
            const ol = std.unicode.utf8ByteSequenceLength(other_slice[0]) catch 1;

            const sval = charValue(self_slice, sl);
            const oval = charValue(other_slice, ol);
            if (sval != oval) {
                return if (sval < oval) Order.less else Order.greater;
            }

            self_slice += sl;
            other_slice += ol;
        }

        // 文字列の長さを比較します。
        // 長さが異なる場合は、長い方が大きいと判断します。
        if (self_len != other_len) {
            return if (self_len < other_len) Order.less else Order.greater;
        }
        return Order.equal;
    }

    /// 文字列が他の文字列と等しいかどうかを確認します。
    pub fn eql(self: *const String, other: *const String) bool {
        // 文字列の長さを比較します。
        if (self.len() != other.len()) return false;

        // 文字列のバイト配列を比較します。
        const self_slice = self.raw();
        const other_slice = other.raw();
        return std.mem.eql(u8, self_slice, other_slice);
    }

    /// 文字列が他のUTF-8エンコードされた文字列と等しいかどうかを確認します。
    pub fn eqlLiteral(self: *const String, other: []const u8) bool {
        // 文字列のバイト配列を比較します。
        const self_slice = self.raw();

        // 文字列の長さを比較します。
        if (self_slice.len != other.len) return false;

        return std.mem.eql(u8, self_slice, other);
    }

    /// 文字列の特定のインデックスにある文字の値を取得します。
    fn charValue(arrptr: [*]const u8, clen: u3) u48 {
        if (clen == 1) return arrptr[0];
        var res: u48 = 0;
        for (0..clen) |i| {
            res = (res << 8) + arrptr[i];
        }
        return res;
    }

    /// 文字列のイテレータを返します。
    /// イテレータは文字列の各文字を順に返します。
    /// イテレータは文字列のバイト配列を使用して、UTF-8エンコードされた文字を取得します。
    pub fn iterate(self: *const String) Iterator {
        return Iterator{
            .str = self.raw(),
            .current_index = 0,
        };
    }

    /// 文字列のイテレータ。
    pub const Iterator = struct {
        str: []const u8,
        current_index: usize,

        /// 次の要素が存在するかどうかを確認します。
        pub fn hasNext(self: *Iterator) bool {
            return self.current_index < self.str.len;
        }

        /// 次の要素を取得します。
        pub fn next(self: *Iterator) ?Char {
            if (self.current_index < self.str.len) {
                const ln = std.unicode.utf8ByteSequenceLength(self.str[self.current_index]) catch 1;
                const char = Char.init(self.str[self.current_index .. self.current_index + ln]);
                self.current_index += ln;
                return char;
            } else {
                return null;
            }
        }

        /// 次の要素を取得します。参照位置を変更しません。
        pub fn peek(self: *const Iterator) ?Char {
            if (self.current_index < self.str.len) {
                const ln = std.unicode.utf8ByteSequenceLength(self.str[self.current_index]) catch 1;
                return Char.init(self.str[self.current_index .. self.current_index + ln]);
            } else {
                return null;
            }
        }

        /// 次の要素を取得します。参照位置を変更しません。
        pub fn skip(self: *const Iterator, count: usize) ?Char {
            var idx = self.current_index;
            var i: usize = 0;
            var ln: usize = 1;
            while (i < count and idx < self.str.len) {
                ln = std.unicode.utf8ByteSequenceLength(self.str[idx]) catch 1;
                idx += ln;
                i += 1;
            }
            return if (idx < self.str.len) Char.init(self.str[idx .. idx + ln]) else null;
        }
    };
};
