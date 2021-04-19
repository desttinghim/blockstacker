const std = @import("std");
const seizer = @import("seizer");
const math = seizer.math;
const Vec2f = math.Vec(2, f32);
const vec2f = Vec2f.init;
const Texture = @import("./texture.zig").Texture;
const flat = @import("flat_render.zig");
const FlatRenderer = flat.FlatRenderer;
const Rect = flat.Rect;
const Quad = flat.Quad;

fn getNineSliceQuads(pos: Vec2f, size: Vec2f, tile_size: Vec2f) [9]Quad {
    const inner_size = vec2f(size.x - tile_size.x * 2, size.y - tile_size.y * 2);

    const x1 = pos.x;
    const x2 = pos.x + tile_size.x;
    const x3 = pos.x + size.x - tile_size.x;

    const y1 = pos.y;
    const y2 = pos.y + tile_size.y;
    const y3 = pos.y + size.y - tile_size.y;

    return [9]Quad{
        .{ .pos = vec2f(x1, y1), .size = tile_size },
        .{ .pos = vec2f(x2, y1), .size = vec2f(inner_size.x, tile_size.y) },
        .{ .pos = vec2f(x3, y1), .size = tile_size },

        .{ .pos = vec2f(x1, y2), .size = vec2f(tile_size.x, inner_size.y) },
        .{ .pos = vec2f(x2, y2), .size = inner_size },
        .{ .pos = vec2f(x3, y2), .size = vec2f(tile_size.x, inner_size.y) },

        .{ .pos = vec2f(x1, y3), .size = tile_size },
        .{ .pos = vec2f(x2, y3), .size = vec2f(inner_size.x, tile_size.y) },
        .{ .pos = vec2f(x3, y3), .size = tile_size },
    };
}

fn getNineSliceRect(pos1: Vec2f, pos2: Vec2f) [9]Rect {
    const w = pos2.x - pos1.x;
    const h = pos2.y - pos1.y;
    const h1 = pos1.x;
    const h2 = pos1.x + w / 3;
    const h3 = pos1.x + 2 * w / 3;
    const h4 = pos2.x;
    const v1 = pos1.y;
    const v2 = pos1.y + h / 3;
    const v3 = pos1.y + 2 * h / 3;
    const v4 = pos2.y;
    return [9]Rect{
        .{ .min = vec2f(h1, v1), .max = vec2f(h2, v2) },
        .{ .min = vec2f(h2, v1), .max = vec2f(h3, v2) },
        .{ .min = vec2f(h3, v1), .max = vec2f(h4, v2) },

        .{ .min = vec2f(h1, v2), .max = vec2f(h2, v3) },
        .{ .min = vec2f(h2, v2), .max = vec2f(h3, v3) },
        .{ .min = vec2f(h3, v2), .max = vec2f(h4, v3) },

        .{ .min = vec2f(h1, v3), .max = vec2f(h2, v4) },
        .{ .min = vec2f(h2, v3), .max = vec2f(h3, v4) },
        .{ .min = vec2f(h3, v3), .max = vec2f(h4, v4) },
    };
}

pub const NineSlice = struct {
    rects: [9]Rect,
    quads: [9]Quad,

    pub fn init(texPos1: Vec2f, texPos2: Vec2f, pos: Vec2f, size: Vec2f, tile_size: Vec2f) @This() {
        return @This(){
            .rects = getNineSliceRect(texPos1, texPos2),
            .quads = getNineSliceQuads(pos, size, tile_size),
        };
    }
};

pub fn drawNineSlice(renderer: *FlatRenderer, texture: Texture, nineslice: NineSlice) void {
    for (nineslice.quads) |quad, i| {
        renderer.drawTextureExt(texture, quad.pos, .{ .size = quad.size, .rect = nineslice.rects[i] });
    }
}
