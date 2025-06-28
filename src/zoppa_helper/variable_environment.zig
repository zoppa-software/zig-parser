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

/// 変数の値を表す型です。
pub const VariableValue = union(enum) {
    /// 式
    expr: *const Expression,
    /// 数値
    number: f64,
    /// 文字列
    string: *const String,
    /// 真偽値
    boolean: bool,
};

/// 変数管理階層を表す構造体です。
/// 変数の登録、取得、削除を行います。
pub const VariableEnvironment = struct {
    // アロケータ
    allocator: Allocator,

    // 変数リスト
    hierarchy: ArrayList(*Variables),

    // 文字列のストア
    string_store: Store(String, 32, initString, deinitString),

    // 変数管理のストア
    variable_store: Store(Variables, 4, initVariable, deinitVariable),

    /// 変数管理階層の初期化を行います。
    pub fn init(alloc: Allocator) !VariableEnvironment {
        var env = VariableEnvironment{
            .allocator = alloc,
            .hierarchy = try ArrayList(*Variables).initCapacity(alloc, 4),
            .string_store = try Store(String, 32, initString, deinitString).init(alloc),
            .variable_store = try Store(Variables, 4, initVariable, deinitVariable).init(alloc),
        };

        // 最初の変数管理階層の追加
        const cur = try env.variable_store.get(.{});
        try cur.init(alloc);
        try env.hierarchy.append(cur);

        return env;
    }

    // 変数管理階層のクローンを作成します。
    // 変数の値は参照カウントされます。
    //pub fn clone(self: *const VariableEnvironment) !VariableEnvironment {
    //    var new_env = try VariableEnvironment.init(self.allocator);
    //    // 新しい変数管理を作成
    //    for (self.hierarchy.items) |v| {
    //        try new_env.hierarchy.append(v);
    //    }
    //    return new_env;
    //}

    /// 変数管理階層の解放を行います。
    pub fn deinit(self: *VariableEnvironment) void {
        var iter = self.variable_store.iterate() catch {};
        while (iter.next()) |item| {
            item.deinit();
        }
        self.hierarchy.deinit();
        self.string_store.deinit();
        self.variable_store.deinit();
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *VariableEnvironment, key: *const String, value: VariableValue) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, value);
    }

    /// 式の変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn registExpr(self: *VariableEnvironment, key: *const String, value: *const Expression) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, .{ .expr = value });
    }

    /// 数値を持つ変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn registNumber(self: *VariableEnvironment, key: *const String, value: f64) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, .{ .number = value });
    }

    /// 文字列を持つ変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn registString(self: *VariableEnvironment, key: *const String, value: String) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        const regvalue = try self.string_store.get(.{ value.raw(), value.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, .{ .string = regvalue });
    }

    /// 真偽値を持つ変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn registBoolean(self: *VariableEnvironment, key: *const String, value: bool) !void {
        const regkey = try self.string_store.get(.{ key.raw(), key.raw().len });
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(regkey, .{ .boolean = value });
    }

    /// 変数を取得します。
    /// 変数が存在しない場合は、`NotFound`のエラーを返します。
    pub fn get(self: *VariableEnvironment, key: *const String) !VariableValue {
        var lv = self.hierarchy.items.len;
        while (lv > 0) : (lv -= 1) {
            const res = self.hierarchy.items[lv - 1].get(key) catch |err| {
                if (err != VariableError.NotFound) {
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

    // 変数の階層を追加します。
    pub fn addHierarchy(self: *VariableEnvironment) !void {
        const cur = try self.variable_store.get(.{});
        if (!cur.flag) {
            try cur.init(self.allocator);
        }
        try self.hierarchy.append(cur);
    }

    // 変数の階層を削除します。
    pub fn removeHierarchy(self: *VariableEnvironment) void {
        if (self.hierarchy.items.len > 1) {
            if (self.hierarchy.pop()) |current| {
                //current.variable.deinit();
                self.variable_store.pop(current) catch {};
            }
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

/// 変数管理の初期化関数（空実装）
fn initVariable(_: Allocator, _: *Variables, _: anytype) !void {}

/// 変数管理の破棄関数（空実装）
fn deinitVariable(_: Allocator, _: *Variables) void {}

/// 変数管理を行う構造体です。
const Variables = struct {
    //
    flag: bool = false,

    // 変数リスト
    variable: BTree(Pair, 4, comparePair),

    // 変数情報
    pub const Pair = struct {
        key: ?*const String,
        value: ?VariableValue,
    };

    /// 変数管理の初期化を行います。
    pub fn init(self: *Variables, alloc: Allocator) !void {
        self.flag = true;
        self.variable = try BTree(Pair, 4, comparePair).init(alloc);
    }

    /// 変数管理の解放を行います。
    pub fn deinit(self: *Variables) void {
        if (self.flag) {
            self.variable.deinit();
            self.flag = false;
        }
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *Variables, key: *const String, value: VariableValue) !void {
        const pair = Pair{ .key = key, .value = value };
        if (self.variable.search(pair)) |v| {
            v.value = pair.value;
        } else {
            try self.variable.insert(pair);
        }
    }

    /// 変数を取得します。
    pub fn get(self: *Variables, key: *const String) !VariableValue {
        const pair = Pair{ .key = key, .value = .{ .number = 0 } };
        if (self.variable.search(pair)) |v| {
            if (v.value) |value| {
                return value;
            }
        }
        return VariableError.NotFound;
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
    try env.registNumber(&key1, 10);

    const key2 = String.newAllSlice("b");
    try env.registNumber(&key2, 20);

    // 変数の取得
    const res1 = try env.get(&key1);
    try std.testing.expectEqual(10, res1.number);

    const res2 = try env.get(&key2);
    try std.testing.expectEqual(20, res2.number);

    // 変数の削除
    try env.unregist(&key1);
    try std.testing.expectError(VariableError.NotFound, env.get(&key1));
    try env.registNumber(&key1, 10);

    // 変数階数の追加と削除
    try env.addHierarchy();
    try env.registNumber(&key1, 30);
    const res3 = try env.get(&key1);
    try std.testing.expectEqual(30, res3.number);

    env.removeHierarchy();

    const res4 = try env.get(&key1);
    try std.testing.expectEqual(10, res4.number);

    // 変数のクローン
    //var cloned_env = try env.clone();
    //defer cloned_env.deinit();
    //const cloned_res2 = try cloned_env.get(&key2);
    //try std.testing.expectEqual(20, cloned_res2.number);
    //try std.testing.expectEqual(20, res2.number);
}
