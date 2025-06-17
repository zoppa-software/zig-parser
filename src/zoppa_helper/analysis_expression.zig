const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const ArrayList = std.ArrayList;
const LexicalAnalysis = @import("lexical_analysis.zig");
const ParserAnalysis = @import("parser_analysis.zig");
const Parser = ParserAnalysis.AnalysisParser;
const Value = @import("analysis_value.zig").AnalysisValue;
const Errors = @import("analysis_error.zig").AnalysisErrors;

/// 式の定義
pub const AnalysisExpression = struct {
    parser: *ParserAnalysis.AnalysisParser,

    /// 式の種類を表す列挙型。
    data: union(enum) {
        ListExpress: struct { exprs: []*AnalysisExpression },
        UnfoldExpress: *String,
        NoEscapeUnfoldExpress: *String,
        VariableListExpress: struct { exprs: []*AnalysisExpression },
        VariableExpress: struct { name: *String, value: *AnalysisExpression },
        IfExpress: struct { exprs: []*AnalysisExpression },
        IfConditionExpress: struct { condition: *String, inner: *AnalysisExpression },
        ElseExpress: struct { inner: *AnalysisExpression },
        TernaryExpress: struct { condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression },
        ParenExpress: struct { inner: *AnalysisExpression },
        BinaryExpress: struct { kind: LexicalAnalysis.WordType, left: *AnalysisExpression, right: *AnalysisExpression },
        UnaryExpress: struct { kind: LexicalAnalysis.WordType, expr: *AnalysisExpression },
        NumberExpress: f64,
        StringExpress: *const String,
        BooleanExpress: bool,
        ArrayExpress: struct { exprs: []*AnalysisExpression },
    },

    /// リストの式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は式のリストです。
    pub fn initListExpression(parser: *Parser, params: *ArrayList(*AnalysisExpression)) Errors!*AnalysisExpression {
        const list_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        const list_exprs = params.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
        list_expr.* = .{ .parser = parser, .data = .{ .ListExpress = .{ .exprs = list_exprs } } };
        return list_expr;
    }

    /// 展開式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は展開する文字列です。
    pub fn initUnfoldExpression(parser: *Parser, params: *String) Errors!*AnalysisExpression {
        const unfold_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        unfold_expr.* = .{ .parser = parser, .data = .{ .UnfoldExpress = params } };
        return unfold_expr;
    }

    /// 非エスケープ展開式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は展開する文字列です。
    pub fn initNoEscapeUnfoldExpression(parser: *Parser, params: *String) Errors!*AnalysisExpression {
        const no_unfold_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        no_unfold_expr.* = .{ .parser = parser, .data = .{ .NoEscapeUnfoldExpress = params } };
        return no_unfold_expr;
    }

    /// 変数リストの式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は式のリストです。
    pub fn initVariableListExpression(parser: *Parser, params: *ArrayList(*AnalysisExpression)) Errors!*AnalysisExpression {
        const variable_list_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        const list_exprs = params.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
        variable_list_expr.* = .{ .parser = parser, .data = .{ .VariableListExpress = .{ .exprs = list_exprs } } };
        return variable_list_expr;
    }

    /// 変数の式を初期化します。
    /// `parser` は解析器のインスタンス、`name` は変数名、`value` は変数の値です。
    pub fn initVariableExpression(parser: *Parser, name: *String, value: *AnalysisExpression) Errors!*AnalysisExpression {
        const variable_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        variable_expr.* = .{ .parser = parser, .data = .{ .VariableExpress = .{ .name = name, .value = value } } };
        return variable_expr;
    }

    /// IF文の式を初期化します。
    /// `parser` は解析器のインスタンス、`params` はIF文の式リストです。
    pub fn initIfExpression(parser: *Parser, params: *ArrayList(*AnalysisExpression)) Errors!*AnalysisExpression {
        const if_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        const exprs = params.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
        if_expr.* = .{ .parser = parser, .data = .{ .IfExpress = .{ .exprs = exprs } } };
        return if_expr;
    }

    /// IF条件の式を初期化します。
    /// `parser` は解析器のインスタンス、`condition` は条件式、`inner` は条件が真の場合の式です。
    pub fn initIfConditionExpression(parser: *Parser, condition: *String, inner: *AnalysisExpression) Errors!*AnalysisExpression {
        const if_condition_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        if_condition_expr.* = .{ .parser = parser, .data = .{ .IfConditionExpress = .{ .condition = condition, .inner = inner } } };
        return if_condition_expr;
    }

    /// ELSE文の式を初期化します。
    /// `parser` は解析器のインスタンス、`inner` はELSE文の式です。
    pub fn initElseExpression(parser: *Parser, inner: *AnalysisExpression) Errors!*AnalysisExpression {
        const else_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        else_expr.* = .{ .parser = parser, .data = .{ .ElseExpress = .{ .inner = inner } } };
        return else_expr;
    }

    /// 三項演算子の式を初期化します。
    /// `parser` は解析器のインスタンス、`condition` は条件式、`true_expr` は真の場合の式、`false_expr` は偽の場合の式です。
    pub fn initTernaryExpression(parser: *Parser, condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression) Errors!*AnalysisExpression {
        const ternary_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        ternary_expr.* = .{ .parser = parser, .data = .{ .TernaryExpress = .{ .condition = condition, .true_expr = true_expr, .false_expr = false_expr } } };
        return ternary_expr;
    }

    /// 括弧の式を初期化します。
    /// `parser` は解析器のインスタンス、`inner` は括弧内の式です。
    pub fn initParenExpression(parser: *Parser, inner: *AnalysisExpression) Errors!*AnalysisExpression {
        const paren_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        paren_expr.* = .{ .parser = parser, .data = .{ .ParenExpress = .{ .inner = inner } } };
        return paren_expr;
    }

    /// バイナリ式を初期化します。
    /// `parser` は解析器のインスタンス、`kind` は演算子の種類、`left` と `right` は左辺と右辺の式です。
    pub fn initBinaryExpression(parser: *Parser, kind: LexicalAnalysis.WordType, left: *AnalysisExpression, right: *AnalysisExpression) Errors!*AnalysisExpression {
        const binary_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        binary_expr.* = .{ .parser = parser, .data = .{ .BinaryExpress = .{ .kind = kind, .left = left, .right = right } } };
        return binary_expr;
    }

    /// 単項式を初期化します。
    /// `parser` は解析器のインスタンス、`kind` は演算子の種類、`expr` は対象の式です。
    pub fn initUnaryExpression(parser: *Parser, kind: LexicalAnalysis.WordType, expr: *AnalysisExpression) Errors!*AnalysisExpression {
        const unary_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        unary_expr.* = .{ .parser = parser, .data = .{ .UnaryExpress = .{ .kind = kind, .expr = expr } } };
        return unary_expr;
    }

    /// 数値の式を初期化します。
    /// `parser` は解析器のインスタンス、`value` は数値です。
    pub fn initNumberExpression(parser: *Parser, value: f64) Errors!*AnalysisExpression {
        const number_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        number_expr.* = .{ .parser = parser, .data = .{ .NumberExpress = value } };
        return number_expr;
    }

    /// 文字列の式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は式の文字列です。
    pub fn initStringExpression(parser: *Parser, params: *const String) Errors!*AnalysisExpression {
        const unfold_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        unfold_expr.* = .{ .parser = parser, .data = .{ .StringExpress = params } };
        return unfold_expr;
    }

    /// 真偽値の式を初期化します。
    /// `parser` は解析器のインスタンス、`value` は真偽値です。
    pub fn initBooleanExpression(parser: *Parser, value: bool) Errors!*AnalysisExpression {
        const boolean_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        boolean_expr.* = .{ .parser = parser, .data = .{ .BooleanExpress = value } };
        return boolean_expr;
    }

    /// 配列の式を初期化します。
    /// `parser` は解析器のインスタンス、`params` は式のリストです。
    pub fn initArrayExpression(parser: *Parser, params: *ArrayList(*AnalysisExpression)) Errors!*AnalysisExpression {
        const array_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        const exprs = params.toOwnedSlice() catch return Errors.OutOfMemoryExpression;
        array_expr.* = .{ .parser = parser, .data = .{ .ArrayExpress = .{ .exprs = exprs } } };
        return array_expr;
    }

    /// 式をクローンします。
    /// `parser` は解析器のインスタンス、`other` はクローン元の式です。
    pub fn initFromExpression(parser: *Parser, other: *const AnalysisExpression) Errors!*AnalysisExpression {
        const cloned_expr = parser.expr_store.get({}) catch return Errors.OutOfMemoryExpression;
        cloned_expr.* = other.*;
        return cloned_expr;
    }

    /// 式を評価して値を取得します。
    /// この関数は、式の種類に応じて適切な評価を行い、結果の値を返します。
    pub fn get(self: *const AnalysisExpression) Errors!Value {
        return switch (self.*.data) {
            .ListExpress => |expr| {
                var values = ArrayList(u8).init(self.parser.allocator);
                defer values.deinit();
                for (expr.exprs) |e| {
                    const value = try e.get();
                    if (value.String.len() > 0) {
                        values.appendUnalignedSlice(value.String.raw()) catch return Errors.OutOfMemoryString;
                    }
                }
                const tmp = self.parser.string_store.get(.{ values.items, values.items.len }) catch return Errors.OutOfMemoryString;
                return .{ .String = tmp };
            },
            .UnfoldExpress => |str| {
                const expr = self.parser.executes(str) catch return Errors.EvaluationFailed;
                return switch (try expr.get()) {
                    .String => |s| .{ .String = s },
                    .Number => |n| {
                        const msg = std.fmt.allocPrint(self.parser.allocator, "{d}", .{n}) catch return Errors.OutOfMemoryString;
                        defer self.parser.allocator.free(msg);
                        return .{ .String = self.parser.string_store.get(.{ msg, msg.len }) catch return Errors.OutOfMemoryString };
                    },
                    else => return Errors.EvaluationFailed,
                };
            },
            .NoEscapeUnfoldExpress => |str| .{ .String = str },
            .VariableListExpress => |expr| {
                for (expr.exprs) |e| {
                    _ = try e.get();
                }
                return .{ .String = &String.empty };
            },
            .VariableExpress => |v| {
                switch (try v.value.get()) {
                    .Number => |n| self.parser.setNumberVariable(v.name, n) catch return Errors.OutOfMemoryExpression,
                    .String => |s| self.parser.setStringVariable(v.name, s) catch return Errors.OutOfMemoryExpression,
                    .Boolean => |b| self.parser.setBooleanVariable(v.name, b) catch return Errors.OutOfMemoryExpression,
                    //else => return Errors.InvalidExpression,
                }
                return .{ .String = &String.empty };
            },
            .IfExpress => |expr| {
                for (expr.exprs) |e| {
                    switch (e.data) {
                        .IfConditionExpress => |con| {
                            const condition = try e.get();
                            if (condition.Boolean) {
                                return con.inner.get() catch return Errors.EvaluationFailed;
                            }
                        },
                        .ElseExpress => {
                            return try e.get();
                        },
                        else => {},
                    }
                }
                return .{ .String = &String.empty };
            },
            .IfConditionExpress => |str| {
                const expr = self.parser.executes(str.condition) catch return Errors.EvaluationFailed;
                const condition = try expr.get();
                return switch (condition) {
                    .Boolean => condition,
                    else => return Errors.EvaluationFailed,
                };
            },
            .ElseExpress => |expr| expr.inner.get(),
            .TernaryExpress => |expr| executesTernary(expr.condition, expr.true_expr, expr.false_expr),
            .ParenExpress => |expr| expr.inner.get(),
            .BinaryExpress => |expr| self.executesBinary(expr.kind, expr.left, expr.right),
            .UnaryExpress => |expr| executesUnary(expr.kind, expr.expr),
            .NumberExpress => .{ .Number = self.data.NumberExpress },
            .StringExpress => |str| .{ .String = str },
            .BooleanExpress => |bol| .{ .Boolean = bol },
            .ArrayExpress => |_| {
                return Errors.OutOfMemoryExpression; // TODO: Implement array expression evaluation
                //var values = ArrayList(Value).init(self.parser.allocator);
                //defer values.deinit();
                //for (expr.exprs) |e| {
                //    const value = try e.get();
                //    values.append(value) catch return Errors.OutOfMemoryExpression;
                //}
                //return .{ .Array = self.parser.expr_store.get(.{ values.items, values.items.len }) catch return Errors.OutOfMemoryExpression };
            },
        };
    }

    /// 三項演算子を実行します。
    /// `expr` は三項演算子の式で、条件に応じて真の値または偽の値を返します。
    /// この関数は、三項演算子の条件を評価し、結果の値を返します。
    /// `condition` は条件式、`true_expr` は真の場合の式、`false_expr` は偽の場合の式です。
    fn executesTernary(condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression) Errors!Value {
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
    fn executesUnary(kind: LexicalAnalysis.WordType, expr: *AnalysisExpression) Errors!Value {
        const value = try expr.get();
        return switch (kind) {
            .Plus => switch (value) {
                .Number => .{ .Number = value.Number },
                else => Errors.UnaryOperatorNotSupported,
            },
            .Minus => switch (value) {
                .Number => .{ .Number = -value.Number },
                else => Errors.UnaryOperatorNotSupported,
            },
            .Not => switch (value) {
                .Boolean => .{ .Boolean = !value.Boolean },
                else => Errors.UnaryOperatorNotSupported,
            },
            else => Errors.UnaryOperatorNotSupported,
        };
    }

    /// バイナリ式を実行します。
    /// `kind` は演算子の種類で、`left` と `right` は左辺と右辺の式です。
    /// この関数は、バイナリ演算子を適用し、結果の値を返します。
    fn executesBinary(self: *const AnalysisExpression, kind: LexicalAnalysis.WordType, left: *AnalysisExpression, right: *AnalysisExpression) Errors!Value {
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
            else => Errors.BinaryOperatorNotSupported,
        };
    }

    /// より大きいを実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn greaterExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => blk: {
                    const res = @abs(leftValue.Number - rightValue.Number);
                    break :blk .{ .Boolean = leftValue.Number > rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
                },
                else => Errors.GreaterOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.greater },
                else => Errors.GreaterOperatorNotSupported,
            },
            else => Errors.GreaterOperatorNotSupported,
        };
    }

    /// 以上を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn greaterEqualExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => blk: {
                    const res = @abs(leftValue.Number - rightValue.Number);
                    break :blk .{ .Boolean = leftValue.Number > rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
                },
                else => Errors.GreaterEqualOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.less },
                else => Errors.GreaterEqualOperatorNotSupported,
            },
            else => Errors.GreaterEqualOperatorNotSupported,
        };
    }

    /// より小さいを実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn lessExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => blk: {
                    const res = @abs(leftValue.Number - rightValue.Number);
                    break :blk .{ .Boolean = leftValue.Number < rightValue.Number and res > std.math.nextAfter(f64, 0, 1) };
                },
                else => Errors.LessOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.less },
                else => Errors.LessOperatorNotSupported,
            },
            else => Errors.LessOperatorNotSupported,
        };
    }

    /// 以下を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn lessEqualExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => blk: {
                    const res = @abs(leftValue.Number - rightValue.Number);
                    break :blk .{ .Boolean = leftValue.Number < rightValue.Number or res <= std.math.nextAfter(f64, 0, 1) };
                },
                else => Errors.LessEqualOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.greater },
                else => Errors.LessEqualOperatorNotSupported,
            },
            else => Errors.LessEqualOperatorNotSupported,
        };
    }

    /// 等価演算子を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn equalExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) <= std.math.nextAfter(f64, 0, 1) },
                else => Errors.EqualOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) == String.Order.equal },
                else => Errors.EqualOperatorNotSupported,
            },
            .Boolean => switch (rightValue) {
                .Boolean => .{ .Boolean = leftValue.Boolean == rightValue.Boolean },
                else => Errors.EqualOperatorNotSupported,
            },
        };
    }

    /// 不等号を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn notEqualExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => .{ .Boolean = @abs(leftValue.Number - rightValue.Number) > std.math.nextAfter(f64, 0, 1) },
                else => Errors.NotEqualOperatorNotSupported,
            },
            .String => switch (rightValue) {
                .String => .{ .Boolean = leftValue.String.compare(rightValue.String) != String.Order.equal },
                else => Errors.NotEqualOperatorNotSupported,
            },
            .Boolean => switch (rightValue) {
                .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
                else => Errors.NotEqualOperatorNotSupported,
            },
        };
    }

    /// 数値、文字の加算を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn additionExpression(self: *const AnalysisExpression, leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => .{ .Number = leftValue.Number + rightValue.Number },
                else => Errors.CalculationFailed,
            },
            .String => switch (rightValue) {
                .String => .{ .String = try self.concat(leftValue.String, rightValue.String) },
                else => Errors.CalculationFailed,
            },
            else => Errors.CalculationFailed,
        };
    }

    /// 文字列を連結します。
    /// `left` と `right` は連結する文字列で、結果の値を返します。
    /// この関数は、2つの文字列を連結し、新しい文字列を生成します。
    fn concat(self: *const AnalysisExpression, left: *const String, right: *const String) Errors!*String {
        const res = self.parser.string_store.get(.{ [_]u8{}, 0 }) catch return Errors.OutOfMemoryString;
        res.* = left.concat(self.parser.allocator, right) catch return Errors.OutOfMemoryString;
        return res;
    }

    /// 数値の減算を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn subtractionExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => .{ .Number = leftValue.Number - rightValue.Number },
                else => Errors.CalculationFailed,
            },
            else => Errors.CalculationFailed,
        };
    }

    /// 数値の乗算を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn multiplicationExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => .{ .Number = leftValue.Number * rightValue.Number },
                else => Errors.CalculationFailed,
            },
            else => Errors.CalculationFailed,
        };
    }

    /// 数値の除算を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn divisionExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Number => switch (rightValue) {
                .Number => if (rightValue.Number != 0) .{ .Number = leftValue.Number / rightValue.Number } else Errors.InvalidExpression,
                else => Errors.CalculationFailed,
            },
            else => Errors.CalculationFailed,
        };
    }

    /// AND演算子を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn andExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Boolean => switch (rightValue) {
                .Boolean => .{ .Boolean = leftValue.Boolean and rightValue.Boolean },
                else => Errors.LogicalOperationFailed,
            },
            else => Errors.LogicalOperationFailed,
        };
    }

    /// OR演算子を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn orExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Boolean => switch (rightValue) {
                .Boolean => .{ .Boolean = leftValue.Boolean or rightValue.Boolean },
                else => Errors.LogicalOperationFailed,
            },
            else => Errors.LogicalOperationFailed,
        };
    }

    /// XOR演算を実行します。
    /// `leftValue` と `rightValue` はそれぞれ左辺と右辺の式です。
    pub fn xorExpression(leftValue: Value, rightValue: Value) Errors!Value {
        return switch (leftValue) {
            .Boolean => switch (rightValue) {
                .Boolean => .{ .Boolean = leftValue.Boolean != rightValue.Boolean },
                else => Errors.LogicalOperationFailed,
            },
            else => Errors.LogicalOperationFailed,
        };
    }
};
