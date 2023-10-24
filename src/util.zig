const std = @import("std");
const seizer = @import("seizer");
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const geom = seizer.geometry;

pub fn contains(size: Vec, point: Veci) bool {
    return point.x >= 0 and point.y >= 0 and point.x < size.x and point.y < size.y;
}

pub fn vec2i(size: Vec, pos: Veci) ?usize {
    return if (contains(size, pos)) @as(usize, @intCast(pos.x)) + (size.x * @as(usize, @intCast(pos.y))) else null;
}

pub fn i2vec(size: Vec, i: usize) ?Veci {
    return if (i < size.x * size.y) veci(@as(isize, @intCast(i % size.x)), @as(isize, @intCast(i / size.x))) else null;
}

/// Shuffles a slice in place
pub fn shuffle(comptime T: type, rand: std.rand.Random, slice: []T) void {
    var i: usize = 0;
    while (i < slice.len) : (i += 1) {
        var a = rand.intRangeLessThanBiased(usize, 0, slice.len);
        const current = slice[i];
        slice[i] = slice[a];
        slice[a] = current;
    }
}

const Texture = seizer.Texture;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
pub fn pixelToTex(tex: *Texture, pixel: Vec2) Vec2f {
    return vec2f(
        @as(f32, @floatFromInt(pixel.x)) / @as(f32, @floatFromInt(tex.size.x)),
        @as(f32, @floatFromInt(pixel.y)) / @as(f32, @floatFromInt(tex.size.y)),
    );
}

pub const Tilemap = struct {
    blocks: []geom.AABB(f32),
    ninepatches: []NinepatchInfo,

    pub fn fromMemory(gpa: std.mem.Allocator, contents: []const u8) !Tilemap {
        var parsed = try std.json.parseFromSlice(Tilemap.JSON, gpa, contents, .{});
        defer parsed.deinit();
        const tilemap = try parsed.value.convert(gpa);
        return tilemap;
    }
    pub fn deinit(this: @This(), alloc: std.mem.Allocator) void {
        alloc.free(this.blocks);
        alloc.free(this.ninepatches);
    }

    const NinepatchInfo = struct {
        size: usize,
        bounds: geom.AABB(f32),
    };

    const NinepatchJSONInfo = struct {
        size: usize,
        bounds: [4]i32,
    };

    const JSON = struct {
        blocks: [][4]i32,
        ninepatches: []NinepatchJSONInfo,
        fn convert(this: @This(), alloc: std.mem.Allocator) !Tilemap {
            const blocks = try alloc.alloc(geom.AABB(f32), this.blocks.len);
            for (this.blocks, 0..) |block, i| {
                blocks[i] = .{
                    .min = .{
                        @floatFromInt(block[0]),
                        @floatFromInt(block[1]),
                    },
                    .max = .{
                        @floatFromInt(block[0] + block[2]),
                        @floatFromInt(block[1] + block[3]),
                    },
                };
            }
            const ninepatches = try alloc.alloc(NinepatchInfo, this.ninepatches.len);
            for (this.ninepatches, 0..) |ninepatch, i| {
                ninepatches[i] = .{
                    .size = ninepatch.size,
                    .bounds = .{
                        .min = .{
                            @floatFromInt(ninepatch.bounds[0]),
                            @floatFromInt(ninepatch.bounds[1]),
                        },
                        .max = .{
                            @floatFromInt(ninepatch.bounds[0] + ninepatch.bounds[2]),
                            @floatFromInt(ninepatch.bounds[1] + ninepatch.bounds[3]),
                        },
                    },
                };
            }
            return Tilemap{
                .blocks = blocks,
                .ninepatches = ninepatches,
            };
        }
    };
};
