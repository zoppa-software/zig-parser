const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const AnalysisIterator = @import("parser_analysis_iterator.zig");
const Parser = @import("parser_analysis.zig").Parser;
const Expression = @import("parser_analysis_expression.zig").AnalysisExpression;

const AllErrors = LexicalAnalysis.LexicalError || ParserAnalysis.ParserError;

/// ブロックの解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
/// この関数は、ブロックを解析し、結果の `Expression` を返します。
pub fn blocksParser(parser: *Parser, iter: *AnalysisIterator.Iterator(LexicalAnalysis.Block), buffer: *ArrayList(u8)) AllErrors!*Expression {
    // ブロックの解析を行います
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    while (iter.hasNext()) {
        const block = iter.peek().?;

        switch (block.kind) {
            .Text => {
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
    const list_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    const list_exprs = exprs.toOwnedSlice() catch return AllErrors.OutOfMemoryExpression;
    list_expr.* = .{ .parser = parser, .data = .{ .ListExpress = .{ .exprs = list_exprs } } };
    return list_expr;
}

/// テキストブロックを解析します。
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseTextBlock(parser: *Parser, block: LexicalAnalysis.Block, buffer: *ArrayList(u8)) !*Expression {
    const text_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    text_expr.* = .{ .parser = parser, .data = .{ .StringExpress = try unescapeBracket(parser, block.str.raw(), buffer, 0, 0) } };
    return text_expr;
}

/// 展開ブロックを解析します。
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseUnfoldBlock(parser: *Parser, block: LexicalAnalysis.Block, buffer: *ArrayList(u8)) !*Expression {
    const unfold_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    unfold_expr.* = .{ .parser = parser, .data = .{ .UnfoldExpress = try unescapeBracket(parser, block.str.raw(), buffer, 2, 1) } };
    return unfold_expr;
}

/// 展開ブロックを解析します（非エスケープ）
/// `parser` は自身のパーサーインスタンスで、`block` はブロックのデータです。
fn parseNoEscapeUnfoldBlock(parser: *Parser, block: LexicalAnalysis.Block, buffer: *ArrayList(u8)) !*Expression {
    const no_unfold_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    no_unfold_expr.* = .{ .parser = parser, .data = .{ .NoEscapeUnfoldExpress = try unescapeBracket(parser, block.str.raw(), buffer, 2, 1) } };
    return no_unfold_expr;
}

/// 入力文字列からエスケープされた波括弧を取り除きます。
/// `parser` は自身のパーサーインスタンスで、`source` は入力の文字列スライスです。
fn unescapeBracket(parser: *Parser, source: []const u8, buffer: *ArrayList(u8), startSkip: comptime_int, lastSkip: comptime_int) AllErrors!*String {
    buffer.clearRetainingCapacity();

    var src_ptr = source.ptr + startSkip;
    while (@intFromPtr(src_ptr) < @intFromPtr(source.ptr + source.len - lastSkip)) {
        if (src_ptr[0] == '\\' and @intFromPtr(src_ptr + 1) < @intFromPtr(source.ptr + source.len - lastSkip) and (src_ptr[1] == '{' or src_ptr[1] == '}')) {
            // エスケープされた波括弧を処理
            buffer.append(src_ptr[1]) catch return AllErrors.OutOfMemoryString;
            src_ptr += 2;
        } else {
            buffer.append(src_ptr[0]) catch return AllErrors.OutOfMemoryString;
            src_ptr += 1;
        }
    }
    return parser.string_store.get(.{ buffer.items, buffer.items.len }) catch return error.OutOfMemoryString;
}

fn parseIfBlock(parser: *Parser, iter: *AnalysisIterator.Iterator(LexicalAnalysis.Block), buffer: *ArrayList(u8)) AllErrors!*Expression {
    // 式バッファを生成します
    var exprs = ArrayList(*Expression).init(parser.allocator);
    defer exprs.deinit();

    var prev_condition = iter.peek().?;
    var prev_type = LexicalAnalysis.BlockType.IfBlock;
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
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return AllErrors.OutOfMemoryExpression;
                    prev_condition = blk;
                    prev_type = .ElseIfBlock;
                    update = true;
                }
            },

            // elseブロックを評価
            .ElseBlock => {
                if (lv == 0) {
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return AllErrors.OutOfMemoryExpression;
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
                    exprs.append(try parseIfExpression(parser, iter, prev_condition, prev_type, start, end, buffer)) catch return AllErrors.OutOfMemoryExpression;
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
    const if_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    const if_exprs = exprs.toOwnedSlice() catch return AllErrors.OutOfMemoryExpression;
    if_expr.* = .{ .parser = parser, .data = .{ .IfExpress = .{ .exprs = if_exprs } } };
    return if_expr;
}

fn parseIfExpression(parser: *Parser, iter: *AnalysisIterator.Iterator(LexicalAnalysis.Block), prev_condition: LexicalAnalysis.Block, prev_type: LexicalAnalysis.BlockType, start: usize, end: usize, buffer: *ArrayList(u8)) AllErrors!*Expression {
    const tmp_expr = parser.expr_store.get({}) catch return AllErrors.OutOfMemoryExpression;
    var in_iter = AnalysisIterator.Iterator(LexicalAnalysis.Block).init(iter.items[start..end], 0);

    switch (prev_type) {
        .IfBlock, .ElseIfBlock => {
            const tmp_str = parser.string_store.get(.{ prev_condition.str.raw(), prev_condition.str.raw().len }) catch return AllErrors.OutOfMemoryString;
            tmp_expr.* = .{ .parser = parser, .data = .{ .IfConditionExpress = .{ .condition = tmp_str, .inner = try blocksParser(parser, &in_iter, buffer) } } };
        },
        .ElseBlock => {
            tmp_expr.* = .{ .parser = parser, .data = .{ .ElseExpress = .{ .inner = try blocksParser(parser, &in_iter, buffer) } } };
        },
        else => return error.InvalidExpression,
    }
    return tmp_expr;
}
