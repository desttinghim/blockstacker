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

    pub fn contains(self: *@This(), point: Vec) bool {
        return point.x > 0 and point.y > 0 and point.x <= self.size.x and point.y < self.size.y;
    }

    pub fn vec2i(self: *@This(), pos: Vec) ?usize {
        return if (self.contains(pos)) pos.x + (self.size.x * pos.y) else null;
    }

    pub fn i2vec(self: *@This(), i: usize) ?Vec {
        return if (i < self.items.len) vec(@intCast(usize, i % self.size.x), @intCast(usize, i / self.size.x)) else null;
    }

    pub fn set(self: *@This(), pos: Vec, val: Block) void {
        if (self.vec2i(pos)) |i| {
            self.items[i] = val;
        }
    }

    pub fn get(self: *@This(), pos: Vec) ?Block {
        return if (self.vec2i(pos)) |i|
            self.items[i]
        else
            null;
    }

    pub fn clear(self: *@This()) void {
        std.mem.set(Block, self.items, Block.none);
        std.mem.set(Block, self.items_copy, Block.none);
    }

    fn transpose(self: *@This()) void {
        std.mem.copy(Block, self.items_copy, self.items);

        var x: usize = 0;
        while (x < self.size.x) : (x += 1) {
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                if (self.vec2i(vec(x, y))) |src| {
                    if (self.vec2i(vec(y, x))) |dest| {
                        self.items[dest] = self.items_copy[src];
                    }
                }
            }
        }
    }

    fn reverse_rows(self: *@This()) void {
        std.mem.copy(Block, self.items_copy, self.items);

        var y: usize = 0;
        while (y < self.size.y) : (y += 1) {
            var x: usize = 0;
            while (x < self.size.x) : (x += 1) {
                if (self.vec2i(vec(x, y))) |src| {
                    if (self.vec2i(vec(x, self.size.y - y - 1))) |dest| {
                        self.items[dest] = self.items_copy[src];
                    }
                }
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

pub const PieceType = enum {
    I,
    J,
    L,
    O,
    S,
    T,
    Z,
    Other,
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

    pub fn rotate_cw(self: *@This()) void {
        self.grid.rotate_cw();
    }

    pub fn rotate_ws(self: *@This()) void {
        self.grid.rotate_ws();
    }

    pub fn set_type(self: *@This(), piece: PieceType) void {
        switch (piece) {
            .I => {
                self.grid.set(vec(1, 2), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
                self.grid.set(vec(4, 2), .{ .some = 0 });
            },
            .J => {
                self.grid.set(vec(1, 1), .{ .some = 0 });
                self.grid.set(vec(1, 2), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
            },
            .L => {
                self.grid.set(vec(1, 2), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
                self.grid.set(vec(3, 1), .{ .some = 0 });
            },
            .O => {
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
                self.grid.set(vec(2, 3), .{ .some = 0 });
                self.grid.set(vec(3, 3), .{ .some = 0 });
            },
            .S => {
                self.grid.set(vec(1, 3), .{ .some = 0 });
                self.grid.set(vec(2, 3), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
            },
            .T => {
                self.grid.set(vec(1, 2), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(3, 2), .{ .some = 0 });
                self.grid.set(vec(2, 3), .{ .some = 0 });
            },
            .Z => {
                self.grid.set(vec(1, 2), .{ .some = 0 });
                self.grid.set(vec(2, 2), .{ .some = 0 });
                self.grid.set(vec(2, 3), .{ .some = 0 });
                self.grid.set(vec(3, 3), .{ .some = 0 });
            },
            else => {
                std.log.debug("Not implemented", .{});
            },
        }
    }
};
