const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const Veci = seizer.math.Vec(2, isize);
const veci = Veci.init;
const Vec = seizer.math.Vec(2, usize);
const vec = Vec.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Texture = seizer.Texture;
const SpriteBatch = seizer.batch.SpriteBatch;
const BitmapFont = seizer.font.Bitmap;
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
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
const MenuAndItem = @import("menu.zig").MenuAndItem;
const MainMenuScreen = @import("main_menu.zig").MainMenuScreen;
const SetupScreen = @import("main_menu.zig").SetupScreen;
const ScoreEntry = @import("score.zig").ScoreEntry;
const geom = @import("geometry.zig");
const ui = @import("ui/default.zig");

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
    hardDrop: InputState,
    down: InputState,
    left: InputState,
    right: InputState,
    rot_cw: InputState,
    rot_ws: InputState,
    hold: InputState,
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

pub const Setup = struct {
    level: u8 = 0,
};

var grid: Grid = undefined;
var piece: Piece = undefined;
var piece_pos: Veci = undefined;
var piece_drop_pos: Veci = undefined;
var next_piece: Piece = undefined;
var held_piece: ?Piece = null;
var can_hold = true;
var inputs: Inputs = undefined;
var last_time: f64 = undefined;
var bag: [14]PieceType = undefined;
var grab: usize = undefined;
var level_at: usize = undefined;
var clock: usize = 0;
var score: ScoreEntry = undefined;

const REPEAT_TIME = 0.1;
var move_left_timer: f64 = undefined;
var move_right_timer: f64 = undefined;

var score_text: []u8 = undefined;
var level_text: []u8 = undefined;
var lines_text: []u8 = undefined;

pub fn set_level(level_start: u8) void {
    score.startingLevel = level_start;
    score.level = level_start;
    level_at = level_start * 10 + 10;
}

fn fail_to_null(ctx: *Context) void {
    ctx.switch_screen(NullScreen) catch @panic("Can't switch to NullScreen");
}

