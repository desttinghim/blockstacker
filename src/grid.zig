const std = @import("std");
const seizer = @import("seizer");
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const util = @import("util.zig");

pub const Block = union(enum) {
    none: void,
    some: u8,
};

pub const Grid = struct {
    items: []Block,
    size: Vec,
    allocator: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator, size: Vec) !@This() {
        const items = try alloc.alloc(Block, @intCast(usize, size.x * size.y));
        std.mem.set(Block, items, Block.none);
        return @This(){
            .items = items,
            .size = size,
            .allocator = alloc,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.items);
    }

    pub fn contains(self: *@This(), point: Veci) bool {
        return util.contains(self.size, point);
    }

    pub fn vec2i(self: *@This(), pos: Veci) ?usize {
        return util.vec2i(self.size, pos);
    }

    pub fn i2vec(self: *@This(), i: usize) ?Veci {
        return i2vec(self.size, i);
    }

    pub fn set(self: *@This(), pos: Veci, val: Block) void {
        if (self.vec2i(pos)) |i| {
            self.items[i] = val;
        }
    }

    pub fn get(self: *@This(), pos: Veci) ?Block {
        return if (self.vec2i(pos)) |i|
            self.items[i]
        else
            null;
    }

    pub fn get_row_slice(self: *@This(), row: usize) []Block {
        var offset = row * self.size.x;
        return self.items[offset .. offset + self.size.x];
    }

    /// Only call on known good locations
    pub fn get_raw(self: *@This(), pos: Veci) Block {
        return self.items[self.vec2i(pos).?];
    }

    /// Only call on known good locations
    pub fn swap(self: *@This(), pos1: Veci, pos2: Veci) void {
        var a = self.get_raw(pos1);
        self.set(pos1, self.get_raw(pos2));
        self.set(pos2, a);
    }

    pub fn clear_rows(self: *@This()) !u32 {
        var cleared: u32 = 0;
        var row: usize = self.size.y - 1;
        while (row > 0) : (row -= 1) {
            var full_row = true;
            var row_slice = self.get_row_slice(row);
            for (row_slice) |*val| {
                if (val.* == .none) {
                    full_row = false;
                    break;
                }
            }

            if (full_row) {
                cleared += 1;
                for (row_slice) |*val| {
                    val.* = .none;
                }
                var temp_slice = try self.allocator.alloc(Block, self.size.x);
                defer self.allocator.free(temp_slice);
                var y: usize = row;
                while (y > 0) : (y -= 1) {
                    var a = self.get_row_slice(y);
                    var b = self.get_row_slice(y - 1);
                    std.mem.copy(Block, temp_slice, b);
                    std.mem.copy(Block, a, b);
                    std.mem.copy(Block, a, temp_slice);
                }
                row += 1;
            }
        }
        return cleared;
    }

    pub fn clear(self: *@This()) void {
        std.mem.set(Block, self.items, Block.none);
    }
};
