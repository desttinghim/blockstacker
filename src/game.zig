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
const Context = @import("context.zig").Context;
const NullScreen = @import("context.zig").NullScreen;
const PauseScreen = @import("pause.zig").PauseScreen;
const NineSlice = @import("nineslice.zig").NineSlice;
const drawNineSlice = @import("nineslice.zig").drawNineSlice;

pub const GameScreen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .update = update,
    .render = render,
};

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

fn get_bag() [7]PieceType {
    var tempbag: [7]PieceType = undefined;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        tempbag[i] = @intToEnum(PieceType, i);
    }
    return tempbag;
}

fn shuffled_bag(ctx: *Context) [7]PieceType {
    var tempbag = get_bag();
    util.shuffle(PieceType, ctx.rand, &tempbag);
    return tempbag;
}

var grid: Grid = undefined;
var piece: Piece = undefined;
var piece_pos: Veci = undefined;
var inputs: Inputs = undefined;
var last_time: f64 = undefined;
var bag: [7]PieceType = undefined;
var grab: usize = undefined;
var cleared_rows: usize = undefined;
var score: usize = undefined;
var level: usize = undefined;
var level_at: usize = undefined;

var score_text: []u8 = undefined;
var level_text: []u8 = undefined;
var lines_text: []u8 = undefined;

pub fn set_level(level_start: usize) void {
    level = level_start;
    level_at = level_start * 10 + 10;
}

fn fail_to_null(ctx: *Context) void {
    ctx.switch_screen(NullScreen) catch @panic("Can't switch to NullScreen");
}

/// Resets EVERYTHING to default
pub fn init(ctx: *Context) void {
    grid = Grid.init(ctx.allocator, vec(10, 20)) catch |e| {
        fail_to_null(ctx);
        return;
    };
    piece = Piece.init();
    piece_pos = veci(0, 0);
    inputs = .{
        .down = .Released,
        .left = .Released,
        .right = .Released,
        .rot_ws = .Released,
        .rot_cw = .Released,
    };
    last_time = 0;
    bag = shuffled_bag(ctx);
    grab = 0;
    cleared_rows = 0;
    score = 0;
    level = 0;
    level_at = 10;

    score_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch |e| {
        fail_to_null(ctx);
        return;
    };
    level_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch |e| {
        fail_to_null(ctx);
        return;
    };
    lines_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch |e| {
        fail_to_null(ctx);
        return;
    };

    grab_next_piece(ctx);
}

pub fn deinit(ctx: *Context) void {
    ctx.allocator.free(score_text);
    ctx.allocator.free(level_text);
    ctx.allocator.free(lines_text);
    grid.deinit();
}

pub fn event(ctx: *Context, evt: seizer.event.Event) void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .Z, .COMMA => inputs.rot_ws = .JustPressed,
            .X, .PERIOD => inputs.rot_cw = .JustPressed,
            .A, .LEFT => inputs.left = .JustPressed,
            .D, .RIGHT => inputs.right = .JustPressed,
            .S, .DOWN => inputs.down = .JustPressed,

            .ESCAPE => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            else => {},
        },
        .KeyUp => |e| switch (e.scancode) {
            .Z, .COMMA => inputs.rot_ws = .Released,
            .X, .PERIOD => inputs.rot_cw = .Released,
            .A, .LEFT => inputs.left = .Released,
            .D, .RIGHT => inputs.right = .Released,
            .S, .DOWN => inputs.down = .Released,

            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .DPAD_DOWN => inputs.down = .JustPressed,
            .DPAD_LEFT => inputs.left = .JustPressed,
            .DPAD_RIGHT => inputs.right = .JustPressed,
            .START => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            .A => inputs.rot_ws = .JustPressed,
            .B => inputs.rot_cw = .JustPressed,
            else => {},
        },
        .ControllerButtonUp => |cbutton| switch (cbutton.button) {
            .DPAD_DOWN => inputs.down = .Released,
            .DPAD_LEFT => inputs.left = .Released,
            .DPAD_RIGHT => inputs.right = .Released,
            .A => inputs.rot_ws = .Released,
            .B => inputs.rot_cw = .Released,
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn update(ctx: *Context, current_time: f64, delta: f64) void {
    {
        var new_piece = piece;
        var new_pos = piece_pos;
        if (inputs.right == .JustPressed) new_pos = new_pos.add(1, 0);
        if (inputs.left == .JustPressed) new_pos = new_pos.sub(1, 0);
        if (inputs.rot_ws == .JustPressed) new_piece.rotate_ws();
        if (inputs.rot_cw == .JustPressed) new_piece.rotate_cw();

        if (!new_piece.collides_with(new_pos, &grid)) {
            piece = new_piece;
            piece_pos = new_pos;
        }
    }

    if ((inputs.down == .Pressed and last_time > get_soft_drop_delta()) or
        inputs.down == .JustPressed or current_time - last_time > get_drop_delta(level))
    {
        var new_pos = piece_pos;
        new_pos = new_pos.add(0, 1);
        if (piece.collides_with(new_pos, &grid)) {
            // Integrate
            piece.integrate_with(piece_pos, &grid);
            grab_next_piece(ctx);
            var lines = grid.clear_rows() catch |e| {
                fail_to_null(ctx);
                return;
            };
            // Checks to see if the new piece collides with the grid.
            // If it is, then the game is over!
            if (piece.collides_with(piece_pos, &grid)) {
                ctx.push_screen(GameOverScreen) catch |e| @panic("Could not push screen");
            }
            cleared_rows += lines;
            score += get_score(lines, level);

            ctx.allocator.free(score_text);
            ctx.allocator.free(level_text);
            ctx.allocator.free(lines_text);

            score_text = std.fmt.allocPrint(ctx.allocator, "{}", .{score}) catch |e| {
                fail_to_null(ctx);
                return;
            };
            level_text = std.fmt.allocPrint(ctx.allocator, "{}", .{level}) catch |e| {
                fail_to_null(ctx);
                return;
            };
            lines_text = std.fmt.allocPrint(ctx.allocator, "{}", .{cleared_rows}) catch |e| {
                fail_to_null(ctx);
                return;
            };

            if (cleared_rows > level_at and level < 9) {
                level += 1;
                level_at += 10;
            }

            // Turn off down input when new piece is made
            inputs.down = .Released;
        } else {
            piece_pos = new_pos;
        }
        last_time = current_time;
    }

    // Update input state
    if (inputs.down == .JustPressed) inputs.down = .Pressed;
    if (inputs.left == .JustPressed) inputs.left = .Pressed;
    if (inputs.right == .JustPressed) inputs.right = .Pressed;
    if (inputs.rot_ws == .JustPressed) inputs.rot_ws = .Pressed;
    if (inputs.rot_cw == .JustPressed) inputs.rot_cw = .Pressed;
}

pub fn render(ctx: *Context, alpha: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);
    const grid_offset = vec(
        @intCast(usize, @divTrunc(screen_size.x, 2)) - @divTrunc(grid.size.x * 16, 2),
        0,
    ).intCast(isize);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size_f);

    draw_grid_offset_bg(ctx, grid_offset, grid.size, grid.items);
    draw_grid_offset(ctx, grid_offset, grid.size, grid.items);
    draw_grid_offset(ctx, grid_offset.addv(piece_pos.scale(16)), piece.size, &piece.items);
    var y: isize = 0;
    while (y < grid.size.y) : (y += 1) {
        draw_tile(ctx, 0, grid_offset.add(-16, y * 16));
        draw_tile(ctx, 0, grid_offset.add(@intCast(isize, grid.size.x) * 16, y * 16));
    }

    ctx.font.drawText(&ctx.flat, "SCORE:", vec(0, 0).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, score_text, vec(0, 32).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LEVEL:", vec(0, 64).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, level_text, vec(0, 96).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LINES:", vec(0, 128).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, lines_text, vec(0, 160).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.flat.flush();
}

