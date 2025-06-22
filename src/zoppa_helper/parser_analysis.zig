///! parser_analysis.zig
///! 式解析を行うモジュール
///! このモジュールは、文字列から式を解析し、結果を `ParseAnswer` として返します。
const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("strings/string.zig").String;
const Lexical = @import("lexical_analysis.zig");
const Iterator = @import("analysis_iterator.zig").AnalysisIterator;
const VariableEnv = @import("variable_environment.zig").VariableEnvironment;
const ParserError = @import("analysis_error.zig").ParserError;
const Errors = @import("analysis_error.zig").AnalysisErrors;
const VariableError = @import("analysis_error.zig").VariableError;
const ExpressionStore = @import("analysis_expression.zig").ExpressionStore;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Executes = @import("parser_execute.zig");
const Embedded = @import("parser_embedded.zig");
const Value = @import("analisys_value.zig").AnalysisValue;

/// 解析結果の構造体
/// 解析された式の結果を格納するための構造体です。
pub const ParseAnswer = struct {
    /// アロケータ
    allocator: Allocator,

    /// 入力文字列
    input: String,

    /// 式のストア
    expr_store: ExpressionStore,

    /// ルートの式
    root_expr: *const Expression,

    /// 取得した値
    value: Value,

    /// 解析結果の初期化を行います。
    /// この関数は、アロケータ、入力文字列、式ストア、ルートの式を受け取り、解析結果の構造体を初期化します。
    pub fn init(allocator: Allocator, input: String, expr_store: ExpressionStore, root_expr: *const Expression) ParseAnswer {
        return ParseAnswer{
            .allocator = allocator,
            .input = input,
            .expr_store = expr_store,
            .root_expr = root_expr,
            .value = Value{ .Number = 0 },
        };
    }

    /// 解析結果を解放します。
    pub fn deinit(self: *ParseAnswer) void {
        self.input.deinit();
        self.expr_store.deinit();
        self.value.deinit(self.allocator);
    }

    /// 変数環境を使用して、ルートの式を評価し、値を取得します。
    pub fn get(self: *ParseAnswer, variables: *VariableEnv) Errors!Value {
        self.value.deinit(self.allocator);

        // 変数環境をクローンして、階層を追加します
        // これにより、元の変数環境を変更せずに評価が可能になります
        var cloned_env = variables.clone() catch return VariableError.OutOfMemoryVariables;
        defer cloned_env.deinit();
        cloned_env.addHierarchy() catch return VariableError.OutOfMemoryVariables;
        defer cloned_env.removeHierarchy();

        // ルートの式を評価して値を取得します
        self.value = try self.root_expr.get(self.allocator, &cloned_env);
        return self.value;
    }
};

/// リテラル文字列から式解析を実行します。
/// この関数は、リテラル文字列を受け取り、式解析を実行します。
/// 解析結果は `ParseAnswer` として返されます。
pub fn executesFromLiteral(allocator: Allocator, input: []const u8) Errors!ParseAnswer {
    const input_str = String.newString(allocator, input) catch return ParserError.OutOfMemoryString;
    return innerExecutes(allocator, input_str);
}

/// 文字列から式解析を実行します。
/// この関数は、文字列を受け取り、式解析を実行します。
/// 解析結果は `ParseAnswer` として返されます。
pub fn executes(allocator: Allocator, input: *const String) Errors!ParseAnswer {
    const input_str = String.newString(allocator, input.raw()) catch return ParserError.OutOfMemoryString;
    return innerExecutes(allocator, input_str);
}

/// 文字列から式解析を実行します（内部用）
fn innerExecutes(allocator: Allocator, input: String) Errors!ParseAnswer {
    // 入力文字列を単語に分割します
    const words = Lexical.splitWords(allocator, &input) catch |err| {
        input.deinit();
        return err;
    };
    defer allocator.free(words);

    // 単語のイテレーターを作成します
    var iter = Iterator(Lexical.Word).init(words);

    // 式の解析を実行します
    var expr_store: ExpressionStore = ExpressionStore.init(allocator) catch return ParserError.OutOfMemoryExpression;
    const expr = Executes.ternaryOperatorParser(allocator, &expr_store, &iter) catch |err| {
        input.deinit();
        expr_store.deinit();
        return err;
    };

    // 残っている単語がある場合は、無効な式とみなします
    if (iter.hasNext()) {
        input.deinit();
        expr_store.deinit();
        return ParserError.InvalidExpression;
    }

    // 解析結果を返します
    return ParseAnswer.init(allocator, input, expr_store, expr);
}

/// 文字列から式解析を実行します（内部用）
pub fn directExecutes(allocator: Allocator, expr_store: *ExpressionStore, input: *const String) ParserError!*Expression {
    // 入力文字列を単語に分割します
    const words = Lexical.splitWords(allocator, input) catch return ParserError.OutOfMemoryString;
    defer allocator.free(words);

    // 単語のイテレーターを作成します
    var iter = Iterator(Lexical.Word).init(words);

    return Executes.ternaryOperatorParser(allocator, expr_store, &iter);
}

/// リテラル文字列から埋め込み式解析を行います。
/// この関数は、リテラル文字列を受け取り、埋め込み式解析を行います。
/// 解析結果は `ParseAnswer` として返されます。
pub fn translateFromLiteral(allocator: Allocator, input: []const u8) Errors!ParseAnswer {
    const input_str = String.newString(allocator, input) catch return ParserError.OutOfMemoryString;
    return innerTranslate(allocator, input_str);
}

/// 文字列から埋め込み式解析を行います。
/// この関数は、文字列を受け取り、埋め込み式解析を行います。
/// 解析結果は `ParseAnswer` として返されます。
pub fn translate(allocator: Allocator, input: *const String) Errors!ParseAnswer {
    const input_str = String.newString(allocator, input.raw()) catch return ParserError.OutOfMemoryString;
    return innerTranslate(allocator, input_str);
}

/// 文字列から埋め込み式解析を行います（内部用）
/// この関数は、文字列を受け取り、埋め込み式解析を行います。
/// 解析結果は `ParseAnswer` として返されます。
fn innerTranslate(allocator: Allocator, input: String) Errors!ParseAnswer {
    // 入力文字列を埋め込み式、非埋め込み式に分割します
    const embeddeds = Lexical.splitEmbeddedText(allocator, &input) catch |err| {
        input.deinit();
        return err;
    };
    defer allocator.free(embeddeds);

    // 埋め込み式のイテレーターを作成します
    var iter = Iterator(Lexical.EmbeddedText).init(embeddeds);

    // 式の解析を実行します
    var expr_store: ExpressionStore = ExpressionStore.init(allocator) catch return ParserError.OutOfMemoryExpression;
    const expr = Embedded.embeddedTextParser(allocator, &expr_store, &iter) catch |err| {
        input.deinit();
        expr_store.deinit();
        return err;
    };

    // 残っている単語がある場合は、無効な式とみなします
    if (iter.hasNext()) {
        input.deinit();
        expr_store.deinit();
        return ParserError.InvalidExpression;
    }

    // 解析結果を返します
    return ParseAnswer.init(allocator, input, expr_store, expr);
}

test "executesFromLiteral test" {
    const allocator = std.testing.allocator;
    var result = try executesFromLiteral(allocator, "x + y - z");
    defer result.deinit();
}

test "executes test" {
    const allocator = std.testing.allocator;
    const input_str = String.newAllSlice("a * b + c");
    defer input_str.deinit();

    var result = try executes(allocator, &input_str);
    defer result.deinit();
}
