const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const Store = @import("store.zig").Store;
const StoreError = @import("store.zig").StoreError;

// サンプルデータ構造
const SampleData = struct {
    id: usize,
};

fn sample_init_T(_: Allocator, item: *SampleData, args: anytype) !void {
    // 初期化処理をここに記述
    // 例えば、item.* = 0; のように初期値を設定することができます。
    item.id = args[0];
}

fn sample_deinit_T(_: Allocator, _: *SampleData) void {
    // 破棄処理をここに記述
    // 例えば、特に何もしない場合は空の関数でOKです。
}

test "Store init" {
    const allocator = std.testing.allocator;
    var store = try Store(SampleData, 4, sample_init_T, sample_deinit_T).init(allocator);
    defer store.deinit();

    const item1 = try store.get(.{1});
    const item2 = try store.get(.{2});
    const item3 = try store.get(.{3});
    const item4 = try store.get(.{4});
    const item5 = try store.get(.{5});
    const item6 = try store.get(.{6});
    const item7 = try store.get(.{7});
    const item8 = try store.get(.{8});
    const item9 = try store.get(.{9});
    const item10 = try store.get(.{10});

    try expect(item1.id == 1);
    try expect(item2.id == 2);
    try expect(item3.id == 3);
    try expect(item4.id == 4);
    try expect(item5.id == 5);
    try expect(item6.id == 6);
    try expect(item7.id == 7);
    try expect(item8.id == 8);
    try expect(item9.id == 9);
    try expect(item10.id == 10);

    try store.pop(item1);
    try store.pop(item2);
    try store.pop(item3);
    try store.pop(item4);
    try store.pop(item5);
    try store.pop(item6);
    try store.pop(item7);
    try store.pop(item8);
    try store.pop(item9);
    try store.pop(item10);

    try expect(store.cache.count == 12);
}

test "store double put" {
    const allocator = std.testing.allocator;
    var store = try Store(SampleData, 4, sample_init_T, sample_deinit_T).init(allocator);
    defer store.deinit();

    const item1 = try store.get(.{1});
    _ = try store.get(.{2});

    // アイテムを削除
    try store.pop(item1);
    store.pop(item1) catch |err| {
        // 既に削除済みのアイテムを再度削除しようとした場合、エラーが発生することを確認
        try expect(err == StoreError.PopFailed);
    };
}
