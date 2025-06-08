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
    /// ブロック解析エラー
    BlockAnalysisError,
    /// アンダーバーの連続エラー
    ConsecutiveUnderscoreError,
    /// 文字列リテラルが閉じられていない場合はエラー
    UnclosedStringLiteralError,
    /// ブロックが閉じられていない場合はエラー
    UnclosedBlockError,
    /// 無効なコマンドの場合はエラー
    InvalidCommandError,
};

/// 単語の種類を表す列挙型。
/// 各単語は、識別子、数字、演算子、句読点、キーワードなどの種類を持ちます。
pub const WordType = enum {
    Identifier, // 識別子
    Number, // 数字
    Period, // ピリオド
    Assign, // 代入
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
    TrueLiteral, // 真
    FalseLiteral, // 偽
    AndOperator, // 論理積
    OrOperator, // 論理和
    XorOperator, // 排他的論理和
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

    const split_char = createSplitChar();

    var iter = input.iterate();
    while (iter.hasNext()) {
        const pc = iter.peek();
        if (pc) |c| {
            if (c.isWhiteSpace() or c.len > 1) {
                _ = iter.next();
            } else {
                const word = switchOneCharToWord(&split_char, input, &iter, c) catch {
                    return LexicalError.WordAnalysisError;
                };
                try tokens.append(word);
            }
        }
    }

    return tokens.toOwnedSlice();
}

/// 分割文字を定義します。
/// 文字列をトークンに分割する際に使用される文字のリストです。
fn createSplitChar() [256]bool {
    var split_char: [256]bool = [1]bool{false} ** 256;
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

    return split_char;
}

/// 1文字のトークンを解析して、Word構造体に変換します。
/// 文字の種類に応じて、適切なWordTypeを設定します。
/// 文字が演算子や記号の場合は、対応するWordTypeを設定します。
/// 文字が数字の場合は、数字のトークンを作成します。
/// 文字が文字列リテラルの場合は、文字列リテラルのトークンを作成します。
fn switchOneCharToWord(split_char: *const [256]bool, input: *const String, iter: *String.Iterator, c: Char) !Word {
    return switch (c.source[0]) {
        '\\' => .{ .str = getOneCharString(input, iter), .kind = WordType.Backslash },
        '.' => .{ .str = getOneCharString(input, iter), .kind = WordType.Period },
        '=' => getEqualWord(input, iter),
        '<' => getLessWord(input, iter),
        '>' => getGreaterWord(input, iter),
        '+' => .{ .str = getOneCharString(input, iter), .kind = WordType.Plus },
        '-' => .{ .str = getOneCharString(input, iter), .kind = WordType.Minus },
        '*' => .{ .str = getOneCharString(input, iter), .kind = WordType.Multiply },
        '/' => .{ .str = getOneCharString(input, iter), .kind = WordType.Devision },
        '(' => .{ .str = getOneCharString(input, iter), .kind = WordType.LeftParen },
        ')' => .{ .str = getOneCharString(input, iter), .kind = WordType.RightParen },
        '[' => .{ .str = getOneCharString(input, iter), .kind = WordType.LeftBracket },
        ']' => .{ .str = getOneCharString(input, iter), .kind = WordType.RightBracket },
        '!' => .{ .str = getOneCharString(input, iter), .kind = WordType.Not },
        ',' => .{ .str = getOneCharString(input, iter), .kind = WordType.Comma },
        '#' => .{ .str = getOneCharString(input, iter), .kind = WordType.Hash },
        '?' => .{ .str = getOneCharString(input, iter), .kind = WordType.Question },
        ':' => .{ .str = getOneCharString(input, iter), .kind = WordType.Colon },
        '"' => .{ .str = try getStringLiteral('"', input, iter), .kind = WordType.StringLiteral },
        '\'' => .{ .str = try getStringLiteral('\'', input, iter), .kind = WordType.StringLiteral },
        '0'...'9' =>
        // 数字のトークンを作成
        .{ .str = try getNumberToken(input, iter), .kind = WordType.Number },
        else =>
        // その他の文字はキーワードまたは識別子とみなす
        getWordString(split_char, input, iter),
    };
}

