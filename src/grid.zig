const std = @import("std");
const seizer = @import("seizer");
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;

pub const Block = union(enum) {
    none: void,
    wall: void,
    some: u8,
};

pub const Grid = struct {
    items: []Block,
    items_copy: []Block,
    size: Vec,
    allocator: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator, size: Vec) !@This() {
        const items = try alloc.alloc(Block, size.x * size.y);
        const items_copy = try alloc.alloc(Block, size.x * size.y);
        std.mem.set(Block, items, Block.none);
        std.mem.set(Block, items_copy, Block.none);
        return @This(){
            .items = items,
            .items_copy = items_copy,
            .size = size,
            .allocator = alloc,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.items);
        self.allocator.free(self.items_copy);
    }

    pub fn contains(self: *@This(), point: Vec) bool {}

    pub fn vec2i(self: *@This(), pos: Vec) usize {
        return pos.x + (self.size.x * pos.y);
    }

    pub fn i2vec(self: *@This(), i: usize) Vec {
        return vec(@intCast(usize, i % self.size.x), @intCast(usize, i / self.size.x));
    }

    pub fn set(self: *@This(), pos: Vec, val: Block) void {
        self.items[self.vec2i(pos)] = val;
    }

    pub fn get(self: *@This(), pos: Vec) Block {
        return self.items[self.vec2i(pos)];
    }

    // pub fn swap(self: *@This(), pos1: Vec, pos2: Vec) void {}

    pub fn clear(self: *@This()) void {
        std.mem.set(Block, self.items, Block.none);
        std.mem.set(Block, self.items_copy, Block.none);
    }

    fn transpose(self: *@This()) void {
        std.mem.copy(self.items_copy, self.items);

        var x: usize = 0;
        while (x < self.size.x) : (x += 1) {
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                self.items[self.vec2i(vec(y, x))] = self.items_copy[self.vec2i(vec(x, y))];
            }
        }
    }

    fn reverse_rows(self: *@This()) void {
        std.mem.copy(self.items_copy, self.items);

        var y: usize = 0;
        while (y < self.size.y) : (y += 1) {
            var x: usize = 0;
            while (x < self.size.x) : (x += 1) {
                self.items[self.vec2i(vec(x, y))] = self.items_copy[self.vec2i(x, self.size.y - y)];
            }
        }
    }

    pub fn rotate_cw(self: *@This()) void {
        self.transpose();
        self.reverse_rows();
    }

    pub fn rotate_ws(self: *@This()) void {
        self.reverse_rows();
        self.transpose();
    }
};

pub const Piece = struct {
    grid: Grid,
    pos: Vec,

    pub fn init(alloc: *std.mem.Allocator, pos: Vec) !@This() {
        return @This(){
            .grid = try Grid.init(alloc, vec(5, 5)),
            .pos = pos,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.grid.deinit();
    }
};
