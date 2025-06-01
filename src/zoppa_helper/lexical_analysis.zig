const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const Char = @import("char.zig").Char;
const ArrayList = std.ArrayList;

/// エラー列挙型
pub const LexicalError = error{
    /// 単語解析エラー
    WordAnalysisError,
    /// アンダーバーの連続エラー
    ConsecutiveUnderscoreError,
    /// 文字列リテラルが閉じられていない場合はエラー
    UnclosedStringLiteralError,
};

/// 単語の種類を表す列挙型。
/// 各単語は、識別子、数字、演算子、句読点、キーワードなどの種類を持ちます。
pub const WordType = enum {
    Identifier, // 識別子
    Number, // 数字
    Period, // ピリオド
    Equal, // イコール
    LessThan, // 小なり
    GreaterThan, // 大なり
    LessEqual, // 小なりイコール
    GreaterEqual, // 大なりイコール
    NotEqual, // 等しくない
    Plus, // プラス
    Minus, // マイナス
    Multiply, // アスタリスク
    Devision, // スラッシュ
    LeftParen, // 左括弧
    RightParen, // 右括弧
    LeftBracket, // 左ブラケット
    RightBracket, // 右ブラケット
    Not, // 否定
    Comma, // コンマ
    Hash, // ハッシュ
    Question, // クエスチョン
    Colon, // コロン
    Backslash, // バックスラッシュ
    StringLiteral, // 文字列リテラル
};

/// 単語を表す構造体。
/// 単語は文字列とその種類を持ちます。
pub const Word = struct {
    str: String,
    kind: WordType,
};

/// 文字列をトークンに分割します。
/// 入力文字列を解析して、単語のリストを生成します。
/// 各単語はWord構造体で表され、文字列とその種類を持ちます。
pub fn splitWords(input: *const String, allocator: Allocator) ![]Word {
    var tokens = ArrayList(Word).init(allocator);
    defer tokens.deinit();

    var iter = input.iterate();
    while (iter.hasNext()) {
        const pc = iter.peek();
        if (pc) |c| {
            if (c.isWhiteSpace() or c.len > 1) {
                _ = iter.next();
            } else {
                const word = switchOneCharToWord(input, &iter, c) catch {
                    return LexicalError.WordAnalysisError;
                };
                try tokens.append(word);
            }
        }
    }

    return tokens.toOwnedSlice();
}

var split_char: [256]bool = [1]bool{false} ** 256;

