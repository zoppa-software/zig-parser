///! parse_execute.zig
///! 基礎的な式解析を行うためのモジュールです。
///! このモジュールは、三項演算子、論理演算子、比較演算子、加算・減算、乗算・除算などの式を解析します。
///! また、括弧内の式や配列の要素も解析します。
///! 解析結果は `Expression` として返されます。
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const Lexical = @import("lexical_analysis.zig");
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const ParserError = @import("analysis_error.zig").ParserError;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;

/// 三項演算子の式を解析します。
/// この関数は、三項演算子の式を解析し、結果を `Expression` として返します。
/// 三項演算子の式は、条件式、真の場合の式、偽の場合の式を持ちます。
/// 例えば、`condition ? true_expr : false_expr` の形式です。
pub fn ternaryOperatorParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    const condition = try logicalParser(allocator, store, iter);
    if (iter.peek()) |word| {
        if (word.kind == .Question) {
            _ = iter.next();

            // 三項演算子の左辺と右辺を解析
            const true_expr = try logicalParser(allocator, store, iter);
            if (iter.hasNext() and iter.peek().?.kind == .Colon) {
                _ = iter.next();
            } else {
                return ParserError.TernaryOperatorParseFailed;
            }
            const false_expr = try logicalParser(allocator, store, iter);

            // 三項演算子の式を生成
            const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
            expr.* = .{ .TernaryExpress = .{ .condition = condition, .true_expr = true_expr, .false_expr = false_expr } };
            return expr;
        }
    }
    return condition;
}

/// 論理演算子の式を解析します。
/// この関数は、論理演算子の式を解析し、結果を `Expression` として返します。
/// 論理演算子の式は、左辺と右辺の式を持ち、演算子として `and`、`or`、`xor` などを使用します。
fn logicalParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    // 左辺を解析します
    var left = try comparisonParser(allocator, store, iter);

    // 論理演算子が見つかった場合、右辺を解析します
    while (iter.peek()) |word| {
        if (word.kind == .AndOperator or word.kind == .OrOperator or word.kind == .XorOperator) {
            _ = iter.next();

            // 右辺を解析します
            const right = try comparisonParser(allocator, store, iter);
            left = blk: {
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } };
                break :blk expr;
            };
        } else {
            break;
        }
    }
    return left;
}

/// 比較演算子の式を解析します。
/// この関数は、比較演算子の式を解析し、結果を `Expression` として返します。
/// 比較演算子の式は、左辺と右辺の式を持ち、演算子として `GreaterThan`、`LessThan`、`Equal`、`NotEqual` などを使用します。
fn comparisonParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    // 左辺を解析します
    var left = try additionOrSubtractionParser(allocator, store, iter);

    // 比較演算子が見つかった場合、右辺を解析します
    while (iter.peek()) |word| {
        switch (word.kind) {
            .GreaterEqual, .LessEqual, .GreaterThan, .LessThan, .Equal, .NotEqual => {
                _ = iter.next();

                // 右辺を解析します
                const right = try additionOrSubtractionParser(allocator, store, iter);
                left = blk: {
                    const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } };
                    break :blk expr;
                };
            },
            else => break,
        }
    }
    return left;
}

/// 加算または減算の式を解析します。
/// この関数は、加算または減算の式を解析し、結果を `Expression` として返します。
/// 加算または減算の式は、左辺と右辺の式を持ち、演算子として `Plus` または `Minus` を使用します。
fn additionOrSubtractionParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    // 左辺を解析します
    var left = try multiplyOrDivisionParser(allocator, store, iter);

    // 加算または減算の演算子が見つかった場合、右辺を解析します
    while (iter.peek()) |word| {
        if (word.kind == .Plus or word.kind == .Minus) {
            _ = iter.next();

            // 右辺を解析します
            const right = try multiplyOrDivisionParser(allocator, store, iter);
            left = blk: {
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } };
                break :blk expr;
            };
        } else {
            break;
        }
    }
    return left;
}

