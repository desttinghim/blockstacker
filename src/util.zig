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
    return if (contains(size, pos)) @intCast(usize, pos.x) + (size.x * @intCast(usize, pos.y)) else null;
}

pub fn i2vec(size: Vec, i: usize) ?Veci {
    return if (i < size.x * size.y) veci(@intCast(isize, i % size.x), @intCast(isize, i / size.x)) else null;
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
        @intToFloat(f32, pixel.x) / @intToFloat(f32, tex.size.x),
        @intToFloat(f32, pixel.y) / @intToFloat(f32, tex.size.y),
    );
}

pub const Tilemap = struct {
    blocks: []geom.AABB,
    ninepatches: []NinepatchInfo,

    pub fn deinit(this: @This(), alloc: std.mem.Allocator) void {
        alloc.free(this.blocks);
        alloc.free(this.ninepatches);
    }

    const NinepatchInfo = struct {
        size: usize,
        bounds: geom.AABB,
    };

    const NinepatchJSONInfo = struct {
        size: usize,
        bounds: [4]i32,
    };

    const JSON = struct {
        blocks: [][4]i32,
        ninepatches: []NinepatchJSONInfo,
        fn convert(this: @This(), alloc: std.mem.Allocator) !Tilemap {
            const blocks = try alloc.alloc(geom.AABB, this.blocks.len);
            for (this.blocks) |block, i| {
                blocks[i] = .{ block[0], block[1], block[0] + block[2], block[1] + block[3] };
            }
            const ninepatches = try alloc.alloc(NinepatchInfo, this.ninepatches.len);
            for (this.ninepatches) |ninepatch, i| {
                ninepatches[i] = .{
                    .size = ninepatch.size,
                    .bounds = .{ ninepatch.bounds[0], ninepatch.bounds[1], ninepatch.bounds[0] + ninepatch.bounds[2], ninepatch.bounds[1] + ninepatch.bounds[3] },
                };
            }
            return Tilemap{
                .blocks = blocks,
                .ninepatches = ninepatches,
            };
        }
    };
};

pub fn load_tilemap_file(alloc: std.mem.Allocator, path: []const u8, maxsize: usize) !Tilemap {
    const file_contents = try seizer.fetch(alloc, path, maxsize);
    defer alloc.free(file_contents);

    var tokenstream = std.json.TokenStream.init(file_contents);
    const options = std.json.ParseOptions{ .allocator = alloc };
    var tilemap_json = try std.json.parse(Tilemap.JSON, &tokenstream, options);
    defer std.json.parseFree(Tilemap.JSON, tilemap_json, options);
    const tilemap = try tilemap_json.convert(alloc);
    return tilemap;
}
