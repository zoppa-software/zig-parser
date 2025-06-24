///! parse_embedded.zig
///! 埋め込み式の解析を行うモジュール
///! このモジュールは、埋め込み式を含む文字列を解析し、`Expression` を返します。
///! 埋め込み式は、変数、条件分岐、展開などを含むことができます。
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const Lexical = @import("lexical_analysis.zig");
const Parser = @import("parser_analysis.zig");
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const ParserError = @import("analysis_error.zig").ParserError;
const Executes = @import("parser_execute.zig");
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;

/// 埋め込み式の解析を行う関数
/// この関数は、埋め込み式を含む文字列を解析し、`Expression` を返します。
pub fn embeddedTextParser(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.EmbeddedText),
) ParserError!*Expression {
    // バッファを作成します
    var exprs = ArrayList(*Expression).init(allocator);
    defer exprs.deinit();

    // 埋め込み式の解析を行います
    while (iter.hasNext()) {
        const embedded = iter.peek().?;

        switch (embedded.kind) {
            .None => {
                // 埋め込み式以外は文字列として扱います
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .NoneEmbeddedExpress = embedded.str };
                exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
                _ = iter.next();
            },
            .Unfold => {
                // 展開埋め込み式を解析します
                const in_expr = try Parser.directExecutes(allocator, store, &embedded.str.mid(2, embedded.str.len() - 3));
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .UnfoldExpress = in_expr };
                exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
                _ = iter.next();
            },
            .NoEscapeUnfold => {
                // 非エスケープ展開埋め込み式を解析します
                const in_expr = try Parser.directExecutes(allocator, store, &embedded.str.mid(2, embedded.str.len() - 3));
                const expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
                expr.* = .{ .NoEscapeUnfoldExpress = in_expr };
                exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
                _ = iter.next();
            },
            .Variables => {
                // 変数埋め込み式を解析します
                exprs.append(try parseVariablesBlock(allocator, store, embedded)) catch return ParserError.OutOfMemoryExpression;
                _ = iter.next();
            },
            .IfBlock => {
                // Ifブロックを解析、最後の埋め込み式が EndIf であることを確認します
                const expr = try parseIfBlock(allocator, store, iter);
                if (iter.hasNext() and iter.peek().?.kind == .EndIfBlock) {
                    exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
                    _ = iter.next();
                } else {
                    return ParserError.IfBlockNotClosed;
                }
            },
            .ElseIfBlock, .ElseBlock, .EndIfBlock => {
                // ElseIfブロックまたはElseブロック、EndIfを解析
                return ParserError.IfBlockNotStarted;
            },
            .ForBlock => {
                // Forブロックを解析、最後の埋め込み式が EndFor であることを確認します
                const expr = try parseForBlock(allocator, store, iter);
                if (iter.hasNext() and iter.peek().?.kind == .EndForBlock) {
                    exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
                    _ = iter.next();
                } else {
                    return ParserError.ForBlockNotClosed;
                }
            },
            .EndForBlock => {
                // EndForブロックを解析
                return ParserError.IfBlockNotStarted;
            },
            .EmptyBlock => {
                // 空のブロックは無視します
                _ = iter.next();
            },
            //else => {
            //    // サポートされていない埋め込み式の場合はエラーを返す
            //    return ParserError.UnsupportedEmbeddedExpression;
            //},
        }
    }

    // 埋め込み式、非埋め込み式のリストを作成し、返します
    const list_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    const list_exprs = exprs.toOwnedSlice() catch return ParserError.OutOfMemoryExpression;
    list_expr.* = .{ .ListExpress = .{ .exprs = list_exprs } };
    return list_expr;
}

/// 変数埋め込み式を解析します。
/// この関数は、変数埋め込み式を解析し、`Expression` を返します。
/// 変数埋め込み式は、`${var1=value1; var2=value2; ...}` の形式で与えられます。
fn parseVariablesBlock(
    allocator: Allocator,
    store: *ExpressionStore,
    embedded: Lexical.EmbeddedText,
) ParserError!*Expression {
    // 式バッファを生成します
    var exprs = ArrayList(*Expression).init(allocator);
    defer exprs.deinit();

    // 入力文字列を単語に分割します
    const words = Lexical.splitWords(allocator, &embedded.str.mid(2, embedded.str.len() - 3)) catch return ParserError.OutOfMemoryString;
    defer allocator.free(words);

    // 変数式を解析します
    var iter = Iterator(Lexical.Word).init(words);
    while (iter.hasNext()) {
        const expr = try Executes.variableParser(allocator, store, &iter);
        exprs.append(expr) catch return ParserError.OutOfMemoryExpression;
        if (iter.peek()) |word| {
            if (word.kind != .Semicolon) return ParserError.VariableNotSemicolonSeparated;
            _ = iter.next(); // セミコロンをスキップ
        }
    }
    if (iter.hasNext()) {
        return ParserError.VariableNotSemicolonSeparated;
    }

    // 変数式をリストとして返します
    const var_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    const list_exprs = exprs.toOwnedSlice() catch return ParserError.OutOfMemoryExpression;
    var_expr.* = .{ .VariableListExpress = list_exprs };
    return var_expr;
}

