const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const AnalysisValue = @import("analysis_value.zig");
const Value = @import("analysis_value.zig").AnalysisValue;

const AllErrors = LexicalAnalysis.LexicalError || ParserAnalysis.ParserError;

/// 式の定義
pub const AnalysisExpression = struct {
    parser: *ParserAnalysis.Parser,

    /// 式の種類を表す列挙型。
    data: union(enum) {
        ListExpress: struct { exprs: []*AnalysisExpression },
        UnfoldExpress: *String,
        NoEscapeUnfoldExpress: *String,
        IfExpress: struct { exprs: []*AnalysisExpression },
        IfConditionExpress: struct { condition: *String, inner: *AnalysisExpression },
        ElseExpress: struct { inner: *AnalysisExpression },
        TernaryExpress: struct { condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression },
        ParenExpress: struct { inner: *AnalysisExpression },
        BinaryExpress: struct { kind: LexicalAnalysis.WordType, left: *AnalysisExpression, right: *AnalysisExpression },
        UnaryExpress: struct { kind: LexicalAnalysis.WordType, expr: *AnalysisExpression },
        NumberExpress: f64,
        StringExpress: *String,
        BooleanExpress: bool,
    },

    /// 式を評価して値を取得します。
    /// この関数は、式の種類に応じて適切な評価を行い、結果の値を返します。
    pub fn get(self: *const AnalysisExpression) AllErrors!Value {
        return switch (self.*.data) {
            .ListExpress => |expr| {
                var values = ArrayList(u8).init(self.parser.allocator);
                defer values.deinit();
                for (expr.exprs) |e| {
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
            .IfExpress => |expr| {
                for (expr.exprs) |e| {
                    switch (e.data) {
                        .IfConditionExpress => |con| {
                            const condition = try e.get();
                            if (condition.Boolean) {
                                return con.inner.get() catch return error.EvaluationFailed;
                            }
                        },
                        .ElseExpress => {
                            return try e.get();
                        },
                        else => {},
                    }
                }
                const tmp: *String = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return error.OutOfMemoryString;
                return .{ .String = tmp };
            },
            .IfConditionExpress => |str| {
                const expr = self.parser.executes(str.condition) catch return error.EvaluationFailed;
                const condition = try expr.get();
                return switch (condition) {
                    .Boolean => condition,
                    else => return error.EvaluationFailed,
                };
            },
            .ElseExpress => |expr| expr.inner.get(),
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

    /// 三項演算子を実行します。
    /// `expr` は三項演算子の式で、条件に応じて真の値または偽の値を返します。
    /// この関数は、三項演算子の条件を評価し、結果の値を返します。
    /// `condition` は条件式、`true_expr` は真の場合の式、`false_expr` は偽の場合の式です。
    fn executesTernary(condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression) AllErrors!Value {
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
    fn executesUnary(kind: LexicalAnalysis.WordType, expr: *AnalysisExpression) AllErrors!Value {
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
    fn executesBinary(self: *const AnalysisExpression, kind: LexicalAnalysis.WordType, left: *AnalysisExpression, right: *AnalysisExpression) AllErrors!Value {
        const leftValue = try left.get();
        const rightValue = try right.get();
        return switch (kind) {
            .Plus => AnalysisValue.additionExpression(leftValue, rightValue, AnalysisExpression, self, concat),
            .Minus => AnalysisValue.subtractionExpression(leftValue, rightValue),
            .Multiply => AnalysisValue.multiplicationExpression(leftValue, rightValue),
            .Devision => AnalysisValue.divisionExpression(leftValue, rightValue),
            .AndOperator => AnalysisValue.andExpression(leftValue, rightValue),
            .OrOperator => AnalysisValue.orExpression(leftValue, rightValue),
            .XorOperator => AnalysisValue.xorExpression(leftValue, rightValue),
            .GreaterThan => AnalysisValue.greaterExpression(leftValue, rightValue),
            .GreaterEqual => AnalysisValue.greaterEqualExpression(leftValue, rightValue),
            .LessThan => AnalysisValue.lessExpression(leftValue, rightValue),
            .LessEqual => AnalysisValue.lessEqualExpression(leftValue, rightValue),
            .Equal => AnalysisValue.equalExpression(leftValue, rightValue),
            .NotEqual => AnalysisValue.notEqualExpression(leftValue, rightValue),
            else => error.BinaryOperatorNotSupported,
        };
    }

    /// 文字列を連結します。
    /// `left` と `right` は連結する文字列で、結果の値を返します。
    /// この関数は、2つの文字列を連結し、新しい文字列を生成します。
    fn concat(self: *const AnalysisExpression, left: *String, right: *String) AllErrors!*String {
        const res = left.concat(self.parser.allocator, right) catch return error.OutOfMemoryString;
        const tmp: *String = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return error.OutOfMemoryString;
        tmp.* = res;
        return tmp;
    }
};
