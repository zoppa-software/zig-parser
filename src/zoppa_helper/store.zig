const std = @import("std");
const testing = std.testing;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

/// 指定した型のオブジェクトを保持する。
pub fn Store(comptime T: type, comptime size: comptime_int, reset_T: fn (*T) void, init_T: fn (Allocator, *T, anytype) anyerror!void, deinit_T: fn (Allocator, *T) void) type {
    return struct {
        ///　ストアのエラー
        pub const Error = error{
            OutOfMemory,
            InitializationFailed,
        };

        /// 自身の型
        const Self = @This();

        // 削除済みリスト
        free_list: []*T,

        // 削除済み数
        free_count: usize,

        // データの格納先
        instances: [][*]T,

        // アロケータ
        allocator: Allocator,

        /// ストアを初期化します。
        pub fn init(alloc: Allocator) !Self {
            var res = Self{
                .free_count = 0,
                .free_list = try alloc.alloc(*T, size),
                .instances = try alloc.alloc([*]T, 0),
                .allocator = alloc,
            };

            // エラーが発生した場合は、初期化を行わない
            try res.createCache();

            return res;
        }

        /// ストアを破棄します。
        pub fn deinit(self: *Self) void {
            self.delete_lists();
        }

        /// ストアをクリアします。
        pub fn clear(self: *Self) !void {
            self.delete_lists();

            self.free_list = try self.allocator.alloc(*T, size);
            self.instances = try self.allocator.alloc([*]T, 0);

            try self.createCache();
        }

        /// ストアの削除済みリスト、データの格納先を削除します。
        fn delete_lists(self: *Self) void {
            self.free_count = 0;
            self.allocator.free(self.free_list);

            for (self.instances) |item| {
                for (0..size) |i| {
                    deinit_T(self.allocator, &item[i]);
                }
                self.allocator.free(item[0..size]);
            }
            self.allocator.free(self.instances);
        }

        /// キャッシュを作成します。
        fn createCache(self: *Self) !void {
            // 実体を保持する領域を確保する
            var new_instances = try self.allocator.alloc([*]T, self.instances.len + 1);
            std.mem.copyForwards([*]T, new_instances[0..self.instances.len], self.instances);

            // 新しいインスタンスを確保する
            const tmp = try self.allocator.alloc(T, size);
            new_instances[new_instances.len - 1] = tmp.ptr;
            self.allocator.free(self.instances);
            self.instances = new_instances;

            // サイズを変更する
            self.free_count = size;
            for (tmp, 0..) |*item, i| {
                reset_T(item);
                self.free_list[i] = item;
            }
        }

        /// 比較関数を使用して、昇順にソートします。
        fn asc_T(_: void, a: *T, b: *T) bool {
            return @intFromPtr(a) < @intFromPtr(b);
        }

        /// ストアからオブジェクトを取得します。
        pub fn get(self: *Self, args: anytype) !*T {
            // 削除済みリストが空の場合は、キャッシュを作成する
            if (self.free_count <= 0) {
                try self.createCache();
            }

            // 削除済みリストから取得する
            const item = self.free_list[self.free_count - 1];
            init_T(self.allocator, item, args) catch {
                return Error.InitializationFailed;
            };

            // 削除済みリストから削除する
            self.free_count -= 1;
            return item;
        }

        /// ストアにオブジェクトを返却します。
        pub fn put(self: *Self, item: *T) !void {
            // もし、itemが削除済みリストに含まれていれば、何もしない
            if (searchTarget(self.free_list, self.free_count, item)) {
                return;
            }

            // インスタンスの解放
            deinit_T(self.allocator, item);

            // もし、削除済みリストが満杯であれば、リストを拡張する
            if (self.free_count >= self.free_list.len) {
                // 削除済みリストが満杯の場合は、リストを拡張する
                // (作成したインスタンス数のサイズ - 削除済みリストのサイズ) / 2 のサイズを追加する
                const inst_size = self.instances.len * size;
                const new_size = @min(self.free_list.len + @max((inst_size - self.free_list.len) / 2, size), inst_size);

                // 新しい削除済みリストを確保する
                const new_deleted = try self.allocator.alloc(*T, new_size);
                std.mem.copyForwards(*T, new_deleted[0..self.free_list.len], self.free_list);
                self.allocator.free(self.free_list);
                self.free_list = new_deleted;
            }

            const insert_pos = searchInsertPosition(self.free_list, self.free_count, item);
            std.mem.copyBackwards(*T, self.free_list[insert_pos + 1 .. self.free_count + 1], self.free_list[insert_pos..self.free_count]);
            self.free_list[insert_pos] = item;
            self.free_count += 1;
        }

        /// 削除済みリストにターゲットが存在するかを検索します。
        /// 存在する場合はtrueを返し、存在しない場合はfalseを返します。
        fn searchTarget(arr: []*T, list_size: usize, target: *T) bool {
            if (list_size <= 0) return false;
            var left: isize = 0;
            var right: isize = @intCast(list_size - 1);

            while (left <= right) {
                const mid = left + @divFloor(right - left, 2);

                // 比較関数を使用して、ターゲットと中間値を比較
                const mid_v = @intFromPtr(arr[@intCast(mid)]);
                const cmp_v = @intFromPtr(target);
                if (mid_v == cmp_v) {
                    return true;
                } else if (mid_v < cmp_v) {
                    left = mid + 1;
                } else {
                    right = mid - 1;
                }
            }
            return false;
        }

        /// 削除済みリストにターゲットの挿入位置を検索します。
        /// 挿入位置を返します。
        fn searchInsertPosition(arr: []*T, list_size: usize, target: *T) usize {
            if (list_size <= 0) return 0;
            var left: isize = 0;
            var right: isize = @intCast(list_size);

            while (left < right) {
                const mid = left + @divFloor(right - left, 2);

                // 比較関数を使用して、ターゲットと中間値を比較
                const mid_v = @intFromPtr(arr[@intCast(mid)]);
                const cmp_v = @intFromPtr(target);
                if (mid_v >= cmp_v) {
                    right = mid;
                } else {
                    left = mid + 1;
                }
            }
            return @intCast(left);
        }
    };
}