/// If埋め込み式を解析します。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
fn parseIfBlock(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.EmbeddedText),
) ParserError!*Expression {
    // 式バッファを生成します
    var exprs = ArrayList(*Expression).init(allocator);
    defer exprs.deinit();

    var prev_condition = iter.peek().?;
    var prev_type = Lexical.EmbeddedType.IfBlock;
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
                        allocator,
                        store,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                    )) catch return ParserError.OutOfMemoryExpression;
                    prev_condition = blk;
                    prev_type = .ElseIfBlock;
                    update = true;
                }
            },

            // elseブロックを評価
            .ElseBlock => {
                if (lv == 0) {
                    exprs.append(try parseIfExpression(
                        allocator,
                        store,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                    )) catch return ParserError.OutOfMemoryExpression;
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
                        allocator,
                        store,
                        iter,
                        prev_condition,
                        prev_type,
                        start,
                        end,
                    )) catch return ParserError.OutOfMemoryExpression;
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

    // If式をリストとして返します
    const if_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
    const if_exprs = exprs.toOwnedSlice() catch return ParserError.OutOfMemoryExpression;
    if_expr.* = .{ .IfExpress = if_exprs };
    return if_expr;
}

/// If埋め込み式の各式を取得します。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
fn parseIfExpression(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.EmbeddedText),
    prev_condition: Lexical.EmbeddedText,
    prev_type: Lexical.EmbeddedType,
    start: usize,
    end: usize,
) ParserError!*Expression {
    // ブロック内の要素のイテレータを作成します
    var in_iter = Iterator(Lexical.EmbeddedText).init(iter.items[start..end]);

    switch (prev_type) {
        .IfBlock, .ElseIfBlock => {
            // IfブロックまたはElseIfブロックの条件式を解析
            const condition = try Parser.directExecutes(allocator, store, &prev_condition.str);

            // Ifブロックの実行部を解析
            const inner_expr = try embeddedTextParser(allocator, store, &in_iter);

            // If条件式を作成
            const if_condition_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
            if_condition_expr.* = .{ .IfConditionExpress = .{ .condition = condition, .inner = inner_expr } };
            return if_condition_expr;
        },
        .ElseBlock => {
            // Elseブロックの実行部を作成
            const inner_expr = try embeddedTextParser(allocator, store, &in_iter);

            // Elseブロックの条件式を作成
            const else_expr = store.get({}) catch return ParserError.OutOfMemoryExpression;
            else_expr.* = .{ .ElseExpress = inner_expr };
            return else_expr;
        },
        else => return ParserError.ConditionParseFailed,
    }
}

/// For埋め込み式を解析します。
/// `parser` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
fn parseForBlock(
    allocator: Allocator,
    store: *ExpressionStore,
    iter: *Iterator(Lexical.EmbeddedText),
) ParserError!*Expression {
    // forブロックの開始を取得
    var for_condition = iter.peek().?;
    _ = iter.next();

    // forの繰り返し範囲を取得
    const start: usize = iter.index;
    var end: usize = iter.index;
    var lv: u8 = 0;
    var end_for = false;
    while (iter.hasNext()) {
        const blk = iter.peek().?;
        switch (blk.kind) {
            // for が開始された場合、ネストレベルを増やす
            .ForBlock => lv += 1,

            // Ifが終了された場合、ネストレベルを減らす
            .EndForBlock => {
                if (lv > 0) {
                    lv -= 1;
                } else {
                    // ネストが終了でループも終了
                    end_for = true;
                    break;
                }
            },
            else => {},
        }
        _ = iter.next();
        end = iter.index;
    }

    if (end_for) {
        // 入力文字列を単語に分割します
        const words = Lexical.splitWords(allocator, &for_condition.str) catch return ParserError.OutOfMemoryString;
        defer allocator.free(words);

        // forの繰り返し条件を解析します
        var iter_words = Iterator(Lexical.Word).init(words);
        var for_expr = try Executes.forStatementParser(allocator, store, &iter_words);

        // forの繰り返す範囲を式として解析します
        var in_iter = Iterator(Lexical.EmbeddedText).init(iter.items[start..end]);
        for_expr.ForExpress.body = try embeddedTextParser(allocator, store, &in_iter);

        return for_expr;
    } else {
        // Forブロックが閉じられていない場合はエラーを返
        return ParserError.ForBlockNotClosed;
    }
}