/// 1文字のトークンを解析して、Word構造体に変換します。
/// 文字の種類に応じて、適切なWordTypeを設定します。
/// 文字が演算子や記号の場合は、対応するWordTypeを設定します。
/// 文字が数字の場合は、数字のトークンを作成します。
/// 文字が文字列リテラルの場合は、文字列リテラルのトークンを作成します。
fn switchOneCharToWord(input: *const String, iter: *String.Iterator, c: Char) !Word {
    split_char[' '] = true;
    split_char['\t'] = true;
    split_char['\n'] = true;
    split_char['\r'] = true;
    split_char[0] = true;
    split_char['+'] = true;
    split_char['-'] = true;
    split_char['*'] = true;
    split_char['/'] = true;
    split_char['='] = true;
    split_char['<'] = true;
    split_char['>'] = true;
    split_char['('] = true;
    split_char[')'] = true;
    split_char['['] = true;
    split_char[']'] = true;
    split_char['!'] = true;
    split_char[','] = true;
    split_char['#'] = true;
    split_char['?'] = true;
    split_char[':'] = true;
    split_char['\\'] = true;
    split_char['.'] = true;
    split_char['\''] = true;
    split_char['"'] = true;

    var res: Word = undefined;
    switch (c.source[0]) {
        '\\' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Backslash };
            _ = iter.next();
        },
        '.' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Period };
            _ = iter.next();
        },
        '=' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Equal };
            _ = iter.next();
        },
        '<' => {
            var twoword = false;
            if (iter.skip(1)) |lc| {
                if (lc.len == 1) {
                    switch (c.source[0]) {
                        '=' => {
                            // <= 演算子
                            res = .{ .str = String.newSlice(input.raw(), iter.index, 2), .kind = WordType.LessEqual };
                            twoword = true;
                        },
                        '>' => {
                            // <> 演算子
                            res = .{ .str = String.newSlice(input.raw(), iter.index, 2), .kind = WordType.NotEqual };
                            twoword = true;
                        },
                        else => {},
                    }
                }
            }
            if (twoword) {
                _ = iter.next();
            } else {
                // 単なる < 演算子
                res = .{ .str = getOneCharString(input, iter), .kind = WordType.LessThan };
            }
            _ = iter.next();
        },
        '>' => {
            var twoword = false;
            if (iter.skip(1)) |lc| {
                if (lc.len == 1) {
                    switch (c.source[0]) {
                        '=' => {
                            // >= 演算子
                            res = .{ .str = String.newSlice(input.raw(), iter.index, 2), .kind = WordType.GreaterEqual };
                            twoword = true;
                        },
                        else => {},
                    }
                }
            }
            if (twoword) {
                _ = iter.next();
            } else {
                // 単なる < 演算子
                res = .{ .str = getOneCharString(input, iter), .kind = WordType.GreaterThan };
            }
            _ = iter.next();
        },
        '+' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Plus };
            _ = iter.next();
        },
        '-' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Minus };
            _ = iter.next();
        },
        '*' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Multiply };
            _ = iter.next();
        },
        '/' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Devision };
            _ = iter.next();
        },
        '(' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.LeftParen };
            _ = iter.next();
        },
        ')' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.RightParen };
            _ = iter.next();
        },
        '[' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.LeftBracket };
            _ = iter.next();
        },
        ']' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.RightBracket };
            _ = iter.next();
        },
        '!' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Not };
            _ = iter.next();
        },
        ',' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Comma };
            _ = iter.next();
        },
        '#' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Hash };
            _ = iter.next();
        },
        '?' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Question };
            _ = iter.next();
        },
        ':' => {
            res = .{ .str = getOneCharString(input, iter), .kind = WordType.Colon };
            _ = iter.next();
        },
        '"' => {
            res = .{ .str = try getStringLiteral('"', input, iter), .kind = WordType.StringLiteral };
        },
        '\'' => {
            res = .{ .str = try getStringLiteral('\'', input, iter), .kind = WordType.StringLiteral };
        },
        '0'...'9' => {
            // 数字のトークンを作成
            res = .{ .str = try getNumberToken(input, iter), .kind = WordType.Number };
        },
        else => {
            // その他の文字はキーワードまたは識別子とみなす
            res = getWordString(input, iter);
        },
    }
    return res;
}

/// 1文字の文字列を取得します。
/// 文字列のイテレータから1文字のスライスを作成します。
fn getOneCharString(input: *const String, iter: *String.Iterator) String {
    return String.newSlice(input.raw(), iter.index, 1);
}

fn getWordString(input: *const String, iter: *String.Iterator) Word {
    const start = iter.index;
    while (iter.hasNext()) {
        const pc = iter.next();
        if (pc) |c| {
            if (c.isWhiteSpace() or c.len > 1 or split_char[c.source[0]]) {
                // 空白文字または分割文字が見つかったら終了
                break;
            }
        } else {
            // イテレータの終端に到達した場合も終了
            break;
        }
    }
    return .{
        .str = String.newSlice(input.raw(), start, iter.index - start),
        .kind = WordType.Identifier,
    };
}

/// 文字列リテラルを取得します。
/// 文字列リテラルは、引用符　' または " で囲まれた文字列です。
fn getStringLiteral(comptime quote: comptime_int, input: *const String, iter: *String.Iterator) !String {
    const start = iter.index;
    _ = iter.next();
    var closed = false;

    while (iter.hasNext()) {
        const pc = iter.next();
        if (pc) |c| {
            if (c.len == 1 and c.source[0] == '\\' and
                iter.peek() != null and iter.peek().?.len == 1 and iter.peek().?.source[0] == quote)
            {
                _ = iter.next();
            } else if (c.len == 1 and c.source[0] == quote and
                iter.hasNext() and iter.peek().?.len == 1 and (iter.peek().?.source[0] == quote or iter.peek().?.source[0] == 't' or iter.peek().?.source[0] == 'n'))
            {
                _ = iter.next();
            } else if (c.len == 1 and c.source[0] == quote) {
                // 文字列リテラルが閉じられた
                closed = true;
                _ = iter.next();
                break;
            }
        }
    }

    if (!closed) {
        // 文字列リテラルが閉じられていない場合はエラー
        return LexicalError.UnclosedStringLiteralError;
    }
    return String.newSlice(input.raw(), start, iter.index - start);
}