/// Resets EVERYTHING to default
pub fn init(ctx: *Context) void {
    grid = Grid.init(ctx.allocator, vec(10, 20)) catch {
        fail_to_null(ctx);
        return;
    };
    piece = Piece.init();
    piece_pos = veci(0, 0);
    next_piece = Piece.init();
    held_piece = null;
    can_hold = true;
    inputs = .{
        .hardDrop = .Released,
        .down = .Released,
        .left = .Released,
        .right = .Released,
        .rot_ws = .Released,
        .rot_cw = .Released,
        .hold = .Released,
    };
    last_time = 0;
    bag[0..7].* = shuffled_bag(ctx);
    bag[7..14].* = shuffled_bag(ctx);
    grab = 0;
    clock = 0;
    score = .{
        .timestamp = undefined,
        .score = 0,
        .startingLevel = undefined,
        .playTime = 0.0,
        .rowsCleared = 0,
        .level = undefined,
        .singles = 0,
        .doubles = 0,
        .triples = 0,
        .tetrises = 0,
    };
    set_level(ctx.setup.level);

    score_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch {
        fail_to_null(ctx);
        return;
    };
    level_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch {
        fail_to_null(ctx);
        return;
    };
    lines_text = std.fmt.allocPrint(ctx.allocator, "{}", .{0}) catch {
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
            .Z, .COMMA, .SPACE => inputs.rot_ws = .JustPressed,
            .X, .PERIOD => inputs.rot_cw = .JustPressed,
            .A, .LEFT => if (inputs.left != .Pressed) {
                inputs.left = .JustPressed;
            },
            .D, .RIGHT => if (inputs.right != .Pressed) {
                inputs.right = .JustPressed;
            },
            .S, .DOWN => if (inputs.right != .Pressed) {
                inputs.down = .JustPressed;
            },
            .W, .UP => if (inputs.right != .Pressed) {
                inputs.hardDrop = .JustPressed;
            },
            .TAB => if (inputs.hold != .Pressed) {
                inputs.hold = .JustPressed;
            },

            .ESCAPE => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            else => {},
        },
        .KeyUp => |e| switch (e.scancode) {
            .Z, .COMMA => inputs.rot_ws = .Released,
            .X, .PERIOD => inputs.rot_cw = .Released,
            .A, .LEFT => inputs.left = .Released,
            .D, .RIGHT => inputs.right = .Released,
            .S, .DOWN => inputs.down = .Released,
            .W, .UP => inputs.hardDrop = .Released,
            .TAB => inputs.hold = .Released,

            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .DPAD_UP => inputs.hardDrop = .JustPressed,
            .DPAD_DOWN => inputs.down = .JustPressed,
            .DPAD_LEFT => if (inputs.left != .Pressed) {
                inputs.left = .JustPressed;
            },
            .DPAD_RIGHT => if (inputs.right != .Pressed) {
                inputs.right = .JustPressed;
            },
            .START => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            .A => inputs.rot_ws = .JustPressed,
            .B => inputs.rot_cw = .JustPressed,
            .LEFTSHOULDER => inputs.hold = .JustPressed,
            else => {},
        },
        .ControllerButtonUp => |cbutton| switch (cbutton.button) {
            .DPAD_UP => inputs.hardDrop = .Released,
            .DPAD_DOWN => inputs.down = .Released,
            .DPAD_LEFT => inputs.left = .Released,
            .DPAD_RIGHT => inputs.right = .Released,
            .A => inputs.rot_ws = .Released,
            .B => inputs.rot_cw = .Released,
            .LEFTSHOULDER => inputs.hold = .Released,
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn update(ctx: *Context, current_time: f64, delta: f64) void {
    score.playTime += delta;
    {
        var new_piece = piece;
        var new_pos = piece_pos;

        move_right_timer -= delta;
        if (inputs.right == .JustPressed or (inputs.right == .Pressed and move_right_timer < 0)) {
            new_pos = new_pos.add(1, 0);
            move_right_timer = REPEAT_TIME;
        }

        move_left_timer -= delta;
        if (inputs.left == .JustPressed or (inputs.left == .Pressed and move_left_timer < 0)) {
            new_pos = new_pos.sub(1, 0);
            move_left_timer = REPEAT_TIME;
        }

        if (inputs.rot_ws == .JustPressed) new_piece.rotate_ws();
        if (inputs.rot_cw == .JustPressed) new_piece.rotate_cw();

        if (inputs.rot_ws == .JustPressed or inputs.rot_cw == .JustPressed) {
            ctx.audioEngine.play(ctx.sounds.rotate, ctx.clips.rotate);
        }

        if (!new_piece.collides_with(new_pos, &grid)) {
            piece = new_piece;
            piece_pos = new_pos;
        }
    }

    if (inputs.hold == .JustPressed and can_hold) {
        can_hold = false;
        const new_held_piece_type = piece.piece_type;
        if (held_piece) |held| {
            piece_pos = piece.set_type(held.piece_type);
        } else {
            grab_next_piece(ctx);
            held_piece = Piece.init();
        }
        _ = held_piece.?.set_type(new_held_piece_type);
    }

    const prev_score = score;

    var piece_integrated = false;
    if (inputs.hardDrop == .JustPressed and !(inputs.hold == .Pressed or inputs.hold == .JustPressed)) {
        score.score += @intCast(usize, piece_drop_pos.y - piece_pos.y) * 2;
        piece.integrate_with(piece_drop_pos, &grid);
        piece_integrated = true;
        last_time = current_time;
    } else if ((inputs.down == .Pressed and last_time > get_soft_drop_delta()) or
        inputs.down == .JustPressed or current_time - last_time > get_drop_delta(score.level))
    {
        ctx.audioEngine.play(ctx.sounds.move, ctx.clips.move[clock]);
        clock = (clock + 1) % 8;
        var new_pos = piece_pos;
        new_pos = new_pos.add(0, 1);
        if (piece.collides_with(new_pos, &grid)) {
            // Integrate
            piece.integrate_with(piece_pos, &grid);
            piece_integrated = true;
        } else {
            piece_pos = new_pos;
        }
        if (inputs.down == .Pressed or inputs.down == .JustPressed) {
            score.score += 1;
        }
        last_time = current_time;
    }

    if (piece_integrated) {
        grab_next_piece(ctx);

        can_hold = true;

        var lines = grid.clear_rows() catch {
            fail_to_null(ctx);
            return;
        };
        // Checks to see if the new piece collides with the grid.
        // If it is, then the game is over!
        if (piece.collides_with(piece_pos, &grid)) {
            ctx.push_screen(GameOverScreen) catch @panic("Could not push screen");
        }

        score.rowsCleared += lines;
        switch (lines) {
            0 => {},
            1 => score.singles += 1,
            2 => score.doubles += 1,
            3 => score.triples += 1,
            4 => score.tetrises += 1,
            else => unreachable,
        }

        score.score += get_score(lines, score.level);

        ctx.allocator.free(level_text);
        ctx.allocator.free(lines_text);

        level_text = std.fmt.allocPrint(ctx.allocator, "{}", .{score.level}) catch {
            fail_to_null(ctx);
            return;
        };
        lines_text = std.fmt.allocPrint(ctx.allocator, "{}", .{score.rowsCleared}) catch {
            fail_to_null(ctx);
            return;
        };

        if (score.rowsCleared > level_at and score.level < 9) {
            score.level += 1;
            level_at += 10;
        }

        // Turn off down input when new piece is made
        inputs.down = .Released;
    }

    if (score.score != prev_score.score) {
        ctx.allocator.free(score_text);
        score_text = std.fmt.allocPrint(ctx.allocator, "{}", .{score.score}) catch {
            fail_to_null(ctx);
            return;
        };
    }

    piece_drop_pos = piece_pos;
    while (!piece.collides_with(piece_drop_pos.add(0, 1), &grid)) : (piece_drop_pos.y += 1) {}

    // Update input state
    if (inputs.hardDrop == .JustPressed) inputs.hardDrop = .Pressed;
    if (inputs.down == .JustPressed) inputs.down = .Pressed;
    if (inputs.left == .JustPressed) {
        inputs.left = .Pressed;
        move_left_timer = REPEAT_TIME * 2.0;
    }
    if (inputs.right == .JustPressed) {
        inputs.right = .Pressed;
        move_left_timer = REPEAT_TIME * 2.0;
    }
    if (inputs.rot_ws == .JustPressed) inputs.rot_ws = .Pressed;
    if (inputs.rot_cw == .JustPressed) inputs.rot_cw = .Pressed;
    if (inputs.hold == .JustPressed) inputs.hold = .Pressed;
}

pub fn render(ctx: *Context, alpha: f64) void {
    _ = alpha;

    const screen_size = seizer.getScreenSize();
    const grid_offset = vec(
        @intCast(usize, @divTrunc(screen_size.x, 2)) - @divTrunc(grid.size.x * 16, 2),
        0,
    ).intCast(isize);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size);

    // Draw grid
    draw_grid_offset_bg(ctx, grid_offset, grid.size, grid.items);
    draw_grid_offset(ctx, grid_offset, grid.size, grid.items, 1);

    // Draw current piece
    draw_grid_offset(ctx, grid_offset.addv(piece_pos.scale(16)), piece.size, &piece.items, 1);

    // Draw drop indicator
    draw_grid_offset(ctx, grid_offset.addv(piece_drop_pos.scale(16)), piece.size, &piece.items, 0.3);

    // Draw placed blocks
    var y: isize = 0;
    while (y < grid.size.y) : (y += 1) {
        draw_tile(ctx, 0, grid_offset.add(-16, y * 16), 1);
        draw_tile(ctx, 0, grid_offset.add(@intCast(isize, grid.size.x) * 16, y * 16), 1);
    }

    // Draw held piece
    if (held_piece) |*held| {
        draw_grid_offset(ctx, veci(2 * 16, 0), held.size, &held.items, 1);
    }

    // Draw upcoming piece
    draw_grid_offset(ctx, veci(screen_size.x - 8 * 16, 0), next_piece.size, &next_piece.items, 1);

    ctx.font.drawText(&ctx.flat, "SCORE:", vec(0, 128).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, score_text, vec(0, 160).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LEVEL:", vec(0, 192).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, level_text, vec(0, 224).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LINES:", vec(0, 256).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, lines_text, vec(0, 288).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.flat.flush();
}

/// Internal functions
fn grab_next_piece(ctx: *Context) void {
    var next = bag[grab];
    piece_pos = piece.set_type(next);
    grab += 1;
    switch (grab) {
        7 => bag[0..7].* = shuffled_bag(ctx),
        14 => {
            grab = 0;
            bag[7..14].* = shuffled_bag(ctx);
        },
        else => {},
    }
    if (grab >= bag.len) {
        std.log.debug("Grab out of bounds", .{});
        grab = 0;
    }
    _ = next_piece.set_type(bag[grab]);
}

fn draw_tile(ctx: *Context, id: u16, pos: Veci, opacity: f32) void {
    const TILE_W = 16;
    const TILE_H = 16;

    const tileposy = id / (ctx.tileset_tex.size.x / TILE_W);
    const tileposx = id - (tileposy * (ctx.tileset_tex.size.x / TILE_W));

    const texpos1 = vec2f(@intToFloat(f32, tileposx) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));
    const texpos2 = vec2f(@intToFloat(f32, tileposx + 1) / @intToFloat(f32, ctx.tileset_tex.size.x / TILE_W), @intToFloat(f32, tileposy + 1) / @intToFloat(f32, ctx.tileset_tex.size.y / TILE_H));

    ctx.flat.drawTexture(ctx.tileset_tex, pos.intToFloat(f32), .{
        .size = vec2f(16, 16),
        .rect = .{
            .min = texpos1,
            .max = texpos2,
        },
        .color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = @floatToInt(u8, opacity * 255) },
    });
}