/// 乗算または除算の式を解析します。
/// この関数は、乗算または除算の式を解析し、結果を `Expression` として返します。
/// 乗算または除算の式は、左辺と右辺の式を持ち、演算子として `Multiply` または `Divide` を使用します。
fn multiplyOrDivisionParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    // 左辺を解析します
    var left = try parseFactor(allocator, store, iter);

    // 乗算または除算の演算子が見つかった場合、右辺を解析します
    while (iter.peek()) |word| {
        if (word.kind == .Multiply or word.kind == .Divide) {
            _ = iter.next();

            // 右辺を解析します
            const right = try parseFactor(allocator, store, iter);
            left = blk: {
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } };
                break :blk expr;
            };
        } else {
            break;
        }
    }
    return left;
}

/// 要素の式を解析します。
/// この関数は、要素の式を解析し、結果を `Expression` として返します。
/// 要素の式は、数値、文字列リテラル、単項演算子、真偽値リテラル、識別子、括弧内の式などを含みます。
fn parseFactor(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    if (iter.peek()) |word| {
        switch (word.kind) {
            .Number => {
                // 数値の式
                _ = iter.next();
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .NumberExpress = std.fmt.parseFloat(f64, word.str.raw()) catch return ParserError.NumberParseFailed };
                return expr;
            },
            .StringLiteral => {
                // 文字列リテラルの式
                _ = iter.next();
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .StringExpress = word.str };
                return expr;
            },
            .Plus, .Minus, .Not => {
                // 単項演算子の式
                _ = iter.next();
                const nextExpr = try parseFactor(allocator, store, iter);
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .UnaryExpress = .{ .kind = word.kind, .expr = nextExpr } };
                return expr;
            },
            .TrueLiteral => {
                // 真リテラルの式
                _ = iter.next();
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .BooleanExpress = true };
                return expr;
            },
            .FalseLiteral => {
                // 偽リテラルの式
                _ = iter.next();
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .BooleanExpress = false };
                return expr;
            },
            .Identifier => {
                // 識別子の式
                _ = iter.next();
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .IdentifierExpress = word.str };

                if (iter.peek()) |next_word| {
                    if (next_word.kind == .LeftParen) {
                        // 関数呼び出しの式
                        //const expr = try parseParen(allocator, store, iter);
                        //return expr;
                    } else if (next_word.kind == .LeftBracket) {
                        // 配列の要素アクセスの式
                        const arrac = store.get({}) catch return ParserError.OutOfMemoryExpression;
                        const index = try parseBracket(allocator, store, iter);
                        arrac.* = .{ .ArrayExpress = .{ .ident = expr, .index = index } };
                        return arrac;
                    }
                }
                return expr;
            },
            .LeftParen => {
                // ()括弧内の式
                const expr = try parseParen(allocator, store, iter);
                if (iter.hasNext() and iter.peek().?.kind == .RightParen) {
                    _ = iter.next();
                } else {
                    return ParserError.InvalidExpression;
                }
                return expr;
            },
            .LeftBracket => {
                // []括弧内の式
                const expr = try parseArrayVariable(allocator, store, iter);
                if (iter.hasNext() and iter.peek().?.kind == .RightBracket) {
                    _ = iter.next();
                } else {
                    return ParserError.InvalidExpression;
                }
                return expr;
            },
            else => {},
        }
    }
    return ParserError.InvalidExpression;
}

/// ()括弧内の式を解析します。
/// この関数は、()括弧内の式を解析し、結果を `Expression` として返します。
/// ()括弧内の式は、他の式をグループ化するために使用されます。
fn parseParen(allocator: Allocator, store: *ExpressionStore, iter: *Iterator(Lexical.Word)) ParserError!*Expression {
    _ = iter.next();
    // ()括弧内の式を走査するためのイテレーターを作成
    const range = parenBlockParser(.LeftParen, .RightParen, iter);
    var in_iter = Iterator((Lexical.Word)).init(iter.items[range.start..range.end]);

    // カッコ内の式を解析する
    const in_expr = try ternaryOperatorParser(allocator, store, &in_iter);

    // 式を返します
    const paren_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    paren_expr.* = .{ .ParenExpress = in_expr };
    return paren_expr;
}

