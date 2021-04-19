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
const PieceType = @import("piece.zig").PieceType;
const util = @import("util.zig");
const get_score = @import("score.zig").get_score;
const get_drop_delta = @import("score.zig").get_drop_delta;
const get_soft_drop_delta = @import("score.zig").get_soft_drop_delta;

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
    piece_pos: Veci,
    inputs: Inputs,
    last_time: f64,
    bag: [7]PieceType,
    grab: usize,
    cleared_rows: usize,
    score: usize,
    level: usize,
    level_at: usize,

    // Rendering variables
    flat: FlatRenderer,
    font: FontRenderer,
    tileset_tex: Texture,
    score_text: []u8,
    level_text: []u8,
    lines_text: []u8,
};
var ctx: Context = undefined;

pub fn onInit() !void {
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png");
    var load_font = async FontRenderer.initFromFile(allocator, "assets/PressStart2P_8.fnt");
    var level: usize = 0;

    ctx = .{
        .grid = try Grid.init(allocator, vec(10, 20)),
        .piece = Piece.init(),
        .piece_pos = veci(0, 0),
        .inputs = .{
            .down = .Released,
            .left = .Released,
            .right = .Released,
            .rot_ws = .Released,
            .rot_cw = .Released,
        },
        .last_time = 0,
        .bag = Piece.shuffled_bag(),
        .grab = 0,
        .cleared_rows = 0,
        .score = 0,
        .level = level,
        .level_at = level * 10,

        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
        .score_text = try std.fmt.allocPrint(allocator, "{}", .{0}),
        .level_text = try std.fmt.allocPrint(allocator, "{}", .{0}),
        .lines_text = try std.fmt.allocPrint(allocator, "{}", .{0}),
    };

    grab_next_piece();
}

fn grab_next_piece() void {
    var next = ctx.bag[ctx.grab];
    ctx.piece_pos = ctx.piece.set_type(next);
    ctx.grab += 1;
    if (ctx.grab >= ctx.bag.len) {
        ctx.grab = 0;
        ctx.bag = Piece.shuffled_bag();
    }
}

pub fn onDeinit() void {
    allocator.free(ctx.score_text);
    allocator.free(ctx.level_text);
    allocator.free(ctx.lines_text);
    ctx.grid.deinit();
    ctx.font.deinit();
    ctx.flat.deinit();
    _ = gpa.deinit();
}

const InputState = enum {
    JustPressed,
    Pressed,
    Released,
};

const Inputs = struct {
    down: InputState,
    left: InputState,
    right: InputState,
    rot_cw: InputState,
    rot_ws: InputState,
};

pub fn onEvent(event: seizer.event.Event) !void {
    switch (event) {
        .KeyDown => |e| switch (e.scancode) {
            .Z, .COMMA => ctx.inputs.rot_ws = .JustPressed,
            .X, .PERIOD => ctx.inputs.rot_cw = .JustPressed,
            .A, .LEFT => ctx.inputs.left = .JustPressed,
            .D, .RIGHT => ctx.inputs.right = .JustPressed,
            .S, .DOWN => ctx.inputs.down = .JustPressed,

            .ESCAPE => seizer.quit(),
            else => {},
        },
        .KeyUp => |e| switch (e.scancode) {
            .Z, .COMMA => ctx.inputs.rot_ws = .Released,
            .X, .PERIOD => ctx.inputs.rot_cw = .Released,
            .A, .LEFT => ctx.inputs.left = .Released,
            .D, .RIGHT => ctx.inputs.right = .Released,
            .S, .DOWN => ctx.inputs.down = .Released,

            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .DPAD_DOWN => ctx.inputs.down = .JustPressed,
            .DPAD_LEFT => ctx.inputs.left = .JustPressed,
            .DPAD_RIGHT => ctx.inputs.right = .JustPressed,
            // .START => toggle_menu = true,
            .A => ctx.inputs.rot_ws = .JustPressed,
            .B => ctx.inputs.rot_cw = .JustPressed,
            else => |num| {},
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

    f.drawTextureExt(ctx.tileset_tex, pos.intToFloat(f32), .{
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
                draw_tile(f, block.some, offset.addv(pos.scale(16)));
            }
        }
    }
}

fn draw_grid_offset_bg(f: *FlatRenderer, offset: Veci, size: Vec, grid: []Block) void {
    for (grid) |block, i| {
        if (block == .none) {
            if (util.i2vec(size, i)) |pos| {
                draw_tile(f, 8, offset.addv(pos.scale(16)));
            }
        }
    }
}

pub fn render(alpha: f64) !void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);
    const grid_offset = vec(
        @intCast(usize, @divTrunc(screen_size.x, 2)) - @divTrunc(ctx.grid.size.x * 16, 2),
        0,
    ).intCast(isize);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size_f);

    draw_grid_offset_bg(&ctx.flat, grid_offset, ctx.grid.size, ctx.grid.items);
    draw_grid_offset(&ctx.flat, grid_offset, ctx.grid.size, ctx.grid.items);
    draw_grid_offset(&ctx.flat, grid_offset.addv(ctx.piece_pos.scale(16)), ctx.piece.size, &ctx.piece.items);
    var y: isize = 0;
    while (y < ctx.grid.size.y) : (y += 1) {
        draw_tile(&ctx.flat, 0, grid_offset.add(-16, y * 16));
        draw_tile(&ctx.flat, 0, grid_offset.add(@intCast(isize, ctx.grid.size.x) * 16, y * 16));
    }

    ctx.font.drawText(&ctx.flat, "SCORE:", vec(0, 0).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, ctx.score_text, vec(0, 32).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LEVEL:", vec(0, 64).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, ctx.level_text, vec(0, 96).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LINES:", vec(0, 128).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, ctx.lines_text, vec(0, 160).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.flat.flush();
}

