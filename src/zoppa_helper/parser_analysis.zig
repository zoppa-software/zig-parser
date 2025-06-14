const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ArrayList = std.ArrayList;
const Store = @import("stores/store.zig").Store;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const ParserError = @import("analysis_error.zig").ParserError;
const Executes = @import("parser_analysis_execute.zig");
const Embedded = @import("parser_analysis_embedded.zig");
const Variables = @import("analysis_variables.zig").AnalysisVariableHierarchy;

/// 構文解析器のモジュール。
/// このモジュールは、文字列を解析して式を生成するための機能を提供します。
/// 式は、加算、減算、乗算、除算などの基本的な数学演算をサポートします。
/// 式は、単項演算子（プラス、マイナス、否定）と二項演算子（加算、減算、乗算、除算）を含むことができます。
/// このモジュールは、式の解析と評価を行うための `Parser` 構造体を提供します。
pub const AnalysisParser = struct {
    /// 自身の型
    const Self = @This();

    // アロケータ
    allocator: Allocator,

    // 式のストア
    expr_store: Store(Expression, 32, initExpression, deinitExpression),

    // 文字列のストア
    string_store: Store(String, 32, initString, deinitString),

    // 変数階層
    variables: Variables,

    /// パーサーを初期化します。
    pub fn init(alloc: Allocator) !Self {
        return Self{
            .allocator = alloc,
            .expr_store = try Store(Expression, 32, initExpression, deinitExpression).init(alloc),
            .string_store = try Store(String, 32, initString, deinitString).init(alloc),
            .variables = try Variables.init(alloc),
        };
    }

    /// パーサーを破棄します。
    pub fn deinit(self: *Self) void {
        self.expr_store.deinit();
        self.string_store.deinit();
        self.variables.deinit();
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

    /// 式を解析して実行する関数。
    /// 入力は文字列のポインタで、アロケータを使用してメモリを管理します。
    /// この関数は、式を解析し、結果の `Expression` を返します。
    pub fn executes(self: *Self, input: *const String) !*Expression {
        // 入力文字列を単語に分割します
        const words = try LexicalAnalysis.splitWords(input, self.allocator);
        defer self.allocator.free(words);

        // 単語のイテレータを作成します
        var iter = Iterator(LexicalAnalysis.Word).init(words);

        // 文字列バッファを生成します
        var buffer = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        return blk: {
            // 解析を開始します
            const res = Executes.ternaryOperatorParser(self, &iter, &buffer);

            // 残っている単語がある場合は、無効な式とみなします
            if (iter.hasNext()) {
                return error.InvalidExpression;
            }
            break :blk res;
        };
    }

    /// 文章を翻訳します。
    /// この関数は、入力の文字列を解析し、結果の `String` を返します。
    pub fn translate(self: *Self, input: *const String) !*Expression {
        // 入力文字列をブロックに分割します
        const embeddeds = try LexicalAnalysis.splitEmbeddedText(input, self.allocator);
        defer self.allocator.free(embeddeds);

        // 単語のイテレータを作成します
        var iter = Iterator(LexicalAnalysis.EmbeddedText).init(embeddeds);

        // 文字列バッファを生成します
        var buffer = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        return blk: {
            // 解析を開始します
            const res = Embedded.embeddedTextParser(self, &iter, &buffer);

            // 残っている単語がある場合は、無効な式とみなします
            if (iter.hasNext()) {
                return error.InvalidExpression;
            }
            break :blk res;
        };
    }

    pub fn getNumberExpr(self: *Self, number: f64) !*Expression {
        // 数値式を生成します
        const expr = try self.expr_store.get(.{});
        expr.* = .{ .parser = self, .data = .{ .NumberExpress = number } };
        return expr;
    }
};
