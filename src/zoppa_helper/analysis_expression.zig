///! expression_collection.zig
///! 式のストアと解析された式の構造体を定義します。
///! このモジュールは、式の解析結果を格納し、管理するためのものです。
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const Store = @import("stores/store.zig").Store;
const Parser = @import("parser_analysis.zig");
const Lexical = @import("lexical_analysis.zig");
const Errors = @import("analysis_error.zig").AnalysisErrors;
const VariableEnv = @import("variable_environment.zig").VariableEnvironment;
const Value = @import("analisys_value.zig").AnalysisValue;
const Functions = @import("function_library.zig");

/// 式のストア
/// 式のストアは、解析された式を格納するためのストアです。
pub const ExpressionStore = Store(AnalysisExpression, 32, initExpression, deinitExpression);

/// 式の初期化関数
fn initExpression(_: Allocator, _: *AnalysisExpression, _: anytype) !void {}

/// 式の破棄関数
fn deinitExpression(alloc: Allocator, expr: *AnalysisExpression) void {
    switch (expr.*) {
        .ListExpress => |list_expr| alloc.free(list_expr.exprs),
        .VariableListExpress => |vlist_expr| alloc.free(vlist_expr),
        .IfExpress => |if_expr| alloc.free(if_expr),
        .ArrayVariableExpress => |array_expr| alloc.free(array_expr),
        .SelectExpress => |select_expr| alloc.free(select_expr),
        .FunctionArgsExpress => |func_expr| alloc.free(func_expr),
        else => {},
    }
}

