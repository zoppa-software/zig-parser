const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Char = @import("strings/char.zig").Char;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Executes = @import("parser_analysis_execute.zig");
const Errors = @import("analysis_error.zig").AnalysisErrors;
const isEmbeddedTextEscapeChar = @import("lexical_analysis.zig").isEmbeddedTextEscapeChar;
const isNoneEmbeddedTextEscapeChar = @import("lexical_analysis.zig").isNoneEmbeddedTextEscapeChar;

/// 埋め込み式の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
/// この関数は、ブロックを解析し、結果の `Expression` を返します。
pub fn embeddedTextParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.EmbeddedText), buffer: *ArrayList(u8)) Errors!*Expression {
    // バッファを作成します
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    // 埋め込み式の解析を行います
    while (iter.hasNext()) {
        const embedded = iter.peek().?;

        switch (embedded.kind) {
            .None => {
                // 埋め込み式以外は文字列として扱います
                const text = try unescapeBracket(parser, &embedded.str, buffer, 0, 0, isNoneEmbeddedTextEscapeChar);
                exprs.append(try Expression.initStringExpression(parser, text)) catch return Errors.OutOfMemoryExpression;
                _ = iter.next();
            },
            .Unfold => {
                // 展開埋め込み式を解析します
                const text = try unescapeBracket(parser, &embedded.str, buffer, 2, 1, isEmbeddedTextEscapeChar);
                exprs.append(try Expression.initUnfoldExpression(parser, text)) catch return Errors.OutOfMemoryExpression;
                _ = iter.next();
            },
            .NoEscapeUnfold => {
                // 非エスケープ展開埋め込み式を解析します
                const text = try unescapeBracket(parser, &embedded.str, buffer, 2, 1, isEmbeddedTextEscapeChar);
                exprs.append(try Expression.initNoEscapeUnfoldExpression(parser, text)) catch return Errors.OutOfMemoryExpression;
                _ = iter.next();
            },
            .Variables => {
                // 変数埋め込み式を解析します
                exprs.append(try parseVariablesBlock(parser, embedded, buffer)) catch return Errors.OutOfMemoryExpression;
                _ = iter.next();
            },
            .IfBlock => {
                // Ifブロックを解析、最後の埋め込み式が EndIfBlock であることを確認します
                const expr = try parseIfBlock(parser, iter, buffer);
                if (iter.hasNext() and iter.peek().?.kind == .EndIfBlock) {
                    exprs.append(expr) catch return Errors.OutOfMemoryExpression;
                    _ = iter.next();
                } else {
                    return Errors.InvalidExpression;
                }
            },
            else => {
                // サポートされていない埋め込み式の場合はエラーを返す
                return Errors.UnsupportedEmbeddedExpression;
            },
        }
    }
    return Expression.initListExpression(parser, &exprs);
}

/// 入力文字列から波括弧をエスケープ解除します。
/// `parser` は自身のパーサーインスタンスで、`source` は入力文字列です。
fn unescapeBracket(
    parser: *Parser,
    source: *const String,
    buffer: *ArrayList(u8),
    start_skip: comptime_int,
    last_skip: comptime_int,
    is_esc_chk: fn (Char) bool,
) Errors!*String {
    const is_esc = blk: {
        var iter = source.iterate();
        var i: usize = 0;
        while (iter.hasNext() and i < source.len() - last_skip) {
            if (iter.next()) |c| {
                if (i >= start_skip) {
                    if (c.len == 1 and c.source[0] == '\\') {
                        if (iter.hasNext() and is_esc_chk(iter.peek().?)) {
                            break :blk true;
                        }
                    }
                }
            }
            i += 1;
        }
        break :blk false;
    };

    if (is_esc) {
        // エスケープされている場合は、エスケープされた波括弧を取り除く
        buffer.clearRetainingCapacity();

        var iter = source.iterate();
        var i: usize = 0;
        while (iter.hasNext() and i < source.len() - last_skip) {
            if (iter.next()) |c| {
                if (i >= start_skip) {
                    // エスケープ文字かどうかをチェック
                    const esc = blk: {
                        if (c.len == 1 and c.source[0] == '\\') {
                            if (iter.hasNext() and is_esc_chk(iter.peek().?)) {
                                break :blk true;
                            }
                        }
                        break :blk false;
                    };

                    // エスケープの有無を確認して文字を追加
                    // エスケープされている場合は次の文字を追加
                    if (esc) {
                        const nc = iter.next().?;
                        buffer.appendSlice(nc.source[0..nc.len]) catch return Errors.OutOfMemoryString;
                        i += 1;
                    } else {
                        buffer.appendSlice(c.source[0..c.len]) catch return Errors.OutOfMemoryString;
                    }
                }
            }
            i += 1;
        }

        return parser.string_store.get(.{ buffer.items, buffer.items.len }) catch return Errors.OutOfMemoryString;
    } else {
        // エスケープされていない場合はそのまま文字列を返す
        const res = parser.string_store.get(.{ [0]u8, 0 }) catch return Errors.OutOfMemoryString;
        res.* = source.mid(start_skip, source.len() - (start_skip + last_skip));
        return res;
    }
}

