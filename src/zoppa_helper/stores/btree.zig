const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

// https://gist.github.com/viz3/3486656

/// B木のエラー
pub const BTreeError = error{
    /// 挿入に失敗した場合のエラー
    InsertFailed,
    /// メモリ不足のエラー
    OutOfMemory,
    /// 検索の結果、存在しない
    NotFound,
    /// 同じ値が既に存在する場合のエラー
    AlreadyExists,
    /// 削除する値が存在しない場合のエラー
    NotFoundToRemove,
};

/// B木の実装
/// B木は、データを効率的に格納するためのデータ構造です。
pub fn BTree(comptime T: type, comptime M: comptime_int, comptime compare: fn (left: T, right: T) i32) type {
    return struct {
        /// 自身の型
        const Self = @This();

        /// データストア
        fn Store(comptime LT: type, comptime store_size: comptime_int) type {
            return struct {
                // アロケータ
                allocator: Allocator,
                // 削除済みリスト
                free_list: []*LT,
                // 削除済み数
                free_count: usize,
                // データの格納先
                instances: [][*]LT,

                // ストアの初期化
                pub fn init(alloc: Allocator) !@This() {
                    var res = @This(){
                        .allocator = alloc,
                        .free_list = try alloc.alloc(*LT, store_size),
                        .free_count = 0,
                        .instances = try alloc.alloc([*]LT, 0),
                    };
                    try res.createCache();
                    return res;
                }

                /// ストアを破棄します。
                pub fn deinit(self: *@This()) void {
                    self.delete_lists();
                }

                /// キャッシュを作成します。
                fn createCache(self: *@This()) !void {
                    // 実体を保持する領域を確保する
                    var new_instances = try self.allocator.alloc([*]LT, self.instances.len + 1);
                    std.mem.copyForwards([*]LT, new_instances[0..self.instances.len], self.instances);

                    // 新しいインスタンスを確保する
                    const tmp = try self.allocator.alloc(LT, store_size);
                    new_instances[new_instances.len - 1] = tmp.ptr;
                    self.allocator.free(self.instances);
                    self.instances = new_instances;

                    // サイズを変更する
                    self.free_count = store_size;
                    for (tmp, 0..) |*item, i| {
                        self.free_list[i] = item;
                    }
                }

                /// ストアの削除済みリスト、データの格納先を削除します。
                fn delete_lists(self: *@This()) void {
                    self.free_count = 0;
                    self.allocator.free(self.free_list);

                    for (self.instances) |item| {
                        self.allocator.free(item[0..store_size]);
                    }
                    self.allocator.free(self.instances);
                }

                /// ストアからオブジェクトを取得します。
                pub fn get(self: *@This()) !*LT {
                    // 削除済みリストが空の場合は、キャッシュを作成する
                    if (self.free_count <= 0) {
                        try self.createCache();
                    }

                    // 削除済みリストから取得する
                    const item = self.free_list[self.free_count - 1];

                    // 削除済みリストから削除する
                    self.free_count -= 1;
                    return item;
                }

                /// ストアにオブジェクトを返却します。
                pub fn put(self: *@This(), item: *LT) !void {
                    // もし、削除済みリストが満杯であれば、リストを拡張する
                    if (self.free_count >= self.free_list.len) {
                        // 新しい削除済みリストを確保する
                        const new_size = @min(self.instances.len * store_size, self.free_list.len + store_size);
                        const new_deleted = try self.allocator.alloc(*LT, new_size);
                        std.mem.copyForwards(*LT, new_deleted[0..self.free_list.len], self.free_list);
                        self.allocator.free(self.free_list);
                        self.free_list = new_deleted;
                    }

                    self.free_list[self.free_count] = item;
                    self.free_count += 1;
                }
            };
        }

        /// B木のノード
        const Node = struct {
            // データ数
            count: usize,
            // データ
            values: [M * 2]T,
            // 子ノードへのポインタ
            children: [M * 2 + 1]?*Node,
            // ノードの初期化
            pub fn init() Node {
                return .{
                    .count = 0,
                    .values = [1]T{std.mem.zeroes(T)} ** (M * 2),
                    .children = [1]?*Node{null} ** (M * 2 + 1),
                };
            }
        };

        /// 更新情報
        const UpdateInfo = struct {
            /// 更新する値
            value: T,
            /// ノードの更新が完了したかどうか
            done: bool,
            /// 新しいノード
            new_node: ?*Node,
        };

        /// 削除情報
        const DeleteInfo = struct {
            /// 削除する値
            value: T,
            /// 削除が完了
            deleted: bool,
            /// サイズが小さい
            under_size: bool,
        };

        // アロケータ
        allocator: Allocator,

        // ノードのストア
        node_store: Store(Node, 32),

        // B木のルートノード
        root: ?*Node = null,

        // データ数
        count: usize = 0,

        /// B木の初期化
        pub fn init(alloc: Allocator) !Self {
            return .{
                .allocator = alloc,
                .node_store = try Store(Node, 32).init(alloc),
            };
        }

        /// B木の破棄
        pub fn deinit(self: *Self) void {
            self.node_store.deinit();
        }

        /// B木に要素を挿入します。
        /// 挿入後、必要に応じてノードを分割します。
        pub fn insert(self: *Self, value: T) !void {
            // 更新する値を取得
            var update: UpdateInfo = .{
                .value = value,
                .done = false,
                .new_node = null,
            };

            // ルートノードに値を挿入する
            try self.insertIntoNode(self.root, &update);

            // ノードの分割が必要な場合は、ルートノードを更新する
            if (!update.done) {
                // 新しいノードを作成する
                const new_node = self.node_store.get() catch {
                    return BTreeError.OutOfMemory;
                };
                new_node.* = Node.init();
                new_node.values[0] = update.value;
                new_node.children[0] = self.root;
                new_node.children[1] = update.new_node;
                new_node.count = 1;

                // ルートノードを更新する
                self.root = new_node;
            }

            // 数を更新する
            self.count += 1;
        }

        /// ノードに値を挿入します。
        /// 必要に応じてノードを分割します。
        fn insertIntoNode(self: *Self, cur_node: ?*Node, update: *UpdateInfo) !void {
            if (cur_node) |node| {
                // 指定値が挿入される位置を取得
                var ins: usize = 0;
                while (ins < node.count and compare(node.values[ins], update.value) < 0) : (ins += 1) {}

                // 既に同じ値が存在する場合は、エラーを返す
                if (ins < node.count and compare(node.values[ins], update.value) == 0) {
                    update.done = true;
                    return BTreeError.AlreadyExists;
                }

                // 登録されているノードが存在しない場合は、子のノードへ挿入
                self.insertIntoNode(node.children[ins], update) catch {
                    return BTreeError.InsertFailed;
                };
                if (!update.done) {
                    if (node.count < node.values.len) {
                        // ノードを割らずに挿入できる場合は、値を挿入する
                        self.insertValueIntoNode(node, ins, update);
                        update.done = true;
                    } else {
                        // ノードが満杯の場合は、ノードを分割する
                        try self.splitAndIntoNode(node, ins, update);
                        update.done = false;
                    }
                }
            } else {
                // カレントノードが存在しない場合は、呼び元が更新対象
                update.done = false;
                update.new_node = null;
            }
        }

        /// ノードに値を挿入します。
        /// ノードの値を右にシフトし、新しい値を挿入します。
        /// 子ノードも同様にシフトします。
        fn insertValueIntoNode(_: *Self, node: *Node, index: usize, update: *UpdateInfo) void {
            // ノードの値を右にシフト
            std.mem.copyBackwards(T, node.values[index + 1 ..], node.values[index..node.count]);
            node.values[index] = update.value;

            // 新しいノードが存在する場合は、子ノードを右にシフト
            std.mem.copyBackwards(?*Node, node.children[index + 2 ..], node.children[index + 1 .. node.count + 1]);
            node.children[index + 1] = update.new_node;

            // ノードの値の数を更新
            node.count += 1;
        }

        /// ノードを分割し、新しい値を挿入します。
        /// 分割されたノードは、左側のノードと右側のノードに分けられます。
        fn splitAndIntoNode(self: *Self, node: *Node, index: usize, update: *UpdateInfo) !void {
            // 新しいノードを取得
            const new_node = self.node_store.get() catch {
                return BTreeError.OutOfMemory;
            };
            new_node.* = Node.init();

            // 分割位置を計算
            const split_index: usize = if (index <= M) M else M + 1;

            // 右側のノードに値をコピー
            std.mem.copyForwards(T, new_node.values[0..], node.values[split_index..node.values.len]);
            std.mem.copyForwards(?*Node, new_node.children[1..], node.children[split_index + 1 .. node.children.len]);
            new_node.count = node.values.len - split_index;

            // 左側のノードは数のみ更新
            node.count = split_index;

            // 値を挿入する
            if (index <= M) {
                self.insertValueIntoNode(node, index, update);
            } else {
                self.insertValueIntoNode(new_node, index - split_index, update);
            }

            // 呼び出し元で更新する情報を設定
            update.value = node.values[node.count - 1];
            update.new_node = new_node;

            // リンクを更新
            new_node.children[0] = node.children[node.count];
            node.count -= 1;
        }

        /// B木に値が存在するかどうかを確認します。
        /// 存在する場合はtrueを返し、存在しない場合はfalseを返します。
        pub fn contains(self: *const Self, value: T) bool {
            var ptr: ?*Node = self.root;
            while (ptr) |node| {
                var i: usize = 0;
                while (i < node.count and compare(node.values[i], value) < 0) : (i += 1) {}

                if (i < node.count and compare(node.values[i], value) == 0) {
                    return true;
                }
                ptr = node.children[i];
            }
            return false;
        }

        /// B木から値を検索します。
        /// 値が見つかった場合は、そのポインタを返します。
        /// 値が見つからなかった場合は、nullを返します。
        pub fn search(self: *const Self, value: T) ?*T {
            var ptr: ?*Node = self.root;
            while (ptr) |node| {
                var i: usize = 0;
                while (i < node.count and compare(node.values[i], value) < 0) : (i += 1) {}

                if (i < node.count and compare(node.values[i], value) == 0) {
                    return &node.values[i];
                }
                ptr = node.children[i];
            }
            return null;
        }

        /// B木から最大値を取得します。
        pub fn getMax(self: *Self) T {
            var ptr: ?*Node = self.root;
            var max_value: T = undefined;

            while (ptr) |node| {
                max_value = node.values[node.count - 1];
                ptr = node.children[node.count];
            }
            return max_value;
        }

        /// B木から最小値を取得します。
        pub fn getMin(self: *Self) T {
            var ptr: ?*Node = self.root;
            var min_value: T = undefined;

            while (ptr) |node| {
                min_value = node.values[0];
                ptr = node.children[0];
            }
            return min_value;
        }

        /// B木をクリアします。
        /// ルートノードから全てのノードをクリアし、カウントを0にします。
        /// クリア後、ストアにノードを返却します。
        pub fn clear(self: *Self) !void {
            // ルートノードから全てのノードをクリア
            if (self.root) |root| {
                try self.clearAndReturnNode(root);
                self.root = null;
            }
            self.count = 0;
        }

        /// ノードをストアに返却します。
        fn clearAndReturnNode(self: *Self, cur_node: ?*Node) !void {
            if (cur_node) |node| {
                for (0..node.count + 1) |i| {
                    try self.clearAndReturnNode(node.children[i]);
                }
                // ノードをストアに返却
                self.node_store.put(node) catch {
                    return BTreeError.OutOfMemory;
                };
            }
        }

        /// B木から値を削除します。
        /// 削除が成功した場合は、カウントを減らします。
        /// 削除が失敗した場合は、エラーを返します。
        pub fn remove(self: *Self, value: T) !void {
            var delete: DeleteInfo = .{
                .value = value,
                .deleted = false,
                .under_size = false,
            };

            // ルートノードから削除を開始
            try self.removeFromNode(self.root, &delete);
            if (delete.deleted) {
                if (self.root) |root| {
                    // ルートノードが空になった場合は、ルートを子要素で置き換える
                    if (root.count == 0) {
                        try self.node_store.put(root);
                        self.root = root.children[0];
                    }
                }

                // 削除が成功した場合は、カウントを減らす
                self.count -= 1;
            } else {
                // 要素がなく、削除できなかった場合はエラーを返す
                return BTreeError.NotFoundToRemove;
            }
        }

        /// ノードから値を削除します。
        /// 値が見つかった場合は、削除し、子ノードも削除します。
        fn removeFromNode(self: *Self, cur_node: ?*Node, delete: *DeleteInfo) !void {
            if (cur_node) |node| {
                // 削除する値の位置を探す
                var del: usize = 0;
                while (del < node.count and compare(node.values[del], delete.value) < 0) : (del += 1) {}

                // 値が見つかった場合は削除する、そうでない場合は子ノードから削除を試みる
                if (del < node.count and compare(node.values[del], delete.value) == 0) {
                    delete.deleted = true;
                    if (node.children[del + 1]) |rnode| {
                        // 右側の子ノードの最小値を取得して置き換える
                        var rem_node: *Node = rnode;
                        while (rem_node.children[0]) |rem_node_a| {
                            rem_node = rem_node_a;
                        }

                        // 右側の子ノードの最小値を削除
                        node.values[del] = rem_node.values[0];
                        delete.value = rem_node.values[0];
                        try self.removeFromNode(node.children[del + 1], delete);
                        if (delete.under_size) {
                            try self.restoreNode(node, del + 1, delete);
                        }
                    } else {
                        self.remove_item(node, del, delete);
                    }
                } else {
                    try self.removeFromNode(node.children[del], delete);
                    if (delete.under_size) {
                        try self.restoreNode(node, del, delete);
                    }
                }
            }
        }

        /// ノードから値を削除します。
        /// 値が見つかった場合は、削除し、子ノードも削除します。
        fn remove_item(_: *Self, node: *Node, index: usize, delete: *DeleteInfo) void {
            // 値を削除し、右側の値を左にシフト
            std.mem.copyForwards(T, node.values[index..], node.values[index + 1 .. node.count]);
            std.mem.copyForwards(?*Node, node.children[index + 1 ..], node.children[index + 2 .. node.count + 1]);

            // ノードの値の数を減らす、小さくなりすぎたら under_size フラグを立てる
            node.count -= 1;
            delete.under_size = node.count < M;
        }

        /// ノードから値を借りて、サイズを調整します。
        /// 左側または右側のノードから値を借りて、サイズを調整します。
        fn restoreNode(self: *Self, node: *Node, index: usize, delete: *DeleteInfo) !void {
            delete.under_size = false;
            if (index > 0) {
                // 左側のノードから値を借りる
                if (node.children[index - 1]) |l_node| {
                    if (l_node.count > M) move_right(node, index) else try self.combine(node, index, delete);
                }
            } else {
                // 右側のノードから値を借りる
                if (node.children[1]) |r_node| {
                    if (r_node.count > M) move_left(node, 1) else try self.combine(node, 1, delete);
                }
            }
        }

        /// 左側のノードから値を借りて、右にシフトします。
        fn move_right(node: *Node, index: usize) void {
            var left = node.children[index - 1].?;
            var right = node.children[index].?;

            // 右のノードに空きを作る
            std.mem.copyBackwards(T, right.values[1..], right.values[0..right.count]);
            std.mem.copyBackwards(?*Node, right.children[2..], right.children[1 .. 1 + right.count]);
            right.children[1] = right.children[0];
            right.count += 1;

            // 親のノードの値を右側のノードに移動
            right.values[0] = node.values[index - 1];

            // 左側のノードの値を親のノードに移動
            node.values[index - 1] = left.values[left.count - 1];
            right.children[0] = left.children[left.count];
            left.count -= 1;
        }

        /// 右側のノードから値を借りて、左にシフトします。
        fn move_left(node: *Node, index: usize) void {
            var left = node.children[index - 1].?;
            var right = node.children[index].?;

            // 親ノードの値を左側のノードに移動
            left.count += 1;
            left.values[left.count - 1] = node.values[index - 1];
            left.children[left.count] = right.children[0];

            // 右側のノードの値を親のノードに移動
            node.values[index - 1] = right.values[0];
            right.children[0] = right.children[1];
            right.count -= 1;

            // 移動した値分、右側のノードの値と子ノードをシフト
            std.mem.copyForwards(T, right.values[0..], right.values[1 .. 1 + right.count]);
            std.mem.copyForwards(?*Node, right.children[1..], right.children[2 .. 2 + right.count]);
        }

        /// ノードを結合します。
        /// 左側のノードと右側のノードを結合し、親ノードから値を削除します。
        fn combine(self: *Self, node: *Node, index: usize, delete: *DeleteInfo) !void {
            var left = node.children[index - 1].?;
            var right = node.children[index].?;

            // 左側のノードに右側のノードの値を追加
            left.count += 1;
            left.values[left.count - 1] = node.values[index - 1];
            left.children[left.count] = right.children[0];
            std.mem.copyForwards(T, left.values[left.count..], right.values[0..right.count]);
            std.mem.copyForwards(?*Node, left.children[left.count + 1 ..], right.children[1 .. right.count + 1]);
            left.count += right.count;

            // 親ノードから値を削除
            self.remove_item(node, index - 1, delete);

            // ノードを削除
            try self.node_store.put(right);
        }

        /// コンソールにB木の内容を出力します。
        pub fn print(self: *Self) void {
            printNode(self.root, 1);
            std.debug.print(".\n", .{});
        }

        /// ノードの内容をコンソールに出力します。
        /// 再帰的に子ノードも出力します。
        fn printNode(cur_node: ?*Node, depth: usize) void {
            if (cur_node) |node| {
                printNode(node.children[0], depth + 1);
                for (0..node.count) |i| {
                    std.debug.print("{d}:{d},", .{ node.values[i], depth });
                    printNode(node.children[i + 1], depth + 1);
                }
            }
        }

        /// コンソールにB木の内容を出力します。
        pub fn printTree(self: *Self) void {
            printTreeNode(self.root, 1);
            std.debug.print(".\n", .{});
        }

        /// ノードの内容をコンソールに出力します。
        /// 再帰的に子ノードも出力します。
        fn printTreeNode(cur_node: ?*Node, depth: usize) void {
            if (cur_node) |node| {
                std.debug.print("{d} [", .{depth});
                for (0..node.count) |i| {
                    std.debug.print("{d}, ", .{node.values[i]});
                }
                std.debug.print("]\n", .{});
                if (node.children[0] != null) {
                    std.debug.print("(", .{});
                    for (0..node.count + 1) |i| {
                        printTreeNode(node.children[i], depth + 1);
                    }
                    std.debug.print(")\n", .{});
                }
            }
        }

        // イテレータ
        const Iterator = struct {
            tree: *Self,
            depth: usize,
            hierarchy: []?*Node,
            index: []usize,

            /// イテレータの初期化
            pub fn deinit(self: *Iterator) void {
                self.tree.allocator.free(self.hierarchy);
                self.tree.allocator.free(self.index);
            }

            /// 次の要素を取得します。
            pub fn next(iter: *Iterator) ?T {
                while (true) {
                    if (iter.hierarchy[iter.depth]) |node| {
                        const cindex = iter.index[iter.depth] & 1;
                        const nindex = iter.index[iter.depth] >> 1;

                        if (cindex == 0) {
                            iter.depth += 1;
                            iter.hierarchy[iter.depth] = node.children[nindex];
                            iter.index[iter.depth] = 0;
                        } else if (nindex < node.count) {
                            const res = node.values[nindex];
                            iter.index[iter.depth] += 1;
                            return res;
                        } else if (iter.depth > 0) {
                            iter.depth -= 1;
                            iter.index[iter.depth] += 1;
                        } else {
                            break;
                        }
                    } else if (iter.depth > 0) {
                        iter.depth -= 1;
                        iter.index[iter.depth] += 1;
                    } else {
                        break;
                    }
                }
                iter.hierarchy[iter.depth] = null;
                return null;
            }
        };

        /// イテレータを使用して、B木コレクションの要素を反復処理します。
        /// イテレータは、B木コレクションの要素を順番に処理するための構造体です。
        pub fn iterate(self: *Self) !Iterator {
            const depth: usize = @intFromFloat(@ceil(@log(@as(f64, @floatFromInt(self.count))) / @log(@as(f64, @floatFromInt(M * 2)))));
            var res = Iterator{
                .tree = self,
                .depth = 0,
                .hierarchy = try self.allocator.alloc(?*Node, depth + 1),
                .index = try self.allocator.alloc(usize, depth + 1),
            };
            res.hierarchy[res.depth] = self.root;
            res.index[res.depth] = 0;
            return res;
        }
    };
}