/// 解析した式の構造体
pub const AnalysisExpression = union(enum) {
    ListExpress: struct { exprs: []*AnalysisExpression },
    NoneEmbeddedExpress: String,
    UnfoldExpress: *AnalysisExpression,
    NoEscapeUnfoldExpress: *AnalysisExpression,
    VariableListExpress: []*AnalysisExpression,
    VariableExpress: struct { name: String, value: *AnalysisExpression },
    IfExpress: []*AnalysisExpression,
    IfConditionExpress: struct { condition: *AnalysisExpression, inner: *AnalysisExpression },
    ElseExpress: *AnalysisExpression,
    TernaryExpress: struct { condition: *AnalysisExpression, true_expr: *AnalysisExpression, false_expr: *AnalysisExpression },
    ParenExpress: *AnalysisExpression,
    BinaryExpress: struct { kind: Lexical.WordType, left: *AnalysisExpression, right: *AnalysisExpression },
    UnaryExpress: struct { kind: Lexical.WordType, expr: *AnalysisExpression },
    NumberExpress: f64,
    StringExpress: String,
    NoEscapeStringExpress: String,
    BooleanExpress: bool,
    ArrayVariableExpress: []*AnalysisExpression,
    ArrayExpress: struct { ident: *AnalysisExpression, index: *AnalysisExpression },
    IdentifierExpress: String,
    ForExpress: struct { var_name: String, collection: *AnalysisExpression, body: *AnalysisExpression },
    SelectExpress: []*AnalysisExpression,
    SelectTopExpress: struct { expr: *AnalysisExpression, body: *AnalysisExpression },
    SelectCaseExpress: struct { expr: *AnalysisExpression, body: *AnalysisExpression },
    SelectDefaultExpress: *AnalysisExpression,
    FunctionArgsExpress: []*AnalysisExpression,
    FunctionExpress: struct { name: *AnalysisExpression, args: *AnalysisExpression },

    /// 式を評価して値を取得します。
    pub fn get(self: *const AnalysisExpression, allocator: Allocator, variables: *VariableEnv) Errors!Value {
        return switch (self.*) {
            .ListExpress => |list_expr| {
                // リスト式の評価
                var values = ArrayList(u8).init(allocator);
                defer values.deinit();
                for (list_expr.exprs) |e| {
                    const value = try e.get(allocator, variables);
                    defer value.deinit(allocator);
                    if (value.String.len() > 0) {
                        values.appendSlice(value.String.raw()) catch return Errors.OutOfMemoryString;
                    }
                }
                const res = String.newString(allocator, values.items) catch return Errors.OutOfMemoryString;
                return .{ .String = res };
            },
            .NoneEmbeddedExpress => |str| {
                // 埋め込み式なしの文字列の評価
                const res = unEscapeFromNoneEmbedded(allocator, &str) catch return Errors.OutOfMemoryString;
                return .{ .String = res };
            },
            .UnfoldExpress => |expr| {
                // 展開式の評価
                var value = try expr.get(allocator, variables);
                defer value.deinit(allocator);
                return .{ .String = value.toString(allocator) catch return Errors.EvaluationFailed };
            },
            .NoEscapeUnfoldExpress => |expr| {
                // 非エスケープ展開式の評価
                var value = try expr.get(allocator, variables);
                defer value.deinit(allocator);
                return .{ .String = value.toString(allocator) catch return Errors.EvaluationFailed };
            },
            .VariableListExpress => |vlist_expr| {
                // 変数リスト式の評価
                // 各変数の値を取得し、変数環境に登録します（get関数で）
                for (vlist_expr) |e| {
                    _ = try e.get(allocator, variables);
                }
                return .{ .String = String.empty };
            },
            .VariableExpress => |var_expr| {
                // 変数式の評価
                variables.registExpr(&var_expr.name, var_expr.value) catch return Errors.OutOfMemoryVariables;
                return .{ .String = String.empty };
            },
            .IfExpress => |if_expr| {
                // if式の評価
                // 条件式を順に評価し、最初に真となる条件の内側の式を評価します。
                // もしどの条件も真でない場合は、else式を評価します。
                for (if_expr) |expr| {
                    switch (expr.*) {
                        .IfConditionExpress => |cond_expr| {
                            // 条件式の評価
                            // 変数環境に階層を追加して、条件式の評価を行います。
                            variables.addHierarchy() catch return Errors.AddVariableHierarchyFailed;
                            defer variables.removeHierarchy();

                            // 条件式の値を取得、条件が真の場合、内側の式を評価
                            const condition_value = try cond_expr.condition.get(allocator, variables);
                            defer condition_value.deinit(allocator);
                            if (condition_value.Boolean) {
                                return try cond_expr.inner.get(allocator, variables);
                            }
                        },
                        .ElseExpress => |else_expr| {
                            // else式の評価
                            // 変数環境に階層を追加して、else式の評価を行います。
                            variables.addHierarchy() catch return Errors.AddVariableHierarchyFailed;
                            defer variables.removeHierarchy();
                            return try else_expr.get(allocator, variables);
                        },
                        else => {
                            // 他の式は無視
                            return Errors.InvalidIfStatement;
                        },
                    }
                }
                return .{ .String = String.empty };
            },
            .ForExpress => |for_expr| {
                // for式の評価
                // 変数環境に階層を追加して、for式の評価を行います。
                variables.addHierarchy() catch return Errors.AddVariableHierarchyFailed;
                defer variables.removeHierarchy();

                // コレクションの値を取得
                const collection_value = try for_expr.collection.get(allocator, variables);
                defer collection_value.deinit(allocator);

                // for式の評価
                var values = ArrayList(u8).init(allocator);
                defer values.deinit();

                // コレクションが配列であることを確認
                switch (collection_value) {
                    .Array => |arr| {
                        for (arr) |item| {
                            // 各アイテムに対して変数を登録
                            switch (item) {
                                .String => |s| {
                                    // 文字列の場合、変数に登録
                                    variables.registString(&for_expr.var_name, s) catch return Errors.OutOfMemoryVariables;
                                },
                                .Number => |n| {
                                    // 数値の場合、変数に登録
                                    variables.registNumber(&for_expr.var_name, n) catch return Errors.OutOfMemoryVariables;
                                },
                                .Boolean => |b| {
                                    // 真偽値の場合、変数に登録
                                    variables.registBoolean(&for_expr.var_name, b) catch return Errors.OutOfMemoryVariables;
                                },
                                else => return Errors.InvalidForCollection,
                            }

                            // ボディの式を評価
                            const body_value = try for_expr.body.get(allocator, variables);
                            defer body_value.deinit(allocator);

                            // ボディの評価結果を文字列に変換してバッファに追加
                            values.appendSlice(body_value.String.raw()) catch return Errors.OutOfMemoryString;
                        }
                    },
                    else => return Errors.InvalidForCollection,
                }
                return .{ .String = String.newString(allocator, values.items) catch return Errors.OutOfMemoryString };
            },
            .SelectExpress => |select_expr| {
                // select式の評価
                var values = ArrayList(u8).init(allocator);
                defer values.deinit();

                // 変数環境に階層を追加して、select式の評価を行います。
                variables.addHierarchy() catch return Errors.AddVariableHierarchyFailed;
                defer variables.removeHierarchy();

                // トップの式を評価
                const value = try select_expr[0].SelectTopExpress.expr.get(allocator, variables);
                defer value.deinit(allocator);

                // トップのラベルを取得
                const label = try select_expr[0].SelectTopExpress.body.get(allocator, variables);
                defer label.deinit(allocator);
                if (label.String.len() > 0) {
                    values.appendSlice(label.String.raw()) catch return Errors.OutOfMemoryString;
                }

                // トップレベルの式に基づいて、caseやdefaultを評価
                for (select_expr[1..]) |case_expr| {
                    switch (case_expr.*) {
                        .SelectCaseExpress => |case| {
                            // caseの値を取得
                            const case_value = try case.expr.get(allocator, variables);
                            defer case_value.deinit(allocator);

                            // トップレベルの値とcaseの値を比較
                            if (try value.equal(&case_value)) {
                                const bvalue = case.body.get(allocator, variables) catch return Errors.SelectParseFailed;
                                defer bvalue.deinit(allocator);
                                if (bvalue.String.len() > 0) {
                                    values.appendSlice(bvalue.String.raw()) catch return Errors.OutOfMemoryString;
                                }
                                break;
                            }
                        },
                        .SelectDefaultExpress => |default_case| {
                            // defaultの場合、bodyを評価
                            const dvalue = default_case.get(allocator, variables) catch return Errors.SelectParseFailed;
                            defer dvalue.deinit(allocator);
                            if (dvalue.String.len() > 0) {
                                values.appendSlice(dvalue.String.raw()) catch return Errors.OutOfMemoryString;
                            }
                            break;
                        },
                        else => return Errors.InvalidSelectExpression,
                    }
                }
                const res = String.newString(allocator, values.items) catch return Errors.OutOfMemoryString;
                return .{ .String = res };
            },
            .TernaryExpress => |ternary_expr| {
                // 三項演算子の評価
                const condition_value = try ternary_expr.condition.get(allocator, variables);
                defer condition_value.deinit(allocator);
                if (condition_value.Boolean) {
                    return try ternary_expr.true_expr.get(allocator, variables);
                } else {
                    return try ternary_expr.false_expr.get(allocator, variables);
                }
            },
            .ParenExpress => |paren_expr| paren_expr.get(allocator, variables),
            .BinaryExpress => |binary_expr| {
                // 二項演算子の評価
                const left_value = try binary_expr.left.get(allocator, variables);
                defer left_value.deinit(allocator);
                const right_value = try binary_expr.right.get(allocator, variables);
                defer right_value.deinit(allocator);
                return switch (binary_expr.kind) {
                    .Plus => left_value.add(allocator, &right_value),
                    .Minus => left_value.subtract(&right_value),
                    .Multiply => left_value.multiply(&right_value),
                    .Divide => left_value.divide(&right_value),
                    .Equal => .{ .Boolean = try left_value.equal(&right_value) },
                    .NotEqual => .{ .Boolean = try left_value.notEqual(&right_value) },
                    .LessThan => .{ .Boolean = try left_value.lessThan(&right_value) },
                    .GreaterThan => .{ .Boolean = try left_value.greaterThan(&right_value) },
                    .LessEqual => .{ .Boolean = try left_value.lessEqual(&right_value) },
                    .GreaterEqual => .{ .Boolean = try left_value.greaterEqual(&right_value) },
                    .AndOperator => .{ .Boolean = try left_value.andOperation(&right_value) },
                    .OrOperator => .{ .Boolean = try left_value.orOperation(&right_value) },
                    .XorOperator => .{ .Boolean = try left_value.xorOperation(&right_value) },
                    else => return Errors.InvalidExpression,
                };
            },
            .UnaryExpress => |unary_expr| {
                // 単項演算子の評価
                const expr_value = try unary_expr.expr.get(allocator, variables);
                defer expr_value.deinit(allocator);
                return switch (unary_expr.kind) {
                    .Plus => expr_value.unaryPlus(),
                    .Minus => expr_value.unaryMinus(),
                    .Not => expr_value.notOperation(),
                    else => return Errors.InvalidUnaryOperation,
                };
            },
            .NumberExpress => |num_expr| .{ .Number = num_expr },
            .StringExpress => |str_expr| .{ .String = try parseStringLiteral(allocator, &str_expr) },
            .NoEscapeStringExpress => |no_escape_str_expr| .{ .String = no_escape_str_expr },
            .BooleanExpress => |bool_expr| .{ .Boolean = bool_expr },
            .ArrayVariableExpress => |array_expr| {
                // 配列変数式の評価
                var values = allocator.alloc(Value, array_expr.len) catch return Errors.OutOfMemoryArray;
                for (array_expr, 0..) |expr, i| {
                    values[i] = try expr.get(allocator, variables);
                }
                return .{ .Array = values };
            },
            .ArrayExpress => |array_expr| {
                // 配列アクセス式の評価
                return try parseArrayAccessExpression(allocator, array_expr.ident, array_expr.index, variables);
            },
            .IdentifierExpress => |id_expr| {
                // 識別子式の評価
                const value = variables.get(&id_expr) catch return Errors.IdentifierParseFailed;
                return switch (value) {
                    .expr => |expr| try expr.get(allocator, variables),
                    .number => |n| .{ .Number = n },
                    .string => |s| blk: {
                        const new_s = String.newString(allocator, s.raw()) catch return Errors.OutOfMemoryString;
                        break :blk .{ .String = new_s };
                    },
                    .boolean => |b| .{ .Boolean = b },
                };
            },
            .FunctionExpress => |func_expr| {
                // 関数式の評価
                return Functions.callFunction(allocator, variables, func_expr.name, func_expr.args) catch return Errors.FunctionCallFailed;
            },
            else => return Errors.InvalidExpression,
        };
    }
};