fn draw_region(ctx: *Context, rect: geom.Rect, pos: Veci, opacity: f32) void {
    const texpos1 = vec2(rect[0], rect[1]);
    const texpos2 = vec2(rect[2], rect[3]);

    ctx.flat.drawTexture(ctx.tileset_tex, pos.intToFloat(f32), .{
        .size = vec2f(16, 16),
        .rect = .{
            .min = util.pixelToTex(&ctx.tileset_tex, texpos1),
            .max = util.pixelToTex(&ctx.tileset_tex, texpos2),
        },
        .color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = @floatToInt(u8, opacity * 255) },
    });
}

fn draw_grid_offset(ctx: *Context, offset: Veci, size: Vec, dgrid: []Block, opacity: f32) void {
    for (dgrid) |block, i| {
        if (block == .some) {
            if (util.i2vec(size, i)) |pos| {
                const rect = ctx.tilemap.blocks[block.some];
                draw_region(ctx, rect, offset.addv(pos.scale(16)), opacity);
            }
        }
    }
}

fn draw_grid_offset_bg(ctx: *Context, offset: Veci, size: Vec, dgrid: []Block) void {
    for (dgrid) |block, i| {
        if (block == .none) {
            if (util.i2vec(size, i)) |pos| {
                draw_tile(ctx, 8, offset.addv(pos.scale(16)), 1);
            }
        }
    }
}

