const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const Parser = @import("parser_analysis.zig").AnalysisParser;
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Errors = @import("analysis_error.zig").AnalysisErrors;

/// 三項演算子の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、三項演算子（条件 ? 真の値 : 偽の値）を解析し、結果の `Expression` を返します。
pub fn ternaryOperatorParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) !*Expression {
    const condition = try logicalParser(parser, iter, buffer);
    if (iter.peek()) |word| {
        if (word.kind == .Question) {
            _ = iter.next();

            // 三項演算子の左辺と右辺を解析
            const ture_expr = try logicalParser(parser, iter, buffer);
            if (iter.hasNext() and iter.peek().?.kind == .Colon) {
                _ = iter.next();
            } else {
                return error.InvalidExpression;
            }
            const false_expr = try logicalParser(parser, iter, buffer);

            // 三項演算子の式を生成
            const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
            expr.* = .{ .parser = parser, .data = .{ .TernaryExpress = .{ .condition = condition, .true_expr = ture_expr, .false_expr = false_expr } } };
            return expr;
        }
    }
    return condition;
}

/// 論理式の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、論理式を解析し、結果の `Expression` を返します。
fn logicalParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) !*Expression {
    var left = try comparisonParser(parser, iter, buffer);
    while (iter.peek()) |word| {
        if (word.kind == .AndOperator or word.kind == .OrOperator or word.kind == .XorOperator) {
            _ = iter.next();
            const right = try comparisonParser(parser, iter, buffer);
            const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
            expr.* = .{ .parser = parser, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
            left = expr;
        } else {
            break;
        }
    }
    return left;
}

/// 比較式の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、比較式を解析し、結果の `Expression` を返します。
fn comparisonParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    var left = try additionOrSubtractionParser(parser, iter, buffer);
    while (iter.peek()) |word| {
        if (word.kind == .GreaterEqual or word.kind == .LessEqual or word.kind == .GreaterThan or word.kind == .LessThan or word.kind == .Equal or word.kind == .NotEqual) {
            _ = iter.next();
            const right = try additionOrSubtractionParser(parser, iter, buffer);
            const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
            expr.* = .{ .parser = parser, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
            left = expr;
        } else {
            break;
        }
    }
    return left;
}

/// 加算または減算の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、加算または減算の式を解析し、結果の `Expression` を返します。
fn additionOrSubtractionParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    var left = try multiplyOrDevisionParser(parser, iter, buffer);
    while (iter.peek()) |word| {
        if (word.kind == .Plus or word.kind == .Minus) {
            _ = iter.next();
            const right = try multiplyOrDevisionParser(parser, iter, buffer);
            const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
            expr.* = .{ .parser = parser, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
            left = expr;
        } else {
            break;
        }
    }
    return left;
}

/// 乗算または除算の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、乗算または除算の式を解析し、結果の `Expression` を返します。
fn multiplyOrDevisionParser(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    var left = try parseFactor(parser, iter, buffer);
    while (iter.peek()) |word| {
        if (word.kind == .Multiply or word.kind == .Devision) {
            _ = iter.next();
            const right = try parseFactor(parser, iter, buffer);
            const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
            expr.* = .{ .parser = parser, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
            left = expr;
        } else {
            break;
        }
    }
    return left;
}

/// 単項式の解析を行います。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、単項式を解析し、結果の `Expression` を返します。
fn parseFactor(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    if (iter.peek()) |word| {
        switch (word.kind) {
            .LeftParen => {
                const expr = try parseParen(parser, iter, buffer);
                if (iter.hasNext() and iter.peek().?.kind == .RightParen) {
                    _ = iter.next();
                } else {
                    return error.InvalidExpression;
                }
                return expr;
            },
            .Number => {
                _ = iter.next();
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = .{ .parser = parser, .data = .{ .NumberExpress = try parseNumber(parser, word.str.raw()) } };
                return expr;
            },
            .StringLiteral => {
                _ = iter.next();
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = .{ .parser = parser, .data = .{ .StringExpress = try parseStringLiteral(parser, word.str.raw(), buffer) } };
                return expr;
            },
            .Plus, .Minus, .Not => {
                _ = iter.next();
                const nextExpr = try parseFactor(parser, iter, buffer);
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = .{ .parser = parser, .data = .{ .UnaryExpress = .{ .kind = word.kind, .expr = nextExpr } } };
                return expr;
            },
            .TrueLiteral => {
                _ = iter.next();
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = .{ .parser = parser, .data = .{ .BooleanExpress = true } };
                return expr;
            },
            .FalseLiteral => {
                _ = iter.next();
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = .{ .parser = parser, .data = .{ .BooleanExpress = false } };
                return expr;
            },
            .Identifier => {
                _ = iter.next();
                const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
                expr.* = (parser.variables.getExpr(&word.str) catch return Errors.IdentifierParseFailed).*;
                return expr;
            },
            else => {},
        }
    }
    return error.InvalidExpression;
}

/// 文字列を数値にします。
/// `parser` は自身のパーサーインスタンスで、`str` は数値の文字列スライスです。
/// この関数は、数値の単語を解析し、結果の数値を返します。
fn parseNumber(_: *Parser, str: []const u8) Errors!f64 {
    return std.fmt.parseFloat(f64, str) catch return Errors.OutOfMemoryNumber;
}

/// 文字列リテラルを解析します。
/// `parser` は自身のパーサーインスタンスで、`str` は文字列リテラルのスライスです。
fn parseStringLiteral(parser: *Parser, source: []const u8, buffer: *ArrayList(u8)) Errors!*String {
    buffer.clearRetainingCapacity();

    const quote = source[0];
    var src_ptr = source.ptr + 1; // クォートの次の文字から開始
    while (@intFromPtr(src_ptr) < @intFromPtr(source.ptr + source.len - 1)) {
        if (src_ptr[0] == quote) {
            // クォートが閉じられた場合、ループを終了
            src_ptr += 1;
            break;
        } else if (src_ptr[0] == '\\') {
            // エスケープシーケンスを処理
            src_ptr += 1;
            if (@intFromPtr(src_ptr) < @intFromPtr(source.ptr + source.len - 1)) {
                switch (src_ptr[0]) {
                    'n' => buffer.append('\n') catch return Errors.OutOfMemoryString,
                    't' => buffer.append('\t') catch return Errors.OutOfMemoryString,
                    '\\' => buffer.append('\\') catch return Errors.OutOfMemoryString,
                    '"' => buffer.append('"') catch return Errors.OutOfMemoryString,
                    '\'' => buffer.append('\'') catch return Errors.OutOfMemoryString,
                    else => {},
                }
                src_ptr += 1;
            } else {
                return Errors.EvaluationFailed;
            }
        } else {
            buffer.append(src_ptr[0]) catch return Errors.OutOfMemoryString;
            src_ptr += 1;
        }
    }
    return parser.string_store.get(.{ buffer.items, buffer.items.len }) catch return Errors.OutOfMemoryString;
}

/// 括弧で囲まれた式を解析します。
/// `parser` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
/// この関数は、左括弧が見つかった場合に括弧内の式を解析し、結果の `Expression` を返します。
/// もし左括弧が見つからなかった場合は、論理式の解析を行います。
fn parseParen(parser: *Parser, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    if (iter.peek()) |word| {
        if (word.kind == .LeftParen) {
            _ = iter.next();
            return try parenBlockParser(parser, .LeftParen, .RightParen, iter, buffer);
        } else {
            return try logicalParser(parser, iter, buffer);
        }
    }
    return error.InvalidExpression;
}

/// 括弧で囲まれたブロックを解析します。
/// `LParen` と `RParen` は、左括弧と右括弧の種類を指定します。
/// `next_parser` は、括弧内の式を解析するための次のパーサー関数です。
/// この関数は、括弧内の式を解析し、結果の `Expression` を返します。
fn parenBlockParser(parser: *Parser, comptime LParen: LexicalAnalysis.WordType, comptime RParen: LexicalAnalysis.WordType, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) Errors!*Expression {
    const start = iter.index;
    var end: usize = iter.index;
    var lv: u8 = 0;
    while (iter.hasNext()) {
        const word = iter.peek().?;
        switch (word.kind) {
            // 左括弧が見つかった場合、ネストレベルを増やす
            LParen => lv += 1,

            // 右括弧が見つかった場合、ネストレベルを減らす
            RParen => {
                if (lv > 0) {
                    lv -= 1;
                } else {
                    // ネストが終了でループも終了
                    break;
                }
            },
            else => {},
        }
        _ = iter.next();
        end = iter.index;
    }

    // 括弧内の式を解析
    const expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
    var in_iter = Iterator((LexicalAnalysis.Word)).init(iter.items[start..end]);
    expr.* = .{ .parser = parser, .data = .{ .ParenExpress = .{ .inner = try logicalParser(parser, &in_iter, buffer) } } };
    return expr;
}
