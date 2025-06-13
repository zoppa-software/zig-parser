const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Errors = @import("analysis_error.zig").AnalysisErrors;

/// ブロックの解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
/// この関数は、ブロックを解析し、結果の `Expression` を返します。
pub fn embeddedTextParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.EmbeddedText), buffer: *ArrayList(u8)) Errors!*Expression {
    // ブロックの解析を行います
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    while (iter.hasNext()) {
        const block = iter.peek().?;

        switch (block.kind) {
            .None => {
                exprs.append(try parseTextBlock(parser, block, buffer)) catch return error.OutOfMemoryExpression;
                _ = iter.next();
            },
            .Unfold => {
                exprs.append(try parseUnfoldBlock(parser, block, buffer)) catch return error.OutOfMemoryExpression;
                _ = iter.next();
            },
            .NoEscapeUnfold => {
                exprs.append(try parseNoEscapeUnfoldBlock(parser, block, buffer)) catch return error.OutOfMemoryExpression;
                _ = iter.next();
            },
            .IfBlock => {
                const expr = try parseIfBlock(parser, iter, buffer);
                if (iter.hasNext() and iter.peek().?.kind == .EndIfBlock) {
                    exprs.append(expr) catch return error.OutOfMemoryExpression;
                    _ = iter.next();
                } else {
                    return error.InvalidExpression;
                }
            },
            else => {},
        }
    }

    // 解析した式をリストとして返します
    const list_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    const list_exprs = exprs.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
    list_expr.* = .{ .parser = parser, .data = .{ .ListExpress = .{ .exprs = list_exprs } } };
    return list_expr;
}

/// テキストブロックを解析します。
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseTextBlock(parser: *Parser, block: LexicalAnalysis.EmbeddedText, buffer: *ArrayList(u8)) !*Expression {
    const text_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    text_expr.* = .{ .parser = parser, .data = .{ .StringExpress = try unescapeBracket(parser, block.str.raw(), buffer, 0, 0) } };
    return text_expr;
}

/// 展開ブロックを解析します。
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseUnfoldBlock(parser: *Parser, block: LexicalAnalysis.EmbeddedText, buffer: *ArrayList(u8)) !*Expression {
    const unfold_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    unfold_expr.* = .{ .parser = parser, .data = .{ .UnfoldExpress = try unescapeBracket(parser, block.str.raw(), buffer, 2, 1) } };
    return unfold_expr;
}

/// 展開ブロックを解析します（非エスケープ）
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseNoEscapeUnfoldBlock(parser: *Parser, block: LexicalAnalysis.EmbeddedText, buffer: *ArrayList(u8)) !*Expression {
    const no_unfold_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    no_unfold_expr.* = .{ .parser = parser, .data = .{ .NoEscapeUnfoldExpress = try unescapeBracket(parser, block.str.raw(), buffer, 2, 1) } };
    return no_unfold_expr;
}

/// 入力文字列からエスケープされた波括弧を取り除きます。
/// `parser` は自身のパーサーインスタンスで、`source` は入力の文字列スライスです。
fn unescapeBracket(parser: *Parser, source: []const u8, buffer: *ArrayList(u8), startSkip: comptime_int, lastSkip: comptime_int) Errors!*String {
    buffer.clearRetainingCapacity();

    var src_ptr = source.ptr + startSkip;
    while (@intFromPtr(src_ptr) < @intFromPtr(source.ptr + source.len - lastSkip)) {
        if (src_ptr[0] == '\\' and @intFromPtr(src_ptr + 1) < @intFromPtr(source.ptr + source.len - lastSkip) and (src_ptr[1] == '{' or src_ptr[1] == '}')) {
            // エスケープされた波括弧を処理
            buffer.append(src_ptr[1]) catch return Errors.OutOfMemoryString;
            src_ptr += 2;
        } else {
            buffer.append(src_ptr[0]) catch return Errors.OutOfMemoryString;
            src_ptr += 1;
        }
    }
    return parser.string_store.get(.{ buffer.items, buffer.items.len }) catch return error.OutOfMemoryString;
}

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
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return Errors.OutOfMemoryExpression;
                    prev_condition = blk;
                    prev_type = .ElseIfBlock;
                    update = true;
                }
            },

            // elseブロックを評価
            .ElseBlock => {
                if (lv == 0) {
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return Errors.OutOfMemoryExpression;
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
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return Errors.OutOfMemoryExpression;
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

    // if 式を解析
    const if_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    const if_exprs = exprs.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
    if_expr.* = .{ .parser = parser, .data = .{ .IfExpress = .{ .exprs = if_exprs } } };
    return if_expr;
}

fn parseIfExpression(parser: *Parser, iter: *Iterator(LexicalAnalysis.EmbeddedText), prev_condition: LexicalAnalysis.EmbeddedText, prev_type: LexicalAnalysis.EmbeddedType, start: usize, end: usize, buffer: *ArrayList(u8)) Errors!*Expression {
    const tmp_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    var in_iter = Iterator(LexicalAnalysis.EmbeddedText).init(iter.items[start..end]);

    switch (prev_type) {
        .IfBlock, .ElseIfBlock => {
            const tmp_str = parser.string_store.get(.{ prev_condition.str.raw(), prev_condition.str.raw().len }) catch return Errors.OutOfMemoryString;
            tmp_expr.* = .{ .parser = parser, .data = .{ .IfConditionExpress = .{ .condition = tmp_str, .inner = try embeddedTextParser(parser, &in_iter, buffer) } } };
        },
        .ElseBlock => {
            tmp_expr.* = .{ .parser = parser, .data = .{ .ElseExpress = .{ .inner = try embeddedTextParser(parser, &in_iter, buffer) } } };
        },
        else => return error.InvalidExpression,
    }
    return tmp_expr;
}