/// 1文字の文字列を取得します。
/// 文字列のイテレータから1文字のスライスを作成します。
fn getOneCharString(input: *const String, iter: *String.Iterator) String {
    const res = String.fromBytes(input.raw(), iter.current_index, 1);
    _ = iter.next(); // イテレータを1つ進める
    return res;
}

/// 等価演算子を取得します。
fn getEqualWord(input: *const String, iter: *String.Iterator) Word {
    if (iter.skip(1)) |lc| {
        if (lc.len == 1) {
            if (lc.source[0] == '=') {
                // == 演算子
                const res = Word{ .str = String.fromBytes(input.raw(), iter.current_index, 2), .kind = WordType.Equal };
                _ = iter.next();
                _ = iter.next();
                return res;
            }
        }
    }
    // 単なる = 演算子
    return .{ .str = getOneCharString(input, iter), .kind = WordType.Assign };
}

/// 小なり演算子を取得します。
fn getLessWord(input: *const String, iter: *String.Iterator) Word {
    if (iter.skip(1)) |lc| {
        if (lc.len == 1) {
            switch (lc.source[0]) {
                '=' => {
                    // <= 演算子
                    const res = Word{ .str = String.fromBytes(input.raw(), iter.current_index, 2), .kind = WordType.LessEqual };
                    _ = iter.next();
                    _ = iter.next();
                    return res;
                },
                '>' => {
                    // <> 演算子
                    const res = Word{ .str = String.fromBytes(input.raw(), iter.current_index, 2), .kind = WordType.NotEqual };
                    _ = iter.next();
                    _ = iter.next();
                    return res;
                },
                else => {},
            }
        }
    }
    // 単なる < 演算子
    return .{ .str = getOneCharString(input, iter), .kind = WordType.LessThan };
}

/// 大なり演算子を取得します。
fn getGreaterWord(input: *const String, iter: *String.Iterator) Word {
    if (iter.skip(1)) |lc| {
        if (lc.len == 1) {
            if (lc.source[0] == '=') {
                // >= 演算子
                const res = Word{ .str = String.fromBytes(input.raw(), iter.current_index, 2), .kind = WordType.GreaterEqual };
                _ = iter.next();
                _ = iter.next();
                return res;
            }
        }
    }
    // 単なる < 演算子
    return .{ .str = getOneCharString(input, iter), .kind = WordType.GreaterThan };
}

/// 文字列から単語を取得します。
/// イテレータを使用して、空白文字または分割文字が見つかるまで文字を読み取り、
/// その文字列をWord構造体に変換します。
/// 分割文字は、空白文字や特定の記号（例: +, -, *, /, = など）です。
fn getWordString(split_char: *const [256]bool, input: *const String, iter: *String.Iterator) Word {
    const start = iter.current_index;
    while (iter.hasNext()) {
        const pc = iter.peek();
        if (pc) |c| {
            if (c.isWhiteSpace() or c.len > 1 or split_char[c.source[0]]) {
                // 空白文字または分割文字が見つかったら終了
                break;
            }
            _ = iter.next();
        } else {
            // イテレータの終端に到達した場合も終了
            break;
        }
    }

    const keyword = String.fromBytes(input.raw(), start, iter.current_index - start);
    if (isKeyword(&keyword, "true")) { // 真
        return .{ .str = keyword, .kind = WordType.TrueLiteral };
    } else if (isKeyword(&keyword, "false")) { // 偽
        return .{ .str = keyword, .kind = WordType.FalseLiteral };
    } else if (isKeyword(&keyword, "and")) { // 論理積演算子
        return .{ .str = keyword, .kind = WordType.AndOperator };
    } else if (isKeyword(&keyword, "or")) { // 論理和演算子
        return .{ .str = keyword, .kind = WordType.OrOperator };
    } else if (isKeyword(&keyword, "xor")) { // 排他的論理和
        return .{ .str = keyword, .kind = WordType.XorOperator };
    } else {
        // その他のキーワードは識別子として扱う
        return .{ .str = keyword, .kind = WordType.Identifier };
    }
}

