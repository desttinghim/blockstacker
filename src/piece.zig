const std = @import("std");
const seizer = @import("seizer");
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const grid_zig = @import("grid.zig");
const Block = grid_zig.Block;
const Grid = grid_zig.Grid;
const util = @import("util.zig");

pub const PieceType = enum(usize) {
    I = 0,
    J,
    L,
    O,
    S,
    T,
    Z,
};

pub const Piece = struct {
    items: [25]Block,
    items_copy: [25]Block,
    size: Vec,
    pos: Veci,

    pub fn init(pos: Veci) @This() {
        var this: @This() = undefined;
        this = @This(){
            .items = [1]Block{.none} ** 25,
            .items_copy = [1]Block{.none} ** 25,
            .size = vec(5, 5),
            .pos = pos,
        };
        return this;
    }

    pub fn get_bag() [7]PieceType {
        var bag: [7]PieceType = undefined;
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            bag[i] = @intToEnum(PieceType, i);
        }
        return bag;
    }

    pub fn shuffled_bag() [7]PieceType {
        var rng = std.rand.DefaultPrng.init(0);
        var rand = &rng.random;
        var bag = @This().get_bag();
        var i: usize = 0;
        while (i < bag.len) : (i += 1) {
            var a = rand.intRangeLessThanBiased(usize, 0, bag.len);
            const current = bag[i];
            bag[i] = bag[a];
            bag[a] = current;
        }
        return bag;
    }

    pub fn clear(self: *@This()) void {
        std.mem.set(Block, &self.items, Block.none);
        std.mem.set(Block, &self.items_copy, Block.none);
    }

    pub fn collides_with(self: *@This(), grid: *Grid) bool {
        for (self.items) |block_self, i| {
            switch (block_self) {
                .none => continue,
                .some => |_| if (self.i2vec(i)) |pos| {
                    var gpos = pos.addv(self.pos);
                    if (grid.get(gpos)) |block| {
                        if (block == .some) {
                            return true; // Collision is true since we intersected a block
                        }
                    } else {
                        return true; // Collision is true since we are out of bounds
                    }
                },
            }
        }

        return false;
    }

    pub fn integrate_with(self: *@This(), grid: *Grid) void {
        for (self.items) |block_self, i| {
            switch (block_self) {
                .none => continue,
                .some => |_| if (self.i2vec(i)) |pos| {
                    var gpos = pos.addv(self.pos);
                    grid.set(gpos, block_self);
                },
            }
        }
    }

    pub fn move_left(self: *@This()) void {
        self.pos = self.pos.subv(veci(1, 0));
    }

    pub fn move_right(self: *@This()) void {
        self.pos = self.pos.addv(veci(1, 0));
    }

    pub fn move_down(self: *@This()) void {
        self.pos = self.pos.addv(veci(0, 1));
    }

    pub fn rotate_cw(self: *@This()) void {
        self.transpose();
        self.reverse_rows();
    }

    pub fn rotate_ws(self: *@This()) void {
        self.reverse_rows();
        self.transpose();
    }

    pub fn set_type(self: *@This(), piece: PieceType) void {
        self.clear();
        switch (piece) {
            .I => {
                self.set(veci(1, 2), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.set(veci(4, 2), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .J => {
                self.set(veci(1, 1), .{ .some = 0 });
                self.set(veci(1, 2), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .L => {
                self.set(veci(1, 2), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.set(veci(3, 1), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .O => {
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.set(veci(2, 3), .{ .some = 0 });
                self.set(veci(3, 3), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .S => {
                self.set(veci(1, 3), .{ .some = 0 });
                self.set(veci(2, 3), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .T => {
                self.set(veci(1, 2), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(3, 2), .{ .some = 0 });
                self.set(veci(2, 3), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
            .Z => {
                self.set(veci(1, 2), .{ .some = 0 });
                self.set(veci(2, 2), .{ .some = 0 });
                self.set(veci(2, 3), .{ .some = 0 });
                self.set(veci(3, 3), .{ .some = 0 });
                self.pos = veci(0, 0);
            },
        }
    }

    fn contains(self: *@This(), point: Veci) bool {
        return util.contains(self.size, point);
    }

    fn vec2i(self: *@This(), pos: Veci) ?usize {
        return util.vec2i(self.size, pos);
    }

    fn i2vec(self: *@This(), i: usize) ?Veci {
        return util.i2vec(self.size, i);
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

    fn transpose(self: *@This()) void {
        std.mem.copy(Block, &self.items_copy, &self.items);

        var x: usize = 0;
        while (x < self.size.x) : (x += 1) {
            var xi = @intCast(isize, x);
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var yi = @intCast(isize, y);
                if (self.vec2i(veci(xi, yi))) |src| {
                    if (self.vec2i(veci(yi, xi))) |dest| {
                        self.items[dest] = self.items_copy[src];
                    }
                }
            }
        }
    }

    fn reverse_rows(self: *@This()) void {
        std.mem.copy(Block, &self.items_copy, &self.items);

        var y: usize = 0;
        while (y < self.size.y) : (y += 1) {
            var yi = @intCast(isize, y);
            var x: usize = 0;
            while (x < self.size.x) : (x += 1) {
                var xi = @intCast(isize, x);
                if (self.vec2i(veci(xi, yi))) |src| {
                    if (self.vec2i(veci(xi, @intCast(isize, self.size.y) - yi - 1))) |dest| {
                        self.items[dest] = self.items_copy[src];
                    }
                }
            }
        }
    }
};
