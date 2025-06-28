const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const BTree = @import("btree.zig").BTree;

/// データストアのエラー
pub const StoreError = error{
    /// メモリ不足のエラー
    OutOfMemory,
    /// インスタンスの初期化に失敗したエラー
    InitFailed,
    /// データストアからのデータ取得に失敗したエラー
    GetFailed,
    /// データストアのデータ返却に失敗したエラー
    PopFailed,
};

/// データストア
/// このストアは、指定された型のデータを格納、管理します。
pub fn Store(comptime T: type, comptime size: comptime_int, init_T: fn (Allocator, *T, anytype) anyerror!void, deinit_T: fn (Allocator, *T) void) type {
    return struct {
        /// 自身の型
        const Self = @This();

        // アロケータ
        allocator: Allocator,

        // データの格納先
        instances: [][*]T,

        // キャッシュ
        cache: BTree(usize, 4, compareUsize),

        /// データストアを初期化します。
        pub fn init(alloc: Allocator) !Self {
            // 削除済みリストを初期化します。
            const frees = BTree(usize, 4, compareUsize).init(alloc) catch {
                return StoreError.OutOfMemory;
            };

            // データストアを初期化します。
            var res = Self{
                .allocator = alloc,
                .instances = &[_][*]T{},
                .cache = frees,
            };

            // キャッシュを作成します。
            try res.addCache();

            return res;
        }

        /// ストアを破棄します。
        pub fn deinit(self: *Self) void {
            self.clearAllAndCache() catch {};
            self.cache.deinit();
        }

        /// データストアのキャッシュを作成します。
        fn addCache(self: *Self) !void {
            self.instances = blk: {
                // 実体を保持する領域を確保し、今までのインスタンスをコピーします。
                var new_instances = self.allocator.alloc([*]T, self.instances.len + 1) catch {
                    return StoreError.OutOfMemory;
                };
                std.mem.copyForwards([*]T, new_instances[0..self.instances.len], self.instances);

                // 新しいインスタンスを確保する
                const tmp = try self.allocator.alloc(T, size);
                new_instances[new_instances.len - 1] = tmp.ptr;
                defer {
                    if (self.instances.len > 0) self.allocator.free(self.instances);
                }

                // 新しいインスタンスを初期化します。
                for (tmp) |*item| {
                    self.cache.insert(@intFromPtr(item)) catch {
                        return StoreError.InitFailed;
                    };
                }
                break :blk new_instances;
            };
        }
        /// ストアをクリアします。
        pub fn clear(self: *Self) !void {
            try self.clearAllAndCache();
            try self.addCache();
        }

        /// ストアの削除済みリスト、データの格納先を削除します。
        fn clearAllAndCache(self: *Self) !void {
            // 削除済みリストを解放します。
            if (self.instances.len > 0) {
                for (self.instances) |item| {
                    for (0..size) |i| {
                        deinit_T(self.allocator, &item[i]);
                    }
                    self.allocator.free(item[0..size]);
                }
                self.allocator.free(self.instances);
            }

            // インスタンスのポインタを空にします。
            self.instances = &[_][*]T{};

            // キャッシュを空にします。
            try self.cache.clear();
        }

        /// usizeの比較関数
        /// これはBTreeの比較関数として使用されます。
        fn compareUsize(left: usize, right: usize) i32 {
            if (left != right) {
                return if (left < right) -1 else 1;
            }
            return 0;
        }

        /// データを取得します。
        /// argsは初期化時に使用される引数です。
        /// 取得できない場合はStoreError.GetFailedを返します。
        pub fn get(self: *Self, args: anytype) !*T {
            // キャッシュが空の場合は、キャッシュを作成します。
            if (self.cache.count == 0) {
                try self.addCache();
            }

            if (self.cache.root) |root| {
                // キャッシュから値を取得します。
                const item = root.values[root.count - 1];
                self.cache.remove(item) catch {
                    return StoreError.GetFailed;
                };

                // 取得した値を初期化します。
                const res: *T = @ptrFromInt(item);
                init_T(self.allocator, res, args) catch {
                    return StoreError.InitFailed;
                };
                return res;
            } else {
                return StoreError.GetFailed;
            }
        }

        /// データをストアに返却します。
        /// itemは返却するデータのポインタです。
        pub fn pop(self: *Self, item: *T) !void {
            // 既にキャッシュに存在する場合は、エラーを返します。
            const ptr = @intFromPtr(item);
            if (self.cache.contains(ptr)) {
                return StoreError.PopFailed;
            } else {
                // キャッシュに追加します。
                self.cache.insert(ptr) catch {
                    return StoreError.PopFailed;
                };
                // データを解放
                deinit_T(self.allocator, item);
            }
        }

        // イテレータ
        const Iterator = struct {
            store: *Self,
            group: usize,
            index: usize,

            /// イテレータの初期化
            pub fn deinit(self: *Iterator) void {
                self.tree.allocator.free(self.hierarchy);
                self.tree.allocator.free(self.index);
            }

            /// 次の要素を取得します。
            pub fn next(iter: *Iterator) ?*T {
                // 削除済みリストを解放します。
                while (iter.group < iter.store.instances.len) {
                    if (iter.index >= size) {
                        iter.group += 1;
                        iter.index = 0;
                    } else {
                        const idx = iter.index;
                        iter.index += 1;
                        return &iter.store.instances[iter.group][idx];
                    }
                }
                return null;
            }
        };

        /// イテレータを生成します。
        /// これはストアの全ての要素を走査するために使用されます。
        pub fn iterate(self: *Self) !Iterator {
            return Iterator{
                .store = self,
                .group = 0,
                .index = 0,
            };
        }
    };
}