/// []括弧内の式を解析します。
/// この関数は、[]括弧内の式を解析し、結果を `Expression` として返します。
/// []括弧内の式は、他の式をグループ化するために使用されます。
fn parseBracket(allocator: Allocator, store: *ExpressionStore, iter: *Iterator(Lexical.Word)) ParserError!*Expression {
    _ = iter.next();
    // ()括弧内の式を走査するためのイテレーターを作成
    const range = parenBlockParser(.LeftBracket, .RightBracket, iter);
    var in_iter = Iterator((Lexical.Word)).init(iter.items[range.start..range.end]);

    // カッコ内の式を解析する
    const in_expr = try ternaryOperatorParser(allocator, store, &in_iter);

    // 式を返します
    const paren_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    paren_expr.* = .{ .ParenExpress = in_expr };
    return paren_expr;
}

/// []括弧内の式を解析し、変数値として保持します。
/// この関数は、[]括弧内の式を解析し、結果を `Expression` として返します。
/// []括弧内の式は、配列の要素を表現します。
fn parseArrayVariable(allocator: Allocator, store: *ExpressionStore, iter: *Iterator(Lexical.Word)) ParserError!*Expression {
    _ = iter.next();

    // []括弧内の式を走査するためのイテレーターを作成
    const range = parenBlockParser(.LeftBracket, .RightBracket, iter);
    var in_iter = Iterator((Lexical.Word)).init(iter.items[range.start..range.end]);

    // 式を格納するためのArrayListを作成
    var exprs = ArrayList(*Expression).init(allocator);
    defer exprs.deinit();

    while (in_iter.hasNext()) {
        // 配列内の要素を取得
        const in_expr = try ternaryOperatorParser(allocator, store, &in_iter);
        exprs.append(in_expr) catch return ParserError.OutOfMemoryExpression;

        // カンマまたは右括弧を判定して配列を評価
        if (in_iter.hasNext()) {
            switch (in_iter.peek().?.kind) {
                .Comma => {
                    // カンマをスキップ
                    _ = in_iter.next();
                },
                .RightBracket => {
                    // 右括弧が見つかった場合、ループを終了
                    break;
                },
                else => {
                    // 無効な式
                    return ParserError.InvalidExpression;
                },
            }
        }
    }

    // []括弧内の式を作成
    const array_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    const array_exprs = exprs.toOwnedSlice() catch return ParserError.OutOfMemoryExpression;
    array_expr.* = .{ .ArrayVariableExpress = array_exprs };
    return array_expr;
}

/// 括弧の対応をネストレベルでカウントして判定し、カッコ内の文字列を習得します。
/// この関数は、指定された括弧のネストレベルをカウントし、対応する括弧の範囲を返します。
/// `LParen` と `RParen` は、左括弧と右括弧の種類を指定します。
/// `iter` は、解析する単語のイテレーターです。
fn parenBlockParser(
    comptime LParen: Lexical.WordType,
    comptime RParen: Lexical.WordType,
    iter: *Iterator(Lexical.Word),
) struct { start: usize, end: usize } {
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
    return .{ .start = start, .end = end };
}

/// 変数の式を解析します。
/// この関数は、変数の名前と値を解析し、結果を `Expression` として返します。
/// 変数の式は、変数の名前と値を持ち、代入記号 `=` を使用して値を設定します。
pub fn variableParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.Word),
) ParserError!*Expression {
    // 変数の名前を取得
    var name: String = undefined;
    if (iter.peek()) |word| {
        if (word.kind == .Identifier) {
            name = word.str;
        } else {
            return ParserError.InvalidVariableName;
        }
    }
    _ = iter.next();

    // 変数の代入記号 '=' があるか確認
    if (iter.peek()) |word| {
        if (word.kind != .Assign) return ParserError.VariableAssignmentMissing;
    }
    _ = iter.next();

    // 変数の値を解析
    const value = ternaryOperatorParser(allocator, store, iter) catch return ParserError.VariableValueMissing;

    // 変数の式を作成
    const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    expr.* = .{ .VariableExpress = .{ .name = name, .value = value } };
    return expr;
}