/// キーワードかどうかを判定します。
/// 文字列の最初の文字がキーワードの最初の文字と一致する場合にのみ、比較を行います。
inline fn isKeyword(input: *const String, wordchar: []const u8) bool {
    return input.raw()[0] == wordchar[0] and input.eqlLiteral(wordchar);
}

/// キーワードを取得します。
/// キーワードは、識別子の一種であり、特定の意味を持つ単語です。
inline fn getKeyword(input: *const String, wordType: WordType) Word {
    return .{
        .str = input.*,
        .kind = wordType,
    };
}

/// 文字列リテラルを取得します。
/// 文字列リテラルは、引用符　' または " で囲まれた文字列です。
fn getStringLiteral(comptime quote: comptime_int, input: *const String, iter: *String.Iterator) !String {
    const start = iter.current_index;
    _ = iter.next();
    var closed = false;

    while (iter.hasNext()) {
        const pc = iter.next();
        if (pc) |c| {
            if (c.len == 1 and c.source[0] == '\\' and
                iter.peek() != null and iter.peek().?.len == 1 and
                (iter.peek().?.source[0] == quote or iter.peek().?.source[0] == 't' or iter.peek().?.source[0] == 'n'))
            {
                _ = iter.next();
            } else if (c.len == 1 and c.source[0] == quote and
                iter.hasNext() and iter.peek().?.len == 1 and iter.peek().?.source[0] == quote)
            {
                _ = iter.next();
            } else if (c.len == 1 and c.source[0] == quote) {
                // 文字列リテラルが閉じられた
                closed = true;
                break;
            }
        }
    }

    if (!closed) {
        // 文字列リテラルが閉じられていない場合はエラー
        return LexicalError.UnclosedStringLiteralError;
    }
    return String.fromBytes(input.raw(), start, iter.current_index - start);
}

/// 数字のトークンを取得します。
/// 数字は整数または小数点を含むことができます。
/// 符号（+/-）も許可されます。
/// 例: "123", "-456.78", "+3.14" など。
fn getNumberToken(input: *const String, iter: *String.Iterator) !String {
    const start = iter.current_index;
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
    return String.fromBytes(input.raw(), start, iter.current_index - start);
}

/// ブロックの種類を表す列挙型。
/// ブロックは、識別子やキーワードなどの特定の種類の文字列を表します。
pub const BlockType = enum {
    Text, // テキスト部
    Unfold, // 展開部
    NoEscapeUnfold, // エスケープなし展開部
    IfBlock, // ifブロック
    ElseIfBlock, // else ifブロック
    ElseBlock, // elseブロック
    EndIfBlock, // endifブロック
};

/// ブロックを表す構造体。
/// ブロックは、文字列とその種類を持ちます。
pub const Block = struct {
    str: String,
    kind: BlockType,
};

/// 文字列をブロックに分割します。
/// 入力文字列を解析して、ブロックのリストを生成します。
pub fn splitBlocks(input: *const String, allocator: Allocator) ![]Block {
    var tokens = ArrayList(Block).init(allocator);
    defer tokens.deinit();

    var iter = input.iterate();
    while (iter.hasNext()) {
        const pc = iter.peek();
        if (pc) |c| {
            const word = switch (c.source[0]) {
                '{' => try getCommandBlock(input, &iter),
                '#' => try getUnfoldBlock(input, &iter, BlockType.Unfold),
                '!' => try getUnfoldBlock(input, &iter, BlockType.NoEscapeUnfold),
                else => Block{ .str = getTextBlock(input, &iter), .kind = BlockType.Text },
            };
            try tokens.append(word);
        }
    }
    return tokens.toOwnedSlice();
}

