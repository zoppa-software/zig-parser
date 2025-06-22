///! variable_environment.zig
///! 変数管理階層を提供します。
///! 変数の登録、取得、削除を行います。
///! 変数の階層を追加、削除することも可能です。
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const Store = @import("stores/store.zig").Store;
const BTree = @import("stores/btree.zig").BTree;
const BTreeError = @import("stores/btree.zig").BTreeError;
const VariableError = @import("analysis_error.zig").VariableError;
const Expression = @import("analysis_expression.zig").AnalysisExpression;

/// 変数管理階層を表す構造体です。
/// 変数の登録、取得、削除を行います。
pub const VariableEnvironment = struct {
    // アロケータ
    allocator: Allocator,

    // 変数リスト
    hierarchy: ArrayList(Variables),

    // 文字列のストア
    string_store: Store(String, 32, initString, deinitString),

    /// 変数管理階層の初期化を行います。
    pub fn init(alloc: Allocator) !VariableEnvironment {
        // 変数管理の生成
        const cur = try Variables.init(alloc);

        // 最初の変数管理階層の追加
        var hie = ArrayList(Variables).init(alloc);
        try hie.append(cur);

        return VariableEnvironment{
            .allocator = alloc,
            .hierarchy = hie,
            .string_store = try Store(String, 32, initString, deinitString).init(alloc),
        };
    }

    /// 変数管理階層のクローンを作成します。
    /// 変数の値は参照カウントされます。
    pub fn clone(self: *const VariableEnvironment) !VariableEnvironment {
        var new_env = try VariableEnvironment.init(self.allocator);
        for (self.hierarchy.items) |*v| {
            // 新しい変数管理を作成
            var new_vars = try Variables.init(self.allocator);

            // 変数管理のイテレータを取得
            var iter = try v.variable.iterate();
            defer iter.deinit();

            // 変数をクローンして新しい変数管理に追加
            while (iter.next()) |pair| {
                if (pair.key) |key| {
                    if (pair.value) |value| {
                        try new_vars.regist(key, value);
                    }
                }
            }
            // 新しい変数管理を新しい階層に追加
            try new_env.hierarchy.append(new_vars);
        }
        return new_env;
    }

    /// 変数管理階層の解放を行います。
    pub fn deinit(self: *VariableEnvironment) void {
        for (self.hierarchy.items) |*v| {
            v.deinit();
        }
        self.hierarchy.deinit();

        self.string_store.deinit();
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *VariableEnvironment, key: *const String, value: *const Expression) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, value);
    }

    /// 変数を取得します。
    /// 変数が存在しない場合は、`NotFound`のエラーを返します。
    pub fn getExpr(self: *VariableEnvironment, key: *const String) !*const Expression {
        var lv = self.hierarchy.items.len;
        while (lv > 0) : (lv -= 1) {
            const res = self.hierarchy.items[lv - 1].getExpr(key) catch |err| {
                if (err != VariableError.RetrievalFailed) {
                    return err;
                }
                continue;
            };
            return res;
        }
        return VariableError.NotFound;
    }

    /// 変数を削除します。
    /// 変数が存在しない場合は、何もしません。
    pub fn unregist(self: *VariableEnvironment, key: *const String) !void {
        try self.hierarchy.items[self.hierarchy.items.len - 1].unregist(key);
    }

    /// 変数の階層を追加します。
    pub fn addHierarchy(self: *VariableEnvironment) !void {
        const new_vars = try Variables.init(self.allocator);
        try self.hierarchy.append(new_vars);
    }

    /// 変数の階層を削除します。
    pub fn removeHierarchy(self: *VariableEnvironment) void {
        if (self.hierarchy.items.len > 1) {
            var cur: Variables = self.hierarchy.pop().?;
            cur.deinit();
        }
    }
};

/// 文字列の初期化関数
fn initString(alloc: Allocator, str: *String, args: anytype) !void {
    if (args[1] > 0) {
        str.* = try String.newString(alloc, args[0][0..args[1]]);
    } else {
        str.* = String.empty;
    }
}

/// 文字列の破棄関数
fn deinitString(_: Allocator, str: *String) void {
    str.deinit();
}

/// 変数管理を行う構造体です。
const Variables = struct {
    // 変数リスト
    variable: BTree(Pair, 4, comparePair),

    // 変数情報
    pub const Pair = struct {
        key: ?*const String,
        value: ?*const Expression,
    };

    /// 変数管理の初期化を行います。
    pub fn init(alloc: Allocator) !Variables {
        return Variables{
            .variable = try BTree(Pair, 4, comparePair).init(alloc),
        };
    }

    /// 変数管理の解放を行います。
    pub fn deinit(self: *Variables) void {
        self.variable.deinit();
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *Variables, key: *const String, value: *const Expression) !void {
        const pair = Pair{ .key = key, .value = value };
        if (self.variable.search(pair)) |v| {
            v.* = pair;
        } else {
            try self.variable.insert(pair);
        }
    }

    /// 変数を取得します。
    /// 変数が存在しない場合は、nullを返します。
    pub fn getExpr(self: *Variables, key: *const String) !*const Expression {
        const pair = Pair{ .key = key, .value = null };
        if (self.variable.search(pair)) |v| {
            if (v.value) |res| {
                return res;
            }
        }
        return VariableError.RetrievalFailed;
    }

    /// 変数を削除します。
    /// 変数が存在しない場合は、何もしません。
    pub fn unregist(self: *Variables, key: *const String) !void {
        const pair = Pair{ .key = key, .value = null };
        self.variable.remove(pair) catch |err| {
            if (err != BTreeError.NotFoundToRemove) {
                return VariableError.UnregistFailed;
            }
        };
    }

    /// 変数の比較関数
    /// これはBTreeの比較関数として使用されます。
    fn comparePair(left: Pair, right: Pair) i32 {
        if (left.key == null or right.key == null) {
            return 0;
        }
        return switch (left.key.?.compare(right.key.?)) {
            .less => -1,
            .equal => 0,
            .greater => 1,
        };
    }
};

test "変数管理階層の操作" {
    const allocator = std.testing.allocator;
    var env = try VariableEnvironment.init(allocator);
    defer env.deinit();

    // 変数の登録
    const key1 = String.newAllSlice("a");
    const expr1 = Expression{ .NumberExpress = 10 };
    try env.regist(&key1, &expr1);

    const key2 = String.newAllSlice("b");
    const expr2 = Expression{ .NumberExpress = 20 };
    try env.regist(&key2, &expr2);

    // 変数の取得
    const res1 = try env.getExpr(&key1);
    try std.testing.expectEqual(&expr1, res1);

    const res2 = try env.getExpr(&key2);
    try std.testing.expectEqual(&expr2, res2);

    // 変数の削除
    try env.unregist(&key1);
    try std.testing.expectError(VariableError.NotFound, env.getExpr(&key1));

    // 変数階数の追加と削除
    try env.addHierarchy();
    const expr3 = Expression{ .NumberExpress = 30 };
    try env.regist(&key1, &expr3);
    const res3 = try env.getExpr(&key1);
    try std.testing.expectEqual(&expr3, res3);

    env.removeHierarchy();
    try std.testing.expectEqual(&expr1, res1);

    // 変数のクローン
    var cloned_env = try env.clone();
    defer cloned_env.deinit();
    const cloned_res2 = try cloned_env.getExpr(&key2);
    try std.testing.expectEqual(&expr2, cloned_res2);
    try std.testing.expectEqual(&expr2, res2);
}