/// Game Over Screen
pub const GameOverScreen = .{
    .init = go_init,
    .deinit = go_deinit,
    .event = go_event,
    .render = go_render,
};

var go_menu: Menu = undefined;

fn go_init(ctx: *Context) void {
    score.timestamp = @divTrunc(seizer.now(), 1000);
    go_menu = Menu.init(ctx) catch @panic("Couldn't setup menu");
    _ = go_menu.add_menu_item(.{ .label = "Restart", ._type = .{.action = go_action_restart }}) catch @panic("add menu item");
    _ = go_menu.add_menu_item(.{ .label = "Setup", ._type = .{.action = go_action_setup }}) catch @panic("add menu item");
    _ = go_menu.add_menu_item(.{ .label = "Main Menu", ._type = .{.action = go_action_main_menu }}) catch @panic("add menu item");
}

fn go_deinit(ctx: *Context) void {
    go_menu.deinit(ctx);
}

fn go_action_restart(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(GameScreen) catch @panic("Couldn't set screen");
}

fn go_action_setup(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
    menu_ptr.ctx.push_screen(SetupScreen) catch @panic("Couldn't push screen");
}

fn go_action_main_menu(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
}

fn go_event(ctx: *Context, evt: seizer.event.Event) void {
    go_menu.event(ctx, evt);
    if (evt == .Quit) {
        seizer.quit();
    }
}

fn go_render(ctx: *Context, alpha: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);
    const nineslice_size = screen_size_f.divv(vec2f(2, 2));
    const nineslice_pos = screen_size_f.scaleDiv(2).subv(nineslice_size.scaleDiv(2));

    var nineslice = NineSlice.init(
        util.pixelToTex(&ctx.tileset_tex, vec2(0, 48)),
        util.pixelToTex(&ctx.tileset_tex, vec2(48, 96)),
        vec2f(16, 16),
        2,
    );
    nineslice.draw(&ctx.flat, ctx.tileset_tex, .{ nineslice_pos.x, nineslice_pos.y, nineslice_pos.x + nineslice_size.x, nineslice_pos.y + nineslice_size.y });

    ctx.font.drawText(&ctx.flat, "GAME OVER!", nineslice_pos.add(nineslice_size.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = go_menu.getMinSize(ctx);
    const menu_pos = nineslice_size.subv(menu_size).scaleDiv(2).addv(nineslice_pos);
    go_menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