/// 数字のトークンを取得します。
/// 数字は整数または小数点を含むことができます。
/// 符号（+/-）も許可されます。
/// 例: "123", "-456.78", "+3.14" など。
fn getNumberToken(input: *const String, iter: *String.Iterator) !String {
    const start = iter.index;
    var dec = false;
    var num = false;

    const sign = iter.peek();
    if (sign) |c| {
        if (c.len == 1 and (c.source[0] == '+' or c.source[0] == '-')) {
            // 符号を許可
            _ = iter.next();
        }
    }

    while (iter.hasNext()) {
        const pc = iter.peek();
        if (pc) |c| {
            if (c.len == 1 and (c.source[0] >= '0' and c.source[0] <= '9')) {
                // 数字のトークンを作成
                num = true;
                _ = iter.next();
            } else if (c.len == 1 and c.source[0] == '.') {
                // 小数点を許可
                if (!dec) {
                    dec = true;
                    _ = iter.next();
                } else {
                    break; // 2つ目の小数点は無視
                }
            } else if (c.len == 1 and c.source[0] == '_') {
                if (num) {
                    // アンダースコアは数字の一部として扱う
                    num = false;
                    _ = iter.next();
                } else {
                    // アンダースコアが連続している場合はエラー
                    return LexicalError.ConsecutiveUnderscoreError;
                }
            } else {
                break; // 数字以外の文字は終了
            }
        }
    }
    return String.newSlice(input.raw(), start, iter.index - start);
}

test "getStringLiteral test" {
    const input1 = String.newAllSlice("\"Hello, World!\"");
    var iter1 = input1.iterate();
    var token1 = try getStringLiteral('"', &input1, &iter1);
    try std.testing.expectEqualSlices(u8, "\"Hello, World!\"", token1.raw());

    const input2 = String.newAllSlice("'This is a test.'");
    var iter2 = input2.iterate();
    var token2 = try getStringLiteral('\'', &input2, &iter2);
    try std.testing.expectEqualSlices(u8, "'This is a test.'", token2.raw());

    const input3 = String.newAllSlice("\"Another test with \\\"escaped quotes\\\".\"");
    var iter3 = input3.iterate();
    var token3 = try getStringLiteral('\"', &input3, &iter3);
    try std.testing.expectEqualSlices(u8, "\"Another test with \\\"escaped quotes\\\".\"", token3.raw());

    const input4 = String.newAllSlice("'Unclosed string literal");
    var iter4 = input4.iterate();
    if (getStringLiteral('\'', &input4, &iter4)) |_| {
        unreachable; // ここに到達してはならない
    } else |err| {
        try std.testing.expectEqual(LexicalError.UnclosedStringLiteralError, err);
    }
}

test "getNumberToken test" {
    const input = String.newAllSlice("123 -456.78 +3.14 123_456_789 4..2 4__5");
    defer input.deinit();

    var iter = input.iterate();

    var token = try getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "123", token.raw());
    _ = iter.next();

    token = try getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "-456.78", token.raw());
    _ = iter.next();

    token = try getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "+3.14", token.raw());
    _ = iter.next();

    token = try getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "123_456_789", token.raw());
    _ = iter.next();

    token = try getNumberToken(&input, &iter);
    try std.testing.expectEqualSlices(u8, "4.", token.raw());
    _ = iter.next();
    _ = iter.next();
    _ = iter.next();

    if (getNumberToken(&input, &iter)) |_| {
        unreachable;
    } else |err| {
        try std.testing.expectEqual(LexicalError.ConsecutiveUnderscoreError, err);
    }
}