pub fn update(current_time: f64, delta: f64) anyerror!void {
    {
        var new_piece = ctx.piece;
        var new_pos = ctx.piece_pos;
        if (ctx.inputs.right == .JustPressed) new_pos = new_pos.add(1, 0);
        if (ctx.inputs.left == .JustPressed) new_pos = new_pos.sub(1, 0);
        if (ctx.inputs.rot_ws == .JustPressed) new_piece.rotate_ws();
        if (ctx.inputs.rot_cw == .JustPressed) new_piece.rotate_cw();

        if (!new_piece.collides_with(new_pos, &ctx.grid)) {
            ctx.piece = new_piece;
            ctx.piece_pos = new_pos;
        }
    }

    if ((ctx.inputs.down == .Pressed and ctx.last_time > get_soft_drop_delta()) or
        ctx.inputs.down == .JustPressed or current_time - ctx.last_time > get_drop_delta(ctx.level))
    {
        var new_pos = ctx.piece_pos;
        new_pos = new_pos.add(0, 1);
        if (ctx.piece.collides_with(new_pos, &ctx.grid)) {
            // Integrate
            ctx.piece.integrate_with(ctx.piece_pos, &ctx.grid);
            grab_next_piece();
            var lines = try ctx.grid.clear_rows();
            ctx.cleared_rows += lines;
            ctx.score += get_score(lines, ctx.level);

            allocator.free(ctx.score_text);
            ctx.score_text = try std.fmt.allocPrint(allocator, "{}", .{ctx.score});
            allocator.free(ctx.level_text);
            ctx.level_text = try std.fmt.allocPrint(allocator, "{}", .{ctx.level});
            allocator.free(ctx.lines_text);
            ctx.lines_text = try std.fmt.allocPrint(allocator, "{}", .{ctx.cleared_rows});

            if (ctx.cleared_rows > ctx.level_at and ctx.level < 9) {
                ctx.level += 1;
                ctx.level_at += 10;
            }

            // Turn off down input when new piece is made
            ctx.inputs.down = .Released;
        } else {
            ctx.piece_pos = new_pos;
        }
        ctx.last_time = current_time;
    }

    // Update input state
    if (ctx.inputs.down == .JustPressed) ctx.inputs.down = .Pressed;
    if (ctx.inputs.left == .JustPressed) ctx.inputs.left = .Pressed;
    if (ctx.inputs.right == .JustPressed) ctx.inputs.right = .Pressed;
    if (ctx.inputs.rot_ws == .JustPressed) ctx.inputs.rot_ws = .Pressed;
    if (ctx.inputs.rot_cw == .JustPressed) ctx.inputs.rot_cw = .Pressed;
}
