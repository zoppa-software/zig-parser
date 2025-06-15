const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = @import("strings/string.zig").String;
const BTree = @import("stores/btree.zig").BTree;
const BTreeError = @import("stores/btree.zig").BTreeError;
const Expression = @import("analysis_expression.zig").AnalysisExpression;
const Parser = @import("parser_analysis.zig").AnalysisParser;
const VariableError = @import("analysis_error.zig").VariableError;

/// 変数を管理するための構造体です。
/// 変数は、名前と式のペアとして格納されます。
/// この構造体は、変数の追加、取得、削除などの操作を提供します。
pub const AnalysisVariables = struct {
    /// 自身の型
    const Self = @This();

    // アロケータ
    allocator: Allocator,

    // 変数リスト
    variable: BTree(Pair, 4, comparePair),

    // 変数情報
    pub const Pair = struct {
        key: ?*const String,
        value: ?*const Expression,
    };

    /// 変数管理の初期化を行います。
    pub fn init(alloc: Allocator) !Self {
        return Self{
            .allocator = alloc,
            .variable = try BTree(Pair, 4, comparePair).init(alloc),
        };
    }

    /// 変数管理の解放を行います。
    pub fn deinit(self: *Self) void {
        self.variable.deinit();
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *Self, key: *const String, value: *const Expression) !void {
        const pair = Pair{ .key = key, .value = value };
        if (self.variable.search(pair)) |v| {
            v.* = pair;
        } else {
            try self.variable.insert(pair);
        }
    }

    /// 変数を取得します。
    /// 変数が存在しない場合は、nullを返します。
    pub fn getExpr(self: *Self, key: *const String) !*const Expression {
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
    pub fn unregist(self: *Self, key: *const String) !void {
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

/// 変数の階層を管理するための構造体です。
pub const AnalysisVariableHierarchy = struct {
    /// 自身の型
    const Self = @This();

    // アロケータ
    allocator: Allocator,

    // 変数リスト
    hierarchy: ArrayList(AnalysisVariables),

    /// 変数管理階層の初期化を行います。
    pub fn init(alloc: Allocator) !AnalysisVariableHierarchy {
        const cur = try AnalysisVariables.init(alloc);

        var hie = ArrayList(AnalysisVariables).init(alloc);
        try hie.append(cur);

        return AnalysisVariableHierarchy{
            .allocator = alloc,
            .hierarchy = hie,
        };
    }

    /// 変数管理階層の解放を行います。
    pub fn deinit(self: *AnalysisVariableHierarchy) void {
        for (self.hierarchy.items) |*v| {
            v.deinit();
        }
        self.hierarchy.deinit();
    }

    /// 変数を追加します。
    /// 変数が既に存在する場合は、上書きされます。
    pub fn regist(self: *Self, key: *const String, value: *const Expression) !void {
        try self.hierarchy.items[self.hierarchy.items.len - 1].regist(key, value);
    }

    /// 変数を取得します。
    /// 変数が存在しない場合は、`NotFound`のエラーを返します。
    pub fn getExpr(self: *Self, key: *const String) !*const Expression {
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
    pub fn unregist(self: *Self, key: *const String) !void {
        try self.hierarchy.items[self.hierarchy.items.len - 1].unregist(key);
    }

    /// 変数の階層を追加します。
    pub fn addHierarchy(self: *Self) !void {
        const new_vars = try AnalysisVariables.init(self.allocator);
        try self.hierarchy.append(new_vars);
    }

    /// 変数の階層を削除します。
    pub fn removeHierarchy(self: *Self) !void {
        if (self.hierarchy.items.len > 1) {
            var cur: AnalysisVariables = self.hierarchy.pop().?;
            cur.deinit();
        }
    }
};

test "variable init" {
    const allocator = std.testing.allocator;
    var vars = AnalysisVariables.init(allocator) catch unreachable;
    defer vars.deinit();

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const key1 = String.newAllSlice("x");
    const key2 = String.newAllSlice("y");
    const key3 = String.newAllSlice("z");
    const var1 = Expression{ .parser = &parser, .data = .{ .NumberExpress = 8 } };
    const var2 = Expression{ .parser = &parser, .data = .{ .NumberExpress = 12 } };
    try vars.regist(&key1, &var1);
    try vars.regist(&key2, &var2);

    // 変数の追加が成功したことを確認
    try std.testing.expect(vars.variable.count == 2);

    // 変数の取得と比較
    const ans1 = try vars.getExpr(&key1);
    try std.testing.expect((try ans1.get()).Number == 8);

    const ans2 = try vars.getExpr(&key2);
    try std.testing.expect((try ans2.get()).Number == 12);

    // 存在しない変数の取得
    _ = vars.getExpr(&key3) catch |err| {
        try std.testing.expect(err == VariableError.RetrievalFailed);
    };

    // 変数の削除
    try vars.unregist(&key1);
    try std.testing.expect(vars.variable.count == 1);
}

test "variable hierarchy init" {
    const allocator = std.testing.allocator;
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const key1 = String.newAllSlice("a");
    const key2 = String.newAllSlice("b");
    const key3 = String.newAllSlice("c");

    // 変数を追加、取得と比較
    try parser.setNumberVariable(&key1, 5);
    try parser.setNumberVariable(&key2, 10);
    const ans1 = try parser.getVariableExpression(&key1);
    try std.testing.expect((try ans1.get()).Number == 5);
    const ans2 = try parser.getVariableExpression(&key2);
    try std.testing.expect((try ans2.get()).Number == 10);

    // 階層の追加と削除
    try parser.pushVariable();
    try parser.setNumberVariable(&key2, 15);
    const ans1_1 = try parser.getVariableExpression(&key1);
    try std.testing.expect((try ans1_1.get()).Number == 5);
    const ans1_2 = try parser.getVariableExpression(&key2);
    try std.testing.expect((try ans1_2.get()).Number == 15);

    // 存在しない変数（key3）の取得時は、どの階層にも存在しない場合 VariableError.NotFound が返ることを期待
    _ = parser.getVariableExpression(&key3) catch |err| {
        try std.testing.expect(err == VariableError.NotFound);
    };

    // 階層の削除
    try parser.popVariable();
    const ans2_1 = try parser.getVariableExpression(&key1);
    try std.testing.expect((try ans2_1.get()).Number == 5);
    const ans2_2 = try parser.getVariableExpression(&key2);
    try std.testing.expect((try ans2_2.get()).Number == 10);
}
