const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const Char = @import("char.zig").Char;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ArrayList = std.ArrayList;
const Store = @import("store.zig").Store;
const Value = @import("analysis_value.zig").AnalysisValue;
const Expression = @import("parser_analysis_expression.zig").AnalysisExpression;
const AnalysisValue = @import("analysis_value.zig");
const AnalysisIterator = @import("parser_analysis_iterator.zig");
const AnalysisBlock = @import("parser_analysis_block.zig");
const AnalysisExecutes = @import("parser_analysis_executes.zig");

const AllErrors = LexicalAnalysis.LexicalError || ParserError;

/// エラー列挙型
pub const ParserError = error{
    /// 式の生成に失敗した場合のエラー
    InvalidExpression,
    /// 式の生成に失敗した場合のエラー
    OutOfMemoryExpression,
    /// 一時的なメモリ不足エラー（数値）
    OutOfMemoryNumber,
    /// 一時的なメモリ不足エラー（文字列）
    OutOfMemoryString,
    /// 評価に失敗した場合のエラー
    EvaluationFailed,
    /// 単項演算子がサポートされていない場合のエラー
    UnaryOperatorNotSupported,
    /// 二項演算子がサポートされていない場合のエラー
    BinaryOperatorNotSupported,
    /// より大きい演算子がサポートされていない場合のエラー
    GreaterOperatorNotSupported,
    /// 以上演算子がサポートされていない場合のエラー
    GreaterEqualOperatorNotSupported,
    /// より小さい演算子がサポートされていない場合のエラー
    LessOperatorNotSupported,
    /// 以下演算子がサポートされていない場合のエラー
    LessEqualOperatorNotSupported,
    /// 等しい演算子がサポートされていない場合のエラー
    EqualOperatorNotSupported,
    /// 等しくない演算子がサポートされていない場合のエラー
    NotEqualOperatorNotSupported,
    /// 計算に失敗した場合のエラー
    CalculationFailed,
    /// 論理演算に失敗した場合のエラー
    LogicalOperationFailed,
};

/// 構文解析器のモジュール。
/// このモジュールは、文字列を解析して式を生成するための機能を提供します。
/// 式は、加算、減算、乗算、除算などの基本的な数学演算をサポートします。
/// 式は、単項演算子（プラス、マイナス、否定）と二項演算子（加算、減算、乗算、除算）を含むことができます。
/// このモジュールは、式の解析と評価を行うための `Parser` 構造体を提供します。
pub const Parser = struct {
    /// 自身の型
    const Self = @This();

    // 式のストア
    expr_store: Store(Expression, 32, resetExpression, initExpression, deinitExpression),

    // 文字列のストア
    string_store: Store(String, 32, resetString, initString, deinitString),

    // アロケータ
    allocator: Allocator,

    /// パーサーを初期化します。
    pub fn init(alloc: Allocator) !Self {
        return Self{
            .expr_store = try Store(Expression, 32, resetExpression, initExpression, deinitExpression).init(alloc),
            .string_store = try Store(String, 32, resetString, initString, deinitString).init(alloc),
            .allocator = alloc,
        };
    }

    /// パーサーを破棄します。
    pub fn deinit(self: *Self) void {
        self.expr_store.deinit();
        self.string_store.deinit();
    }

    /// 式のクリア関数
    fn resetExpression(expr: *Expression) void {
        expr.data = .{ .NumberExpress = 0.0 };
    }

    /// 式の初期化関数
    fn initExpression(_: Allocator, _: *Expression, _: anytype) !void {}

    /// 式の破棄関数
    fn deinitExpression(alloc: Allocator, expr: *Expression) void {
        switch (expr.data) {
            .ListExpress => |list_expr| {
                alloc.free(list_expr.exprs);
            },
            .IfExpress => |if_expr| {
                alloc.free(if_expr.exprs);
            },
            else => {},
        }
    }

    /// 文字列のクリア関数
    fn resetString(_: *String) void {}

    /// 文字列の初期化関数
    fn initString(alloc: Allocator, str: *String, args: anytype) !void {
        if (args[1] > 0) {
            str.* = String.newString(alloc, args[0][0..args[1]]) catch return ParserError.OutOfMemoryString;
        }
    }

    /// 文字列の破棄関数
    fn deinitString(_: Allocator, str: *String) void {
        str.deinit();
    }

    /// 文章を翻訳します。
    /// この関数は、入力の文字列を解析し、結果の `String` を返します。
    pub fn translate(self: *Self, input: *const String) !*Expression {
        // 入力文字列をブロックに分割します
        const blocks = try LexicalAnalysis.splitBlocks(input, self.allocator);
        defer self.allocator.free(blocks);

        // 単語のイテレータを作成します
        var iter = AnalysisIterator.Iterator(LexicalAnalysis.Block).init(blocks, 0);

        // 文字列バッファを生成します
        var buffer = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        return blk: {
            // 解析を開始します
            const res = AnalysisBlock.blocksParser(self, &iter, &buffer);

            // 残っている単語がある場合は、無効な式とみなします
            if (iter.hasNext()) {
                return error.InvalidExpression;
            }
            break :blk res;
        };
    }

    /// 式を解析して実行する関数。
    /// 入力は文字列のポインタで、アロケータを使用してメモリを管理します。
    /// この関数は、式を解析し、結果の `Expression` を返します。
    pub fn executes(self: *Self, input: *const String) !*Expression {
        // 入力文字列を単語に分割します
        const words = try LexicalAnalysis.splitWords(input, self.allocator);
        defer self.allocator.free(words);

        // 単語のイテレータを作成します
        var iter = AnalysisIterator.Iterator(LexicalAnalysis.Word).init(words, 0);

        // 文字列バッファを生成します
        var buffer = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        return blk: {
            // 解析を開始します
            const res = AnalysisExecutes.ternaryOperatorParser(self, &iter, &buffer);

            // 残っている単語がある場合は、無効な式とみなします
            if (iter.hasNext()) {
                return error.InvalidExpression;
            }
            break :blk res;
        };
    }
};
