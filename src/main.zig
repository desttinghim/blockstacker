const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;
const Block = @import("grid.zig").Block;
const Grid = @import("grid.zig").Grid;
const Piece = @import("piece.zig").Piece;
const util = @import("util.zig");

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
    down_pressed: bool,
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
        .piece = Piece.init(veci(0, 0)),
        .down_pressed = false,
        .last_time = 0,
        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
    };

    ctx.grid.set(veci(9, 19), .{ .some = 0 });
    ctx.piece.set_type(.I);
}

pub fn onDeinit() void {
    ctx.grid.deinit();
    ctx.font.deinit();
    ctx.flat.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    switch (event) {
        .KeyDown => |e| {
            var new_piece = ctx.piece;
            switch (e.scancode) {
                .Z, .COMMA => new_piece.rotate_ws(),
                .X, .PERIOD => new_piece.rotate_cw(),
                .A, .LEFT => new_piece.move_left(),
                .D, .RIGHT => new_piece.move_right(),
                .S, .DOWN => {
                    ctx.down_pressed = true;
                    new_piece.move_down();
                },

                .ESCAPE => seizer.quit(),
                else => {},
            }
            if (!new_piece.collides_with(&ctx.grid)) {
                ctx.piece = new_piece;
            }
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

fn draw_tile(f: *FlatRenderer, id: u16, pos: Veci) void {
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

fn draw_grid_offset(f: *FlatRenderer, offset: Veci, size: Vec, grid: []Block) void {
    for (grid) |block, i| {
        if (block == .some) {
            if (util.i2vec(size, i)) |pos| {
                draw_tile(f, block.some, offset.addv(pos));
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

    draw_grid_offset(&ctx.flat, veci(0, 0), ctx.grid.size, ctx.grid.items);
    draw_grid_offset(&ctx.flat, ctx.piece.pos, ctx.piece.size, &ctx.piece.items);

    ctx.flat.flush();
}

pub fn update(current_time: f64, delta: f64) anyerror!void {
    if (ctx.down_pressed) {
        ctx.last_time = current_time;
        ctx.down_pressed = false;
    }
    if (current_time - ctx.last_time > 1.0) {
        var new_piece = ctx.piece;
        new_piece.move_down();
        if (new_piece.collides_with(&ctx.grid)) {
            // Integrate
        } else {
            ctx.piece = new_piece;
        }
        ctx.last_time = current_time;
    }
}