/// コマンドブロックを取得します。
/// コマンドブロックは、{ で始まり、} で終わる文字列です。
fn getCommandBlock(input: *const String, iter: *String.Iterator) !Block {
    const cmd = try getCommandBlockString(input, iter, false);
    if (cmd.startWithLiteral("{if") and cmd.at(3).?.isWhiteSpace()) {
        return .{ .str = cmd.mid(4, cmd.len() - 5), .kind = BlockType.IfBlock };
    } else if (cmd.startWithLiteral("{else if") and cmd.at(8).?.isWhiteSpace()) {
        return .{ .str = cmd.mid(9, cmd.len() - 10), .kind = BlockType.ElseIfBlock };
    } else if (cmd.startWithLiteral("{elseif") and cmd.at(7).?.isWhiteSpace()) {
        return .{ .str = cmd.mid(8, cmd.len() - 9), .kind = BlockType.ElseIfBlock };
    } else if (cmd.eqlLiteral("{else}")) {
        return .{ .str = cmd, .kind = BlockType.ElseBlock };
    } else if (cmd.eqlLiteral("{/if}")) {
        return .{ .str = cmd, .kind = BlockType.EndIfBlock };
    } else {
        return error.InvalidCommandError;
    }
}

/// 展開ブロックを取得します。
/// 展開ブロックは、# または ! で始まり、{ で終わる文字列です。
fn getUnfoldBlock(input: *const String, iter: *String.Iterator, blkType: BlockType) !Block {
    if (iter.skip(1)) |lc| {
        if (lc.len == 1) {
            if (lc.source[0] != '{') {
                return .{ .str = getTextBlock(input, iter), .kind = BlockType.Text };
            }
        }
        return .{ .str = try getCommandBlockString(input, iter, true), .kind = blkType };
    } else {
        return .{ .str = getTextBlock(input, iter), .kind = BlockType.Text };
    }
}

/// コマンドブロック内の文字列を取得します。
/// コマンドブロックは、{ で始まり、} で終わる文字列です。
fn getCommandBlockString(input: *const String, iter: *String.Iterator, isSkip: bool) !String {
    const start = iter.current_index;
    if (isSkip) {
        _ = iter.next();
    }
    _ = iter.next();
    var closed = false;

    // ブロックの終わりを探す
    while (iter.hasNext()) {
        const c = iter.next().?;
        if (c.len == 1) {
            switch (c.source[0]) {
                '}' => {
                    // } が見つかった場合、ループを終了
                    closed = true;
                    break;
                },

                // エスケープ文字が見つかった場合は次の文字を無視
                '\\' => {
                    const nc = iter.peek();
                    if (nc) |next_c| {
                        if (next_c.len == 1 and (next_c.source[0] == '{' or next_c.source[0] == '}')) {
                            // エスケープされた { または } を無視
                            _ = iter.next();
                        }
                    }
                },
                else => {},
            }
        }
    }

    if (!closed) {
        // ブロックが閉じられていない場合はエラー
        return LexicalError.UnclosedBlockError;
    }
    return String.fromBytes(input.raw(), start, iter.current_index - start);
}

/// テキストブロック内のテキストを取得します。
/// テキストブロックは、{ や #, ! などのコマンドが見つかるまでの文字列です。
fn getTextBlock(input: *const String, iter: *String.Iterator) String {
    const start = iter.current_index;

    while (iter.hasNext()) {
        const c = iter.peek().?;
        if (c.len == 1) {
            switch (c.source[0]) {
                // { が見つかったらテキスト部の終了
                '{' => {
                    break;
                },

                // # または ! が見つかったらテキスト部の終了
                '#', '!' => {
                    const nc = iter.skip(1);
                    if (nc) |next_c| {
                        if (next_c.len == 1 and next_c.source[0] == '{') {
                            break;
                        }
                    }
                },

                // エスケープ文字が見つかった場合は次の文字を無視
                '\\' => {
                    const nc = iter.skip(1);
                    if (nc) |next_c| {
                        if (next_c.len == 1 and (next_c.source[0] == '{' or next_c.source[0] == '}' or next_c.source[0] == '#' or next_c.source[0] == '!')) {
                            // エスケープされた { または } を無視
                            _ = iter.next();
                        }
                    }
                },
                else => {},
            }
        }
        _ = iter.next();
    }
    return String.fromBytes(input.raw(), start, iter.current_index - start);
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