/// 変数埋め込み式を解析します。
/// `parser` は自身のパーサーインスタンスで、`embedded` は埋め込み式のデータです。
fn parseVariablesBlock(parser: *Parser, embedded: LexicalAnalysis.EmbeddedText, buffer: *ArrayList(u8)) Errors!*Expression {
    // 式バッファを生成します
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    // 埋め込まれた文字列を取得します
    const inner_text = try unescapeBracket(
        parser,
        &embedded.str,
        buffer,
        2,
        1,
        isEmbeddedTextEscapeChar,
    );

    // 入力文字列を単語に分割します
    const words = LexicalAnalysis.splitWords(inner_text, parser.allocator) catch return Errors.OutOfMemoryString;
    defer parser.allocator.free(words);

    // 変数式を解析します
    var iter = Iterator(LexicalAnalysis.Word).init(words);
    while (iter.hasNext()) {
        const expr = try Executes.variableParser(parser, &iter, buffer);
        exprs.append(expr) catch return Errors.OutOfMemoryExpression;
        if (iter.peek()) |word| {
            if (word.kind != .Semicolon) return Errors.VariableNotSemicolonSeparated;
            _ = iter.next(); // セミコロンをスキップ
        }
    }
    if (iter.hasNext()) {
        return Errors.VariableNotSemicolonSeparated;
    }

    // 変数式をリストとして返します
    return Expression.initVariableListExpression(parser, &exprs);
}

/// If埋め込み式を解析します。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
fn parseIfBlock(parser: *Parser, iter: *Iterator(LexicalAnalysis.EmbeddedText), buffer: *ArrayList(u8)) Errors!*Expression {
    // 式バッファを生成します
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    var prev_condition = iter.peek().?;
    var prev_type = LexicalAnalysis.EmbeddedType.IfBlock;
    _ = iter.next();

    var start: usize = iter.index;
    var end: usize = iter.index;
    var lv: u8 = 0;
    var update = false;
    while (iter.hasNext()) {
        const blk = iter.peek().?;
        switch (blk.kind) {
            // if が開始された場合、ネストレベルを増やす
            .IfBlock => lv += 1,

            // else if ブロックを評価
            .ElseIfBlock => {
                if (lv == 0) {
                    exprs.append(try parseIfExpression(
                        parser,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                        buffer,
                    )) catch return Errors.OutOfMemoryExpression;
                    prev_condition = blk;
                    prev_type = .ElseIfBlock;
                    update = true;
                }
            },

            // elseブロックを評価
            .ElseBlock => {
                if (lv == 0) {
                    exprs.append(try parseIfExpression(
                        parser,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                        buffer,
                    )) catch return Errors.OutOfMemoryExpression;
                    prev_condition = blk;
                    prev_type = .ElseBlock;
                    update = true;
                }
            },

            // Ifが終了された場合、ネストレベルを減らす
            .EndIfBlock => {
                if (lv > 0) {
                    lv -= 1;
                } else {
                    // ネストが終了でループも終了
                    exprs.append(try parseIfExpression(
                        parser,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                        buffer,
                    )) catch return Errors.OutOfMemoryExpression;
                    break;
                }
            },
            else => {},
        }
        _ = iter.next();
        if (update) {
            start = iter.index;
            update = false;
        }
        end = iter.index;
    }
    return Expression.initIfExpression(parser, &exprs);
}

/// If埋め込み式の各式を取得します。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
fn parseIfExpression(
    parser: *Parser,
    iter: *Iterator(LexicalAnalysis.EmbeddedText),
    prev_condition: LexicalAnalysis.EmbeddedText,
    prev_type: LexicalAnalysis.EmbeddedType,
    start: usize,
    end: usize,
    buffer: *ArrayList(u8),
) Errors!*Expression {
    var in_iter = Iterator(LexicalAnalysis.EmbeddedText).init(iter.items[start..end]);
    switch (prev_type) {
        .IfBlock, .ElseIfBlock => {
            const tmp_str = parser.string_store.get(.{ [0]u8{}, 0 }) catch return Errors.OutOfMemoryString;
            tmp_str.* = prev_condition.str;
            return Expression.initIfConditionExpression(parser, tmp_str, try embeddedTextParser(parser, &in_iter, buffer));
        },
        .ElseBlock => {
            return Expression.initElseExpression(parser, try embeddedTextParser(parser, &in_iter, buffer));
        },
        else => return Errors.ConditionParseFailed,
    }
}
