const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const Char = @import("char.zig").Char;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ArrayList = std.ArrayList;
const Block = LexicalAnalysis.Block;
const BlockType = LexicalAnalysis.BlockType;
const Store = @import("store.zig").Store;

const AllErrors = ParserError || ParserError;

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
pub fn Parser() type {
    return struct {
        /// 自身の型
        const Self = @This();

        // 式のストア
        expr_store: Store(Expression, 32, resetExpression, initExpression, deinitExpression),

        // 文字列のストア
        string_store: Store(String, 32, resetString, initString, deinitString),

        // アロケータ
        allocator: Allocator,

        /// 単語のイテレータ。
        fn Iterator(comptime T: type) type {
            return struct {
                /// 単語のリスト
                items: []T,
                index: usize,

                pub fn init(items: []T, index: usize) @This() {
                    return .{ .items = items, .index = index };
                }

                /// 次の要素が存在するかどうかを確認します。
                pub fn hasNext(self: *@This()) bool {
                    return self.index < self.items.len;
                }

                /// 現在の要素を取得します。
                pub fn peek(self: *@This()) ?T {
                    if (self.index < self.items.len) {
                        return self.items[self.index];
                    } else {
                        return null;
                    }
                }

                /// 次の要素を取得します。
                pub fn next(self: *@This()) ?T {
                    if (self.index < self.items.len) {
                        const res = self.items[self.index];
                        self.index += 1;
                        return res;
                    } else {
                        return null;
                    }
                }
            };
        }

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
                    alloc.free(list_expr.expr);
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

        /// 式を解析して実行する関数。
        /// 入力は文字列のポインタで、アロケータを使用してメモリを管理します。
        /// この関数は、式を解析し、結果の `Expression` を返します。
        pub fn executes(self: *Self, input: *const String) !*Expression {
            // 入力文字列を単語に分割します
            const words = try LexicalAnalysis.splitWords(input, self.allocator);
            defer self.allocator.free(words);

            // 単語のイテレータを作成します
            var iter = Iterator(LexicalAnalysis.Word).init(words, 0);

            // 文字列バッファを生成します
            var buffer = ArrayList(u8).init(self.allocator);
            defer buffer.deinit();

            return blk: {
                // 解析を開始します
                const res = self.ternaryOperatorParser(&iter, &buffer);

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
            const blocks = try LexicalAnalysis.splitBlocks(input, self.allocator);
            defer self.allocator.free(blocks);

            // 単語のイテレータを作成します
            var iter = Iterator(LexicalAnalysis.Block).init(blocks, 0);

            // 文字列バッファを生成します
            var buffer = ArrayList(u8).init(self.allocator);
            defer buffer.deinit();

            return blk: {
                // 解析を開始します
                const res = self.blocksParser(&iter, &buffer);

                // 残っている単語がある場合は、無効な式とみなします
                if (iter.hasNext()) {
                    return error.InvalidExpression;
                }
                break :blk res;
            };
        }

        /// ブロックの解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` はブロックのイテレータです。
        /// この関数は、ブロックを解析し、結果の `Expression` を返します。
        fn blocksParser(self: *Self, iter: *Iterator(LexicalAnalysis.Block), buffer: *ArrayList(u8)) !*Expression {
            // ブロックの解析を行います
            var exprs = ArrayList(*Expression).init(self.allocator);
            defer exprs.deinit();

            while (iter.hasNext()) {
                const block = iter.peek().?;

                switch (block.kind) {
                    .Text => {
                        exprs.append(try self.parseTextBlock(block, buffer)) catch return error.OutOfMemoryExpression;
                        _ = iter.next();
                    },
                    .Unfold => {
                        exprs.append(try self.parseUnfoldBlock(block, buffer)) catch return error.OutOfMemoryExpression;
                        _ = iter.next();
                    },
                    .NoEscapeUnfold => {
                        exprs.append(try self.parseNoEscapeUnfoldBlock(block, buffer)) catch return error.OutOfMemoryExpression;
                        _ = iter.next();
                    },
                    else => {},
                }
            }

            // 解析した式をリストとして返します
            const list_expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
            list_expr.* = .{ .parser = self, .data = .{ .ListExpress = .{ .expr = try exprs.toOwnedSlice() } } };
            return list_expr;
        }

        /// テキストブロックを解析します。
        /// `self` は自身のパーサーインスタンスで、`block` はブロックのデータです。
        fn parseTextBlock(self: *Self, block: Block, buffer: *ArrayList(u8)) !*Expression {
            const text_expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
            text_expr.* = Expression{ .parser = self, .data = .{ .StringExpress = try self.unescapeBracket(block.str.raw(), buffer, 0, 0) } };
            return text_expr;
        }

        /// 展開ブロックを解析します。
        /// `self` は自身のパーサーインスタンスで、`block` はブロックのデータです。
        fn parseUnfoldBlock(self: *Self, block: Block, buffer: *ArrayList(u8)) !*Expression {
            const unfold_expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
            unfold_expr.* = .{ .parser = self, .data = .{ .UnfoldExpress = try self.unescapeBracket(block.str.raw(), buffer, 2, 1) } };
            return unfold_expr;
        }

        /// 展開ブロックを解析します（）
        /// `self` は自身のパーサーインスタンスで、`block` はブロックのデータです。
        fn parseNoEscapeUnfoldBlock(self: *Self, block: Block, buffer: *ArrayList(u8)) !*Expression {
            const no_unfold_expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
            no_unfold_expr.* = .{ .parser = self, .data = .{ .NoEscapeUnfoldExpress = try self.unescapeBracket(block.str.raw(), buffer, 2, 1) } };
            return no_unfold_expr;
        }

        /// 入力文字列からエスケープされた波括弧を取り除きます。
        /// `self` は自身のパーサーインスタンスで、`source` は入力の文字列スライスです。
        fn unescapeBracket(self: *Self, source: []const u8, buffer: *ArrayList(u8), startSkip: comptime_int, lastSkip: comptime_int) AllErrors!*String {
            buffer.clearRetainingCapacity();

            var src_ptr = source.ptr + startSkip;
            while (@intFromPtr(src_ptr) < @intFromPtr(source.ptr + source.len - lastSkip)) {
                if (src_ptr[0] == '\\' and @intFromPtr(src_ptr + 1) < @intFromPtr(source.ptr + source.len - lastSkip) and (src_ptr[1] == '{' or src_ptr[1] == '}')) {
                    // エスケープされた波括弧を処理
                    buffer.append(src_ptr[1]) catch return ParserError.OutOfMemoryString;
                    src_ptr += 2;
                } else {
                    buffer.append(src_ptr[0]) catch return ParserError.OutOfMemoryString;
                    src_ptr += 1;
                }
            }
            return self.string_store.get(.{ buffer.items, buffer.items.len }) catch return error.OutOfMemoryString;
        }

        /// 三項演算子の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、三項演算子（条件 ? 真の値 : 偽の値）を解析し、結果の `Expression` を返します。
        fn ternaryOperatorParser(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) !*Expression {
            const condition = try self.logicalParser(iter, buffer);
            if (iter.peek()) |word| {
                if (word.kind == .Question) {
                    _ = iter.next();

                    // 三項演算子の左辺と右辺を解析
                    const ture_expr = try self.logicalParser(iter, buffer);
                    if (iter.hasNext() and iter.peek().?.kind == .Colon) {
                        _ = iter.next();
                    } else {
                        return error.InvalidExpression;
                    }
                    const false_expr = try self.logicalParser(iter, buffer);

                    // 三項演算子の式を生成
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .TernaryExpress = .{ .condition = condition, .true_expr = ture_expr, .false_expr = false_expr } } };
                    return expr;
                }
            }
            return condition;
        }

        /// 論理式の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、論理式を解析し、結果の `Expression` を返します。
        fn logicalParser(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) !*Expression {
            var left = try self.comparisonParser(iter, buffer);
            while (iter.peek()) |word| {
                if (word.kind == .AndOperator or word.kind == .OrOperator or word.kind == .XorOperator) {
                    _ = iter.next();
                    const right = try self.comparisonParser(iter, buffer);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        /// 比較式の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、比較式を解析し、結果の `Expression` を返します。
        fn comparisonParser(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression {
            var left = try self.additionOrSubtractionParser(iter, buffer);
            while (iter.peek()) |word| {
                if (word.kind == .GreaterEqual or word.kind == .LessEqual or word.kind == .GreaterThan or word.kind == .LessThan or word.kind == .Equal or word.kind == .NotEqual) {
                    _ = iter.next();
                    const right = try self.additionOrSubtractionParser(iter, buffer);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        /// 加算または減算の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、加算または減算の式を解析し、結果の `Expression` を返します。
        fn additionOrSubtractionParser(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression {
            var left = try self.multiplyOrDevisionParser(iter, buffer);
            while (iter.peek()) |word| {
                if (word.kind == .Plus or word.kind == .Minus) {
                    _ = iter.next();
                    const right = try self.multiplyOrDevisionParser(iter, buffer);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        /// 乗算または除算の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、乗算または除算の式を解析し、結果の `Expression` を返します。
        fn multiplyOrDevisionParser(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression {
            var left = try self.parseFactor(iter, buffer);
            while (iter.peek()) |word| {
                if (word.kind == .Multiply or word.kind == .Devision) {
                    _ = iter.next();
                    const right = try self.parseFactor(iter, buffer);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        /// 単項式の解析を行います。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、単項式を解析し、結果の `Expression` を返します。
        fn parseFactor(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression {
            if (iter.peek()) |word| {
                switch (word.kind) {
                    .LeftParen => {
                        const expr = try self.parseParen(iter, buffer);
                        if (iter.hasNext() and iter.peek().?.kind == .RightParen) {
                            _ = iter.next();
                        } else {
                            return error.InvalidExpression;
                        }
                        return expr;
                    },
                    .Number => {
                        _ = iter.next();
                        const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                        expr.* = .{ .parser = self, .data = .{ .NumberExpress = try self.parseNumber(word.str.raw()) } };
                        return expr;
                    },
                    .StringLiteral => {
                        _ = iter.next();
                        const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                        expr.* = .{ .parser = self, .data = .{ .StringExpress = try self.parseStringLiteral(word.str.raw(), buffer) } };
                        return expr;
                    },
                    .Plus, .Minus, .Not => {
                        _ = iter.next();
                        const nextExpr = try self.parseFactor(iter, buffer);
                        const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                        expr.* = .{ .parser = self, .data = .{ .UnaryExpress = .{ .kind = word.kind, .expr = nextExpr } } };
                        return expr;
                    },
                    .TrueLiteral => {
                        _ = iter.next();
                        const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                        expr.* = .{ .parser = self, .data = .{ .BooleanExpress = true } };
                        return expr;
                    },
                    .FalseLiteral => {
                        _ = iter.next();
                        const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                        expr.* = .{ .parser = self, .data = .{ .BooleanExpress = false } };
                        return expr;
                    },
                    else => {},
                }
            }
            return error.InvalidExpression;
        }

        /// 文字列を数値にします。
        /// `self` は自身のパーサーインスタンスで、`str` は数値の文字列スライスです。
        /// この関数は、数値の単語を解析し、結果の `Expression` を返します。
        fn parseNumber(_: *Self, str: []const u8) AllErrors!f64 {
            return std.fmt.parseFloat(f64, str) catch return ParserError.OutOfMemoryNumber;
        }

        /// 文字列リテラルを解析します。
        /// `self` は自身のパーサーインスタンスで、`str` は文字列リテラルのスライスです。
        fn parseStringLiteral(self: *Self, source: []const u8, buffer: *ArrayList(u8)) AllErrors!*String {
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
                            'n' => buffer.append('\n') catch return ParserError.OutOfMemoryString,
                            't' => buffer.append('\t') catch return ParserError.OutOfMemoryString,
                            '\\' => buffer.append('\\') catch return ParserError.OutOfMemoryString,
                            '"' => buffer.append('"') catch return ParserError.OutOfMemoryString,
                            '\'' => buffer.append('\'') catch return ParserError.OutOfMemoryString,
                            else => {},
                        }
                        src_ptr += 1;
                    } else {
                        return ParserError.EvaluationFailed;
                    }
                } else {
                    buffer.append(src_ptr[0]) catch return ParserError.OutOfMemoryString;
                    src_ptr += 1;
                }
            }
            return self.string_store.get(.{ buffer.items, buffer.items.len }) catch return ParserError.OutOfMemoryString;
        }

        /// 括弧で囲まれた式を解析します。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、左括弧が見つかった場合に括弧内の式を解析し、結果の `Expression` を返します。
        /// もし左括弧が見つからなかった場合は、論理式の解析を行います。
        fn parseParen(self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression {
            if (iter.peek()) |word| {
                if (word.kind == .LeftParen) {
                    _ = iter.next();
                    return try self.parenBlockParser(.LeftParen, .RightParen, iter, buffer, logicalParser);
                } else {
                    return try self.logicalParser(iter, buffer);
                }
            }
            return error.InvalidExpression;
        }

        /// 括弧で囲まれたブロックを解析します。
        /// `LParen` と `RParen` は、左括弧と右括弧の種類を指定します。
        /// `next_parser` は、括弧内の式を解析するための次のパーサー関数です。
        /// この関数は、括弧内の式を解析し、結果の `Expression` を返します。
        fn parenBlockParser(self: *Self, comptime LParen: LexicalAnalysis.WordType, comptime RParen: LexicalAnalysis.WordType, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8), next_parser: fn (self: *Self, iter: *Iterator(LexicalAnalysis.Word), buffer: *ArrayList(u8)) AllErrors!*Expression) AllErrors!*Expression {
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
                            // 右括弧が見つかった場合、ループを終了
                            break;
                        }
                    },
                    else => {},
                }
                _ = iter.next();
                end = iter.index;
            }

            // 括弧内の式を解析
            const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
            var in_iter = Iterator((LexicalAnalysis.Word)).init(iter.items[start..end], 0);
            expr.* = .{ .parser = self, .data = .{ .ParenExpress = .{ .inner = try next_parser(self, &in_iter, buffer) } } };
            return expr;
        }

        /// 式の定義
        pub const Expression = struct {
            parser: *Self,

            /// 式の種類を表す列挙型。
            data: union(enum) {
                ListExpress: struct { expr: []*Expression },
                UnfoldExpress: *String,
                NoEscapeUnfoldExpress: *String,
                TernaryExpress: struct { condition: *Expression, true_expr: *Expression, false_expr: *Expression },
                ParenExpress: struct { inner: *Expression },
                BinaryExpress: struct { kind: LexicalAnalysis.WordType, left: *Expression, right: *Expression },
                UnaryExpress: struct { kind: LexicalAnalysis.WordType, expr: *Expression },
                NumberExpress: f64,
                StringExpress: *String,
                BooleanExpress: bool,
            },

            /// 式を評価して値を取得します。
            /// この関数は、式の種類に応じて適切な評価を行い、結果の値を返します。
            pub fn get(self: *const Expression) ParserError!Value {
                return switch (self.*.data) {
                    .ListExpress => |expr| {
                        var values = ArrayList(u8).init(self.parser.allocator);
                        defer values.deinit();
                        for (expr.expr) |e| {
                            const value = try e.get();
                            values.appendUnalignedSlice(value.String.raw()) catch return error.OutOfMemoryString;
                        }
                        const tmp: *String = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return error.OutOfMemoryString;
                        const vtp: []u8 = values.toOwnedSlice() catch return error.OutOfMemoryString;
                        defer self.parser.allocator.free(vtp);
                        tmp.* = String.newString(self.parser.allocator, vtp) catch return error.OutOfMemoryString;
                        return .{ .String = tmp };
                    },
                    .UnfoldExpress => |str| {
                        const expr = self.parser.executes(str) catch return error.EvaluationFailed;
                        return switch (try expr.get()) {
                            .String => |s| .{ .String = s },
                            .Number => |n| {
                                const msg = std.fmt.allocPrint(self.parser.allocator, "{d}", .{n}) catch return error.OutOfMemoryString;
                                defer self.parser.allocator.free(msg);
                                return .{ .String = self.parser.string_store.get(.{ msg, msg.len }) catch return error.OutOfMemoryString };
                            },
                            else => return error.EvaluationFailed,
                        };
                    },
                    .NoEscapeUnfoldExpress => |str| .{ .String = str },
                    .TernaryExpress => |expr| executesTernary(expr.condition, expr.true_expr, expr.false_expr),
                    .ParenExpress => |expr| expr.inner.get(),
                    .BinaryExpress => |expr| self.executesBinary(expr.kind, expr.left, expr.right),
                    .UnaryExpress => |expr| executesUnary(expr.kind, expr.expr),
                    .NumberExpress => .{ .Number = self.data.NumberExpress },
                    .StringExpress => |str| .{ .String = str },
                    .BooleanExpress => |bol| .{ .Boolean = bol },
                };
            }

            /// 文字列を連結します。
            /// `left` と `right` は連結する文字列で、結果の値を返します。
            /// この関数は、2つの文字列を連結し、新しい文字列を生成します。
            fn concat(self: *const Expression, left: *String, right: *String) ParserError!Value {
                const res = left.concat(self.parser.allocator, right) catch return error.OutOfMemoryString;
                const tmp: *String = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return error.OutOfMemoryString;
                tmp.* = res;
                return .{ .String = tmp };
            }

            /// 三項演算子を実行します。
            /// `expr` は三項演算子の式で、条件に応じて真の値または偽の値を返します。
            /// この関数は、三項演算子の条件を評価し、結果の値を返します。
            /// `condition` は条件式、`true_expr` は真の場合の式、`false_expr` は偽の場合の式です。
            fn executesTernary(condition: *Expression, true_expr: *Expression, false_expr: *Expression) ParserError!Value {
                const conditionValue = try condition.get();
                if (conditionValue.Boolean) {
                    return try true_expr.get();
                } else {
                    return try false_expr.get();
                }
            }

            /// 単項演算子を実行します。
            /// `kind` は演算子の種類で、`expr` は対象の式です。
            /// この関数は、単項演算子を適用し、結果の値を返します。
            fn executesUnary(kind: LexicalAnalysis.WordType, expr: *Expression) ParserError!Value {
                const value = try expr.get();
                return switch (kind) {
                    .Plus => switch (value) {
                        .Number => .{ .Number = value.Number },
                        else => error.UnaryOperatorNotSupported,
                    },
                    .Minus => switch (value) {
                        .Number => .{ .Number = -value.Number },
                        else => error.UnaryOperatorNotSupported,
                    },
                    .Not => switch (value) {
                        .Boolean => .{ .Boolean = !value.Boolean },
                        else => error.UnaryOperatorNotSupported,
                    },
                    else => error.UnaryOperatorNotSupported,
                };
            }

            /// バイナリ式を実行します。
            /// `kind` は演算子の種類で、`left` と `right` は左辺と右辺の式です。
            /// この関数は、バイナリ演算子を適用し、結果の値を返します。
            fn executesBinary(self: *const Expression, kind: LexicalAnalysis.WordType, left: *Expression, right: *Expression) ParserError!Value {
                const leftValue = try left.get();
                const rightValue = try right.get();
                return switch (kind) {
                    .Plus => self.additionExpression(leftValue, rightValue),
                    .Minus => subtractionExpression(leftValue, rightValue),
                    .Multiply => multiplicationExpression(leftValue, rightValue),
                    .Devision => divisionExpression(leftValue, rightValue),
                    .AndOperator => andExpression(leftValue, rightValue),
                    .OrOperator => orExpression(leftValue, rightValue),
                    .XorOperator => xorExpression(leftValue, rightValue),
                    .GreaterThan => greaterExpression(leftValue, rightValue),
                    .GreaterEqual => greaterEqualExpression(leftValue, rightValue),
                    .LessThan => lessExpression(leftValue, rightValue),
                    .LessEqual => lessEqualExpression(leftValue, rightValue),
                    .Equal => equalExpression(leftValue, rightValue),
                    .NotEqual => notEqualExpression(leftValue, rightValue),
                    else => error.BinaryOperatorNotSupported,
                };
            }

            /// より大きいを実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn greaterExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => blk: {
                            const res = @abs(leftValue.Number - rightValue.Number);
                            break :blk .{ .Boolean = leftValue.Number > rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
                        },
                        else => error.GreaterOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.greater },
                        else => error.GreaterOperatorNotSupported,
                    },
                    else => error.GreaterOperatorNotSupported,
                };
            }

            /// 以上を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn greaterEqualExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => blk: {
                            const res = @abs(leftValue.Number - rightValue.Number);
                            break :blk .{ .Boolean = leftValue.Number > rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
                        },
                        else => error.GreaterEqualOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.less },
                        else => error.GreaterEqualOperatorNotSupported,
                    },
                    else => error.GreaterEqualOperatorNotSupported,
                };
            }

            /// より小さいを実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn lessExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => blk: {
                            const res = @abs(leftValue.Number - rightValue.Number);
                            break :blk .{ .Boolean = leftValue.Number < rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
                        },
                        else => error.LessOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.less },
                        else => error.LessOperatorNotSupported,
                    },
                    else => error.LessOperatorNotSupported,
                };
            }

            /// 以下を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn lessEqualExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => blk: {
                            const res = @abs(leftValue.Number - rightValue.Number);
                            break :blk .{ .Boolean = leftValue.Number < rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
                        },
                        else => error.LessEqualOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.greater },
                        else => error.LessEqualOperatorNotSupported,
                    },
                    else => error.LessEqualOperatorNotSupported,
                };
            }

            /// 等価演算子を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn equalExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) <= std.math.nextAfter(f64, 0, 1) },
                        else => error.EqualOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.equal },
                        else => error.EqualOperatorNotSupported,
                    },
                    .Boolean => switch (rightValue) {
                        .Boolean => .{ .Boolean = leftValue.Boolean == rightValue.Boolean },
                        else => error.EqualOperatorNotSupported,
                    },
                };
            }

            /// 不等号を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn notEqualExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) > std.math.nextAfter(f64, 0, 1) },
                        else => error.NotEqualOperatorNotSupported,
                    },
                    .String => switch (rightValue) {
                        .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.equal },
                        else => error.NotEqualOperatorNotSupported,
                    },
                    .Boolean => switch (rightValue) {
                        .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
                        else => error.NotEqualOperatorNotSupported,
                    },
                };
            }

            /// 数値、文字の加算を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn additionExpression(self: *const Expression, leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => .{ .Number = leftValue.Number + rightValue.Number },
                        else => error.CalculationFailed,
                    },
                    .String => switch (rightValue) {
                        .String => try self.concat(leftValue.String, rightValue.String),
                        else => error.CalculationFailed,
                    },
                    else => error.CalculationFailed,
                };
            }

            /// 数値の減算を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn subtractionExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => .{ .Number = leftValue.Number - rightValue.Number },
                        else => error.CalculationFailed,
                    },
                    else => error.CalculationFailed,
                };
            }

            /// 数値の乗算を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn multiplicationExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => .{ .Number = leftValue.Number * rightValue.Number },
                        else => error.CalculationFailed,
                    },
                    else => error.CalculationFailed,
                };
            }

            /// 数値の除算を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn divisionExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Number => switch (rightValue) {
                        .Number => if (rightValue.Number != 0) .{ .Number = leftValue.Number / rightValue.Number } else error.InvalidExpression,
                        else => error.CalculationFailed,
                    },
                    else => error.CalculationFailed,
                };
            }

            /// AND演算子を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn andExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Boolean => switch (rightValue) {
                        .Boolean => .{ .Boolean = leftValue.Boolean and rightValue.Boolean },
                        else => error.LogicalOperationFailed,
                    },
                    else => error.LogicalOperationFailed,
                };
            }

            /// OR演算子を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn orExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Boolean => switch (rightValue) {
                        .Boolean => .{ .Boolean = leftValue.Boolean or rightValue.Boolean },
                        else => error.LogicalOperationFailed,
                    },
                    else => error.LogicalOperationFailed,
                };
            }

            /// XOR演算を実行します。
            /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
            fn xorExpression(leftValue: Value, rightValue: Value) ParserError!Value {
                return switch (leftValue) {
                    .Boolean => switch (rightValue) {
                        .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
                        else => error.LogicalOperationFailed,
                    },
                    else => error.LogicalOperationFailed,
                };
            }
        };

        /// 式の値を表す。
        /// この値は、数値、文字列、真偽値、またはエラーを含むことができます。
        pub const Value = union(enum) {
            Number: f64,
            String: *String,
            Boolean: bool,
        };
    };
}
