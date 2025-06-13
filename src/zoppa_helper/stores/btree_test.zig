const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const BTree = @import("btree.zig").BTree;

fn compareI32(left: i32, right: i32) i32 {
    if (left != right) {
        return if (left < right) -1 else 1;
    }
    return 0;
}

// B木の初期化テスト
test "BTree init" {
    const allocator = std.testing.allocator;
    var tree = try BTree(i32, 1, compareI32).init(allocator);
    defer tree.node_store.deinit();

    try tree.insert(9);
    tree.print();
    try tree.insert(7);
    tree.print();
    try tree.insert(8);
    tree.print();
    try tree.insert(18);
    tree.print();
    try tree.insert(6);
    tree.print();
    try tree.insert(11);
    tree.print();
    try tree.insert(14);
    tree.print();
    try tree.insert(5);
    tree.print();
    try tree.insert(13);
    tree.print();
    try tree.insert(12);
    tree.print();
    try tree.insert(19);
    tree.print();
    try tree.insert(0);
    tree.print();
    try tree.insert(1);
    tree.print();
    try tree.insert(4);
    tree.print();
    try tree.insert(15);
    tree.print();
    try tree.insert(2);
    tree.print();
    try tree.insert(16);
    tree.print();
    try tree.insert(10);
    tree.print();
    try tree.insert(17);
    tree.print();
    try tree.insert(20);
    tree.print();

    try expect(tree.count == 20);

    try tree.clear();
}

test "BTree contains" {
    const allocator = std.testing.allocator;
    var tree = try BTree(i32, 1, compareI32).init(allocator);
    defer tree.node_store.deinit();

    try tree.insert(15);
    try tree.insert(1);
    try tree.insert(5);
    try tree.insert(13);
    try tree.insert(0);
    try tree.insert(11);
    try tree.insert(4);
    try tree.insert(6);
    try tree.insert(18);
    try tree.insert(2);
    try tree.insert(12);
    try tree.insert(10);
    try tree.insert(14);
    try tree.insert(3);
    try tree.insert(16);
    try tree.insert(17);
    try tree.insert(9);
    try tree.insert(20);
    try tree.insert(8);
    try tree.insert(19);

    // 存在する値の確認
    try expect(tree.contains(9));
    try expect(tree.contains(8));
    try expect(tree.contains(18));

    // 存在しない値の確認
    try expect(!tree.contains(7));
    try expect(!tree.contains(21));

    // 削除を試みる
    tree.print();
    try tree.remove(14);
    tree.print();
    try tree.remove(6);
    tree.print();
    try tree.remove(15);
    tree.print();
    try tree.remove(5);
    tree.print();
    try tree.remove(11);
    tree.print();
    try tree.remove(18);
    tree.print();
    try tree.remove(4);
    tree.print();
    try tree.remove(2);
    tree.print();
    try tree.remove(10);
    tree.print();
    try tree.remove(19);
    tree.print();
    try tree.remove(16);
    tree.print();
    try tree.remove(9);
    tree.print();
    try tree.remove(13);
    tree.print();
    try tree.remove(12);
    tree.print();
    try tree.remove(20);
    tree.print();
    try tree.remove(8);
    tree.print();
    try tree.remove(1);
    tree.print();
    try tree.remove(17);
    tree.print();
    try tree.remove(3);
    tree.print();
    try tree.remove(0);
    tree.print();

    try expect(tree.count == 0);
}

test "BTree getMax" {
    const allocator = std.testing.allocator;
    var tree = try BTree(i32, 1, compareI32).init(allocator);
    defer tree.node_store.deinit();

    const values = [_]i32{ 3, 11, 16, 7, 20, 18, 1, 15, 9, 5, 19, 17, 12, 8, 4, 6, 13, 14, 2, 10 };
    for (values) |value| {
        try tree.insert(value);
    }

    var max_value: i32 = 20;
    for (0..20) |_| {
        try expect(tree.getMax() == max_value);
        try expect(tree.contains(max_value));
        try tree.remove(max_value);
        max_value -= 1;
    }
}

test "BTree getMin" {
    const allocator = std.testing.allocator;
    var tree = try BTree(i32, 1, compareI32).init(allocator);
    defer tree.node_store.deinit();

    for (0..5) |_| {
        const values = [_]i32{ 17, 39, 6, 41, 12, 25, 19, 5, 1, 43, 38, 18, 8, 44, 14, 24, 27, 50, 32, 29, 47, 21, 13, 45, 49, 15, 4, 42, 16, 23, 37, 2, 7, 9, 40, 36, 3, 28, 22, 20, 46, 11, 10, 34, 35, 26, 33, 48, 30, 31 };
        for (values) |value| {
            try tree.insert(value);
        }
        try expect(tree.count == 50);

        var min_value: i32 = 1;
        for (0..30) |_| {
            std.debug.print("Min value: {d}\n", .{min_value});
            try expect(tree.getMin() == min_value);
            try expect(tree.contains(min_value));
            try tree.remove(min_value);
            tree.print();
            min_value += 1;
        }
        try expect(tree.count == 20);
        try tree.clear();
    }
}

test "BTree cover" {
    const allocator = std.testing.allocator;
    var tree = try BTree(i32, 1, compareI32).init(allocator);
    defer tree.node_store.deinit();

    const values = [_]i32{ 18, 29, 15, 17, 9, 21, 4, 5, 7, 12, 26, 20, 8, 30, 19, 14, 27, 10, 6, 22, 23, 1, 24, 3, 11, 28, 25, 16, 2, 13 };
    for (values) |value| {
        try tree.insert(value);
    }
    tree.printTree();
    try tree.remove(4);
    tree.printTree();
    try tree.remove(6);
    tree.printTree();

    try expect(tree.count == 28);
    try tree.clear();

    var tree2 = try BTree(i32, 2, compareI32).init(allocator);
    defer tree2.node_store.deinit();
    const values2 = [_]i32{ 32, 12, 38, 22, 39, 25, 1, 13, 24, 20, 23, 21, 40, 5, 2, 27, 17, 15, 33, 8, 29, 3, 7, 19, 10, 9, 26, 35, 18, 6, 34, 36, 30, 16, 31, 28, 4, 14, 11, 37 };
    for (values2) |value| {
        try tree2.insert(value);
    }

    var iter = try tree2.iterate();
    defer iter.deinit();
    tree2.printTree();
    while (iter.next()) |v| {
        std.debug.print("Iterated value: {d}\n", .{v});
    }
}