/// 文字列リテラルを解析します。
/// `parser` は自身のパーサーインスタンスで、`str` は文字列です。
fn parseStringLiteral(allocator: Allocator, source: *const String) Errors!String {
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var iter = source.iterate();
    const quote = iter.next().?;

    // クォートの次の文字から開始
    while (iter.hasNext()) {
        const pc = iter.next();
        if (pc) |c| {
            if (c.len == 1 and c.len == quote.len and c.source[0] == quote.source[0]) {
                if (iter.peek()) |nc| {
                    if (nc.len == 1 and nc.source[0] == quote.source[0]) {
                        // クォートが連続している場合、バッファに追加
                        _ = iter.next();
                        buffer.append(nc.source[0]) catch return Errors.StringParseFailed;
                    } else {
                        // クォートが閉じられた場合、ループを終了
                        break;
                    }
                }
            } else if (c.len == 1 and c.source[0] == '\\') {
                // エスケープシーケンスを処理
                if (iter.next()) |nc| {
                    switch (nc.source[0]) {
                        'n' => buffer.append('\n') catch return Errors.StringParseFailed,
                        't' => buffer.append('\t') catch return Errors.StringParseFailed,
                        '\\' => buffer.append('\\') catch return Errors.StringParseFailed,
                        '"' => buffer.append('"') catch return Errors.StringParseFailed,
                        '\'' => buffer.append('\'') catch return Errors.StringParseFailed,
                        '{' => buffer.append('{') catch return Errors.StringParseFailed,
                        '}' => buffer.append('}') catch return Errors.StringParseFailed,
                        else => {
                            // エスケープシーケンスが不明な場合はエラー
                            return Errors.EscapeSequenceParseFailed;
                        },
                    }
                } else {
                    // エスケープシーケンスが不完全な場合はエラー
                    return Errors.EscapeSequenceParseFailed;
                }
            } else {
                // 通常の文字を追加
                buffer.appendSlice(c.source[0..c.len]) catch return Errors.StringParseFailed;
            }
        }
    }
    return String.newString(allocator, buffer.items) catch return Errors.OutOfMemoryString;
}

