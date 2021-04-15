const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;
const Grid = @import("grid.zig").Grid;
const Piece = @import("grid.zig").Piece;

pub fn main() void {
    seizer.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .render = render,
        .update = update,
        .window = .{
            .title = "Blockstacker",
            .width = 480,
            .height = 320,
        },
    });
}

// Global variables
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

const Context = struct {
    // Game variables
    grid: Grid,
    piece: Piece,
    last_time: f64,

    // Rendering variables
    flat: FlatRenderer,
    font: FontRenderer,
    tileset_tex: Texture,
};
var ctx: Context = undefined;

pub fn onInit() !void {
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png");
    var load_font = async FontRenderer.initFromFile(allocator, "assets/PressStart2P_8.fnt");

    ctx = .{
        .grid = try Grid.init(allocator, vec(10, 20)),
        .piece = try Piece.init(allocator, vec(0, 0)),
        .last_time = 0,
        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
    };

    ctx.grid.set(vec(9, 19), .{ .some = 0 });
    ctx.piece.set_type(.I);
}

pub fn onDeinit() void {
    ctx.grid.deinit();
    ctx.piece.deinit();
    ctx.font.deinit();
    ctx.flat.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    switch (event) {
        .Quit => seizer.quit(),
        else => {},
    }
}

fn draw_tile(f: *FlatRenderer, id: u16, pos: Vec) void {
    const TILE_W = 16;
    const TILE_H = 16;

    const tileposy = id / (ctx.tileset_tex.size.x / TILE_W);
    const tileposx = id - (tileposy * (ctx.tileset_tex.size.x / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));

    f.drawTextureExt(ctx.tileset_tex, pos.scale(16).intToFloat(f32), .{
        .size = vec2f(16, 16),
        .rect = .{
            .min = texpos1,
            .max = texpos2,
        },
    });
}

fn draw_grid_offset(f: *FlatRenderer, offset: Vec, g: *Grid) void {
    for (g.items) |block, i| {
        if (block == .some) {
            if (g.i2vec(i)) |pos| {
                draw_tile(f, block.some, pos);
            }
        }
    }
}

pub fn render(alpha: f64) !void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size_f);

    draw_grid_offset(&ctx.flat, vec(0, 0), &ctx.grid);
    draw_grid_offset(&ctx.flat, ctx.piece.pos, &ctx.piece.grid);

    ctx.flat.flush();
}

pub fn update(current_time: f64, delta: f64) anyerror!void {
    if (current_time - ctx.last_time > 1.0) {
        ctx.piece.rotate_ws();
        ctx.last_time = current_time;
    }
}