/// Internal functions
fn grab_next_piece(ctx: *Context) void {
    var next = bag[grab];
    piece_pos = piece.set_type(next);
    grab += 1;
    if (grab >= bag.len) {
        grab = 0;
        bag = shuffled_bag(ctx);
    }
}

fn draw_tile(ctx: *Context, id: u16, pos: Veci) void {
    const TILE_W = 16;
    const TILE_H = 16;

    const tileposy = id / (ctx.tileset_tex.size.x / TILE_W);
    const tileposx = id - (tileposy * (ctx.tileset_tex.size.x / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));

    ctx.flat.drawTextureExt(ctx.tileset_tex, pos.intToFloat(f32), .{
        .size = vec2f(16, 16),
        .rect = .{
            .min = texpos1,
            .max = texpos2,
        },
    });
}

fn draw_grid_offset(ctx: *Context, offset: Veci, size: Vec, dgrid: []Block) void {
    for (dgrid) |block, i| {
        if (block == .some) {
            if (util.i2vec(size, i)) |pos| {
                draw_tile(ctx, block.some, offset.addv(pos.scale(16)));
            }
        }
    }
}

fn draw_grid_offset_bg(ctx: *Context, offset: Veci, size: Vec, dgrid: []Block) void {
    for (dgrid) |block, i| {
        if (block == .none) {
            if (util.i2vec(size, i)) |pos| {
                draw_tile(ctx, 8, offset.addv(pos.scale(16)));
            }
        }
    }
}

/// Game Over Screen
pub const GameOverScreen = .{
    .init = go_init,
    .deinit = go_deinit,
    .event = go_event,
    .update = go_update,
    .render = go_render,
};

fn pixelToTex(tex: *Texture, pixel: Veci) Vec2f {
    return vec2f(
        @intToFloat(f32, pixel.x) / @intToFloat(f32, tex.size.x),
        @intToFloat(f32, pixel.y) / @intToFloat(f32, tex.size.y),
    );
}

var button_pressed = false;

fn go_init(ctx: *Context) void {
    button_pressed = false;
}

fn go_deinit(ctx: *Context) void {}

fn go_event(ctx: *Context, evt: seizer.event.Event) void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            else => button_pressed = true,
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

fn go_update(ctx: *Context, current_time: f64, delta: f64) void {
    if (button_pressed) {
        ctx.add_score("AAAAAAAAAA", score) catch |e| @panic("Couldn't add score to high score list");
        ctx.pop_screen();
        ctx.switch_screen(GameScreen) catch |e| @panic("Couldn't switch screen");
    }
}

fn go_render(ctx: *Context, alpha: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);
    const nineslice_size = screen_size_f.divv(vec2f(2, 2));
    const nineslice_pos = screen_size_f.scaleDiv(2).subv(nineslice_size.scaleDiv(2));

    var nineslice = NineSlice.init(
        pixelToTex(&ctx.tileset_tex, veci(0, 48)),
        pixelToTex(&ctx.tileset_tex, veci(48, 96)),
        nineslice_pos,
        nineslice_size,
        vec2f(16, 16),
    );
    drawNineSlice(&ctx.flat, ctx.tileset_tex, nineslice);

    ctx.font.drawText(&ctx.flat, "GAME OVER!", nineslice_pos.add(nineslice_size.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    ctx.flat.flush();
}