/// 配列アクセス式を解析します。
/// `allocator` はアロケータ、`identExpr` は識別子式、`indexExpr` はインデックス式、`variables` は変数環境です。
fn parseArrayAccessExpression(
    allocator: Allocator,
    identExpr: *const AnalysisExpression,
    indexExpr: *const AnalysisExpression,
    variables: *VariableEnv,
) Errors!Value {
    // 配列アクセス式の評価
    const ident = try identExpr.get(allocator, variables);
    defer ident.deinit(allocator);
    const index = try indexExpr.get(allocator, variables);
    defer index.deinit(allocator);

    // インデックスが数値であることを確認
    var idxnum: usize = 0;
    switch (index) {
        .Number => |n| {
            if (n < 0) {
                return Errors.ArrayIndexOutOfBounds;
            }
            idxnum = @intFromFloat(n);
        },
        else => return Errors.InvalidArrayAccess,
    }

    // 配列識別子の評価
    switch (ident) {
        .Array => |arr_value| {
            // 配列インデックスの範囲チェック
            if (idxnum >= arr_value.len) {
                return Errors.ArrayIndexOutOfBounds;
            }

            // インデックスが範囲内の場合、値を取得
            const res = arr_value[idxnum];
            return switch (res) {
                .String => |s| blk: {
                    const in_str = String.newString(allocator, s.raw()) catch return Errors.OutOfMemoryString;
                    break :blk .{ .String = in_str };
                },
                .Number => |n| .{ .Number = n },
                .Boolean => |b| .{ .Boolean = b },
                else => return Errors.InvalidArrayAccess,
            };
        },
        else => return Errors.NotAnArray,
    }
}

