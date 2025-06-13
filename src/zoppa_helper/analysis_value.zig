const std = @import("std");
const String = @import("strings/string.zig").String;

/// 式の値を表す。
/// この値は、数値、文字列、真偽値、またはエラーを含むことができます。
pub const AnalysisValue = union(enum) {
    /// 数値を表します。
    Number: f64,

    /// 文字列を表します。
    String: *const String,

    /// 真偽値を表します。
    Boolean: bool,
};
