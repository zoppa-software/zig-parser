const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const Char = @import("char.zig").Char;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ArrayList = std.ArrayList;
const Word = LexicalAnalysis.Word;
const WordType = LexicalAnalysis.WordType;
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
        const Iterator = struct {
            words: []Word,
            index: usize,

            /// 次の要素が存在するかどうかを確認します。
            pub fn hasNext(self: *Iterator) bool {
                return self.index < self.words.len;
            }

            /// 現在の要素を取得します。
            pub fn peek(self: *Iterator) ?Word {
                if (self.index < self.words.len) {
                    return self.words[self.index];
                } else {
                    return null;
                }
            }

            /// 次の要素を取得します。
            pub fn next(self: *Iterator) ?Word {
                if (self.index < self.words.len) {
                    const res = self.words[self.index];
                    self.index += 1;
                    return res;
                } else {
                    return null;
                }
            }
        };

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

        /// 式を解析して実行する関数。
        /// 入力は文字列のポインタで、アロケータを使用してメモリを管理します。
        /// この関数は、式を解析し、結果の `Expression` を返します。
        pub fn executes(self: *Self, input: *const String) !*Expression {
            // 入力文字列を単語に分割します
            const words = try LexicalAnalysis.splitWords(input, self.allocator);
            defer self.allocator.free(words);

            // 単語のイテレータを作成します
            var iter = Iterator{
                .words = words,
                .index = 0,
            };

            // 解析を開始します
            return self.logicalParser(&iter);
        }

        /// 式のクリア関数
        fn resetExpression(_: *Expression) void {}

        /// 式の初期化関数
        fn initExpression(_: Allocator, _: *Expression, _: anytype) !void {}

        /// 式の破棄関数
        fn deinitExpression(_: Allocator, _: *Expression) void {}

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

        fn logicalParser(self: *Self, iter: *Iterator) !*Expression {
            var left = try self.comparisonParser(iter);
            while (iter.peek()) |word| {
                if (word.kind == .AndOperator or word.kind == .OrOperator) {
                    _ = iter.next();
                    const right = try self.comparisonParser(iter);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        fn comparisonParser(self: *Self, iter: *Iterator) AllErrors!*Expression {
            return try self.additionOrSubtractionParser(iter);
        }

        fn additionOrSubtractionParser(self: *Self, iter: *Iterator) AllErrors!*Expression {
            var left = try self.multiplyOrDevisionParser(iter);
            while (iter.peek()) |word| {
                if (word.kind == .Plus or word.kind == .Minus) {
                    _ = iter.next();
                    const right = try self.multiplyOrDevisionParser(iter);
                    const expr = self.expr_store.get({}) catch return ParserError.OutOfMemoryExpression;
                    expr.* = .{ .parser = self, .data = .{ .BinaryExpress = .{ .kind = word.kind, .left = left, .right = right } } };
                    left = expr;
                } else {
                    break;
                }
            }
            return left;
        }

        fn multiplyOrDevisionParser(self: *Self, iter: *Iterator) AllErrors!*Expression {
            var left = try self.parseFactor(iter);
            while (iter.peek()) |word| {
                if (word.kind == .Multiply or word.kind == .Devision) {
                    _ = iter.next();
                    const right = try self.parseFactor(iter);
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
        fn parseFactor(self: *Self, iter: *Iterator) AllErrors!*Expression {
            if (iter.peek()) |word| {
                switch (word.kind) {
                    .LeftParen => {
                        const expr = try self.parseParen(iter);
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
                        expr.* = .{ .parser = self, .data = .{ .StringExpress = try self.parseStringLiteral(word.str.raw()) } };
                        return expr;
                    },
                    .Plus, .Minus, .Not => {
                        _ = iter.next();
                        const nextExpr = try self.parseFactor(iter);
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
        fn parseStringLiteral(self: *Self, str: []const u8) AllErrors!*String {
            const buf = self.allocator.alloc(u8, str.len) catch return ParserError.OutOfMemoryExpression;
            defer self.allocator.free(buf);

            const quote = str[0];
            var src_ptr = str.ptr + 1; // クォートの次の文字から開始
            var dest_ptr = buf.ptr;
            while (@intFromPtr(src_ptr) < @intFromPtr(str.ptr + str.len - 1)) {
                if (src_ptr[0] == quote) {
                    // クォートが閉じられた場合、ループを終了
                    src_ptr += 1;
                    break;
                } else if (src_ptr[0] == '\\') {
                    // エスケープシーケンスを処理
                    src_ptr += 1;
                    if (@intFromPtr(src_ptr) < @intFromPtr(str.ptr + str.len - 1)) {
                        switch (src_ptr[0]) {
                            'n' => dest_ptr[0] = '\n',
                            't' => dest_ptr[0] = '\t',
                            '\\' => dest_ptr[0] = '\\',
                            '"' => dest_ptr[0] = '"',
                            '\'' => dest_ptr[0] = '\'',
                            else => dest_ptr[0] = src_ptr[0],
                        }
                        dest_ptr += 1;
                        src_ptr += 1;
                    } else {
                        return ParserError.EvaluationFailed;
                    }
                } else {
                    dest_ptr[0] = src_ptr[0];
                    dest_ptr += 1;
                    src_ptr += 1;
                }
            }
            return self.string_store.get(.{ buf, @intFromPtr(dest_ptr) - @intFromPtr(buf.ptr) }) catch return ParserError.OutOfMemoryString;
        }

        /// 括弧で囲まれた式を解析します。
        /// `self` は自身のパーサーインスタンスで、`iter` は単語のイテレータです。
        /// この関数は、左括弧が見つかった場合に括弧内の式を解析し、結果の `Expression` を返します。
        /// もし左括弧が見つからなかった場合は、論理式の解析を行います。
        fn parseParen(self: *Self, iter: *Iterator) AllErrors!*Expression {
            if (iter.peek()) |word| {
                if (word.kind == .LeftParen) {
                    _ = iter.next();
                    return try self.parenBlockParser(.LeftParen, .RightParen, iter, logicalParser);
                } else {
                    return try self.logicalParser(iter);
                }
            }
            return error.InvalidExpression;
        }

        /// 括弧で囲まれたブロックを解析します。
        /// `LParen` と `RParen` は、左括弧と右括弧の種類を指定します。
        /// `next_parser` は、括弧内の式を解析するための次のパーサー関数です。
        /// この関数は、括弧内の式を解析し、結果の `Expression` を返します。
        fn parenBlockParser(self: *Self, comptime LParen: WordType, comptime RParen: WordType, iter: *Iterator, next_parser: fn (self: *Self, iter: *Iterator) AllErrors!*Expression) AllErrors!*Expression {
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
            var in_iter = Iterator{ .words = iter.words[start..end], .index = 0 };
            expr.* = .{ .parser = self, .data = .{ .ParenExpress = .{ .inner = try next_parser(self, &in_iter) } } };
            return expr;
        }

        /// 式の定義
        pub const Expression = struct {
            parser: *Self,

            data: union(enum) {
                ParenExpress: struct { inner: *Expression },
                BinaryExpress: struct { kind: WordType, left: *Expression, right: *Expression },
                UnaryExpress: struct { kind: WordType, expr: *Expression },
                NumberExpress: f64,
                StringExpress: *String,
                BooleanExpress: bool,
            },

            pub fn get(self: *const Expression) Value {
                return switch (self.*.data) {
                    .ParenExpress => |expr| expr.inner.get(),
                    .BinaryExpress => |expr| byblk: {
                        const leftValue = expr.left.get();
                        const rightValue = expr.right.get();
                        break :byblk switch (expr.kind) {
                            .Plus => switch (leftValue) {
                                .Number => switch (rightValue) {
                                    .Number => .{ .Number = leftValue.Number + rightValue.Number },
                                    .String => .{ .Error = error.InvalidExpression },
                                    else => .{ .Error = error.InvalidExpression },
                                },
                                .String => switch (rightValue) {
                                    .Number => .{ .Error = error.InvalidExpression },
                                    .String => self.concat(leftValue.String, rightValue.String),
                                    else => .{ .Error = error.InvalidExpression },
                                },
                                else => .{ .Error = error.InvalidExpression },
                            },
                            .Minus => .{ .Number = leftValue.Number - rightValue.Number },
                            .Multiply => .{ .Number = leftValue.Number * rightValue.Number },
                            .Devision => if (rightValue.Number != 0) .{ .Number = leftValue.Number / rightValue.Number } else .{ .Error = error.InvalidExpression },
                            .AndOperator => switch (leftValue) {
                                .Boolean => switch (rightValue) {
                                    .Boolean => .{ .Boolean = leftValue.Boolean and rightValue.Boolean },
                                    else => .{ .Error = error.InvalidExpression },
                                },
                                else => .{ .Error = error.InvalidExpression },
                            },
                            .OrOperator => switch (leftValue) {
                                .Boolean => switch (rightValue) {
                                    .Boolean => .{ .Boolean = leftValue.Boolean or rightValue.Boolean },
                                    else => .{ .Error = error.InvalidExpression },
                                },
                                else => .{ .Error = error.InvalidExpression },
                            },
                            .XorOperator => switch (leftValue) {
                                .Boolean => switch (rightValue) {
                                    .Boolean => .{ .Error = error.InvalidExpression },
                                    else => .{ .Error = error.InvalidExpression },
                                },
                                else => .{ .Error = error.InvalidExpression },
                            },
                            else => .{ .Error = error.InvalidExpression },
                        };
                    },
                    .UnaryExpress => |expr| unblk: {
                        break :unblk switch (expr.kind) {
                            .Plus => .{ .Number = expr.expr.data.NumberExpress },
                            .Minus => .{ .Number = -expr.expr.data.NumberExpress },
                            .Not => .{ .Error = error.InvalidExpression },
                            else => .{ .Error = error.InvalidExpression },
                        };
                    },
                    .NumberExpress => .{ .Number = self.data.NumberExpress },
                    .StringExpress => |str| .{ .String = str },
                    .BooleanExpress => |bol| .{ .Boolean = bol },
                };
            }

            fn concat(self: *const Expression, left: *String, right: *String) Value {
                const res = left.concat(self.parser.allocator, right) catch return .{ .Error = AllErrors.OutOfMemoryString };
                const tmp: *String = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return .{ .Error = AllErrors.OutOfMemoryString };
                tmp.* = res;
                return .{ .String = tmp };
            }
        };

        pub const Value = union(enum) {
            Error: AllErrors,
            Number: f64,
            String: *String,
            Boolean: bool,
            pub fn deinit(self: *Value) void {
                switch (self.*) {
                    .String => |s| s.deinit(),
                    else => {},
                }
            }
        };
    };
}

test "string literal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp3 = String.newAllSlice("'abcd' + 'efgh'");
    const expr3 = try parser.executes(&inp3);
    try testing.expectEqualStrings("abcdefgh", expr3.get().String.raw());

    const inp1 = String.newAllSlice("'あいうえお'");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqualStrings("あいうえお", expr1.get().String.raw());

    const inp2 = String.newAllSlice("'あい\\'うえお'");
    const expr2 = try parser.executes(&inp2);
    try testing.expectEqualStrings("あい'うえお", expr2.get().String.raw());
}

test "logcal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("true and false");
    const expr1 = try parser.executes(&inp1);
    try testing.expect(expr1.get().Boolean == false);

    const inp2 = String.newAllSlice("true xor false");
    const expr2 = try parser.executes(&inp2);
    try testing.expect(expr2.get().Boolean == true);

    //const inp3 = String.newAllSlice("false or true");
    //const expr3 = try parser.executes(&inp3);
    //try testing.expect(expr3.get().Boolean == true);
}

test "parseParen test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("(10 + 2) * 3");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqual(36, expr1.get().Number);

    const inp2 = String.newAllSlice("((5 - 3) + 2) / 2");
    const expr2 = try parser.executes(&inp2);
    try testing.expectEqual(2, expr2.get().Number);
}

test "additionOrSubtraction test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("10 / 2 + 2 - 7");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqual(0, expr1.get().Number);
}

test "multiplyOrDevision test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("12.5 * 2.0 / 5.0");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqual(5, expr1.get().Number);
}

test "factor test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("12345.6");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqual(12345.6, expr1.get().Number);

    const inp2 = String.newAllSlice("+123.45");
    const expr2 = try parser.executes(&inp2);
    try testing.expectEqual(123.45, expr2.get().Number);

    const inp3 = String.newAllSlice("-123.45");
    const expr3 = try parser.executes(&inp3);
    try testing.expectEqual(-123.45, expr3.get().Number);

    const inp4 = String.newAllSlice("1_23.45");
    const expr4 = try parser.executes(&inp4);
    try testing.expectEqual(123.45, expr4.get().Number);

    const inp5 = String.newAllSlice("true");
    const expr5 = try parser.executes(&inp5);
    try testing.expect(expr5.get().Boolean == true);

    const inp6 = String.newAllSlice("false");
    const expr6 = try parser.executes(&inp6);
    try testing.expect(expr6.get().Boolean == false);
}
