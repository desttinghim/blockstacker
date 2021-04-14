const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec = seizer.math.Vec(2, u8);
const vec = Vec.init;

pub fn main() void {
    seizer.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .render = render,
        .update = update,
        .window = .{
            .title = "Blockstacker",
        },
    });
}

// Global variables

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

const Block = union(enum) {
    none: void,
    wall: void,
    some: u8,
};

const Grid = struct {
    items: []Block,
    items_copy: []Block,
    size: Vec,
    allocator: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator, size: Vec) !@This() {
        const items = try alloc.alloc(Block, size.x * size.y);
        const items_copy = try alloc.alloc(Block, size.x * size.y);
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

    fn vec2i(self: *@This(), pos: Vec) u8 {
        return pos.x + (self.size.x * pos.y);
    }

    fn i2vec(self: *@This(), i: u8) Vec {
        return vec(i % self.size.x, i / self.size.x);
    }

    // pub fn set(self: *@This(), pos: Vec, val: Block) void {}

    // pub fn get(self: *@This(), pos: Vec) Block {}

    // pub fn swap(self: *@This(), pos1: Vec, pos2: Vec) void {}

    pub fn clear(self: *@This()) void {
        std.mem.set(self.items, Block.none);
        std.mem.set(self.items_copy, Block.none);
    }

    fn transpose(self: *@This()) void {
        std.mem.copy(self.items_copy, self.items);

        var x: u8 = 0;
        while (x < self.size.x) : (x += 1) {
            var y: u8 = 0;
            while (y < self.size.y) : (y += 1) {
                self.items[self.vec2i(vec(y, x))] = self.items_copy[self.vec2i(vec(x, y))];
            }
        }
    }

    fn reverse_rows(self: *@This()) void {
        std.mem.copy(self.items_copy, self.items);

        var y: u8 = 0;
        while (y < self.size.y) : (y += 1) {
            var x: u8 = 0;
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

const Piece = struct {
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

var grid: Grid = undefined;
var piece: Piece = undefined;

pub fn onInit() !void {
    grid = try Grid.init(allocator, vec(10, 20));
    piece = try Piece.init(allocator, vec(0, 0));
}

pub fn onDeinit() void {
    grid.deinit();
    piece.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    switch (event) {
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn render(alpha: f64) !void {
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn update(currentTime: f64, delta: f64) anyerror!void {}
