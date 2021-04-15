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

    pub fn clear(self: *@This()) void {
        std.mem.set(Block, self.items, Block.none);
    }
};