/// 入力文字列から波括弧をエスケープ解除します。
/// `answer` は評価結果インスタンスで、`source` は入力文字列です。
fn unEscapeFromNoneEmbedded(allocator: Allocator, source: *const String) Errors!String {
    const is_esc = blk: {
        var iter = source.iterate();
        while (iter.hasNext()) {
            if (isEscapeCharOfNoneEmbeddedText(&iter) > 0) {
                break :blk true;
            }
            _ = iter.next();
        }
        break :blk false;
    };

    if (is_esc) {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();

        // エスケープされている場合は、エスケープされた波括弧を取り除く
        var iter = source.iterate();
        while (iter.hasNext()) {
            switch (isEscapeCharOfNoneEmbeddedText(&iter)) {
                1 => {
                    _ = iter.next().?;
                    const c = iter.next().?;
                    buffer.appendSlice(c.source[0..c.len]) catch return Errors.OutOfMemoryString;
                },
                2 => {
                    _ = iter.next().?;
                    const c1 = iter.next().?;
                    const c2 = iter.next().?;
                    buffer.appendSlice(c1.source[0..c1.len]) catch return Errors.OutOfMemoryString;
                    buffer.appendSlice(c2.source[0..c2.len]) catch return Errors.OutOfMemoryString;
                },
                else => {
                    const c = iter.next().?;
                    buffer.appendSlice(c.source[0..c.len]) catch return Errors.OutOfMemoryString;
                },
            }
        }
        return String.newString(allocator, buffer.items) catch return Errors.OutOfMemoryString;
    } else {
        // エスケープされていない場合はそのまま文字列を返す
        return source.*;
    }
}

/// エスケープ文字が波括弧の埋め込みテキストの一部であるかどうかを判定します。
/// `iter` は文字列のイテレータで、エスケープ文字が波括弧の一部である場合はその長さを返します。
fn isEscapeCharOfNoneEmbeddedText(iter: *String.Iterator) usize {
    if (iter.peek()) |nc| {
        if (nc.len == 1 and nc.source[0] == '\\') {
            if (iter.skip(1)) |nc1| {
                if (nc1.len == 1 and (nc1.source[0] == '{' or nc1.source[0] == '}')) {
                    return 1;
                }
                if (iter.skip(2)) |nc2| {
                    if (nc1.len == 1 and (nc1.source[0] == '#' or nc1.source[0] == '!' or nc1.source[0] == '$') and nc2.len == 1 and nc2.source[0] == '{') {
                        return 2;
                    }
                }
            }
        }
    }
    return 0;
}
