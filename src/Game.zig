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
// const PauseScreen = @import("PauseScreen.zig");
const ScoreEntry = @import("score.zig").ScoreEntry;
const geom = seizer.geometry;

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

ctx: *Context,
grid: Grid = undefined,
piece: Piece = undefined,
piece_pos: Veci = undefined,
piece_drop_pos: Veci = undefined,
next_piece: Piece = undefined,
held_piece: ?Piece = null,
can_hold: bool = true,
inputs: Inputs = undefined,
last_time: f64 = undefined,
bag: [14]PieceType = undefined,
grab: usize = undefined,
level_at: usize = undefined,
clock: usize = 0,
score: ScoreEntry = undefined,

move_left_timer: f64 = undefined,
move_right_timer: f64 = undefined,

score_text: []u8 = undefined,
level_text: []u8 = undefined,
lines_text: []u8 = undefined,

const REPEAT_TIME = 0.1;

pub fn set_level(this: *@This(), level_start: u8) void {
    this.score.startingLevel = level_start;
    this.score.level = level_start;
    this.level_at = level_start * 10 + 10;
}

fn fail_to_null(ctx: *Context) void {
    ctx.scene.pop();
}

/// Resets EVERYTHING to default
pub fn init(ctx: *Context) !@This() {
    var this = @This(){
        .ctx = ctx,
        .grid = try Grid.init(ctx.allocator, vec(10, 20)),
        .piece = Piece.init(),
        .piece_pos = veci(0, 0),
        .next_piece = Piece.init(),
        .held_piece = null,
        .can_hold = true,
        .inputs = .{
            .hardDrop = .Released,
            .down = .Released,
            .left = .Released,
            .right = .Released,
            .rot_ws = .Released,
            .rot_cw = .Released,
            .hold = .Released,
        },
        .last_time = 0,
        .grab = 0,
        .clock = 0,
        .score = .{
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
        },
        .score_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
        .level_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
        .lines_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
    };

    this.bag[0..7].* = shuffled_bag(ctx);
    this.bag[7..14].* = shuffled_bag(ctx);

    this.set_level(ctx.setup.level);

    this.grab_next_piece();

    return this;
}

pub fn deinit(this: *@This()) void {
    this.ctx.allocator.free(this.score_text);
    this.ctx.allocator.free(this.level_text);
    this.ctx.allocator.free(this.lines_text);
    this.grid.deinit();
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .Z, .COMMA, .SPACE => this.inputs.rot_ws = .JustPressed,
            .X, .PERIOD => this.inputs.rot_cw = .JustPressed,
            .A, .LEFT => if (this.inputs.left != .Pressed) {
                this.inputs.left = .JustPressed;
            },
            .D, .RIGHT => if (this.inputs.right != .Pressed) {
                this.inputs.right = .JustPressed;
            },
            .S, .DOWN => if (this.inputs.right != .Pressed) {
                this.inputs.down = .JustPressed;
            },
            .W, .UP => if (this.inputs.right != .Pressed) {
                this.inputs.hardDrop = .JustPressed;
            },
            .TAB => if (this.inputs.hold != .Pressed) {
                this.inputs.hold = .JustPressed;
            },

            // .ESCAPE => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            else => {},
        },
        .KeyUp => |e| switch (e.scancode) {
            .Z, .COMMA => this.inputs.rot_ws = .Released,
            .X, .PERIOD => this.inputs.rot_cw = .Released,
            .A, .LEFT => this.inputs.left = .Released,
            .D, .RIGHT => this.inputs.right = .Released,
            .S, .DOWN => this.inputs.down = .Released,
            .W, .UP => this.inputs.hardDrop = .Released,
            .TAB => this.inputs.hold = .Released,

            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .DPAD_UP => this.inputs.hardDrop = .JustPressed,
            .DPAD_DOWN => this.inputs.down = .JustPressed,
            .DPAD_LEFT => if (this.inputs.left != .Pressed) {
                this.inputs.left = .JustPressed;
            },
            .DPAD_RIGHT => if (this.inputs.right != .Pressed) {
                this.inputs.right = .JustPressed;
            },
            // .START => ctx.push_screen(PauseScreen) catch @panic("Could not push screen"),
            .A => this.inputs.rot_ws = .JustPressed,
            .B => this.inputs.rot_cw = .JustPressed,
            .LEFTSHOULDER => this.inputs.hold = .JustPressed,
            else => {},
        },
        .ControllerButtonUp => |cbutton| switch (cbutton.button) {
            .DPAD_UP => this.inputs.hardDrop = .Released,
            .DPAD_DOWN => this.inputs.down = .Released,
            .DPAD_LEFT => this.inputs.left = .Released,
            .DPAD_RIGHT => this.inputs.right = .Released,
            .A => this.inputs.rot_ws = .Released,
            .B => this.inputs.rot_cw = .Released,
            .LEFTSHOULDER => this.inputs.hold = .Released,
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    const ctx = this.ctx;
    this.score.playTime += delta;
    {
        var new_piece = this.piece;
        var new_pos = this.piece_pos;

        this.move_right_timer -= delta;
        if (this.inputs.right == .JustPressed or (this.inputs.right == .Pressed and this.move_right_timer < 0)) {
            new_pos = new_pos.add(1, 0);
            this.move_right_timer = REPEAT_TIME;
        }

        this.move_left_timer -= delta;
        if (this.inputs.left == .JustPressed or (this.inputs.left == .Pressed and this.move_left_timer < 0)) {
            new_pos = new_pos.sub(1, 0);
            this.move_left_timer = REPEAT_TIME;
        }

        if (this.inputs.rot_ws == .JustPressed) new_piece.rotate_ws();
        if (this.inputs.rot_cw == .JustPressed) new_piece.rotate_cw();

        if (this.inputs.rot_ws == .JustPressed or this.inputs.rot_cw == .JustPressed) {
            ctx.audioEngine.play(ctx.sounds.rotate, ctx.clips.rotate);
        }

        if (!new_piece.collides_with(new_pos, &this.grid)) {
            this.piece = new_piece;
            this.piece_pos = new_pos;
        }
    }

    if (this.inputs.hold == .JustPressed and this.can_hold) {
        this.can_hold = false;
        const new_held_piece_type = this.piece.piece_type;
        if (this.held_piece) |held| {
            this.piece_pos = this.piece.set_type(held.piece_type);
        } else {
            grab_next_piece(this);
            this.held_piece = Piece.init();
        }
        _ = this.held_piece.?.set_type(new_held_piece_type);
    }

    const prev_score = this.score;

    var piece_integrated = false;
    if (this.inputs.hardDrop == .JustPressed and !(this.inputs.hold == .Pressed or this.inputs.hold == .JustPressed)) {
        this.score.score += @intCast(usize, this.piece_drop_pos.y - this.piece_pos.y) * 2;
        this.piece.integrate_with(this.piece_drop_pos, &this.grid);
        piece_integrated = true;
        this.last_time = current_time;
    } else if ((this.inputs.down == .Pressed and this.last_time > get_soft_drop_delta()) or
        this.inputs.down == .JustPressed or current_time - this.last_time > get_drop_delta(this.score.level))
    {
        ctx.audioEngine.play(ctx.sounds.move, ctx.clips.move[this.clock]);
        this.clock = (this.clock + 1) % 8;
        var new_pos = this.piece_pos;
        new_pos = new_pos.add(0, 1);
        if (this.piece.collides_with(new_pos, &this.grid)) {
            // Integrate
            this.piece.integrate_with(this.piece_pos, &this.grid);
            piece_integrated = true;
        } else {
            this.piece_pos = new_pos;
        }
        if (this.inputs.down == .Pressed or this.inputs.down == .JustPressed) {
            this.score.score += 1;
        }
        this.last_time = current_time;
    }

    if (piece_integrated) {
        grab_next_piece(this);

        this.can_hold = true;

        var lines = try this.grid.clear_rows();
        // Checks to see if the new piece collides with the grid.
        // If it is, then the game is over!
        if (this.piece.collides_with(this.piece_pos, &this.grid)) {
            this.score.timestamp = @divTrunc(seizer.now(), 1000);
            try this.ctx.add_score(this.score);
            try ctx.scene.replace(.GameOver);
            return;
        }

        this.score.rowsCleared += lines;
        switch (lines) {
            0 => {},
            1 => this.score.singles += 1,
            2 => this.score.doubles += 1,
            3 => this.score.triples += 1,
            4 => this.score.tetrises += 1,
            else => unreachable,
        }

        this.score.score += get_score(lines, this.score.level);

        ctx.allocator.free(this.level_text);
        ctx.allocator.free(this.lines_text);

        this.level_text = std.fmt.allocPrint(ctx.allocator, "{}", .{this.score.level}) catch {
            fail_to_null(ctx);
            return;
        };
        this.lines_text = std.fmt.allocPrint(ctx.allocator, "{}", .{this.score.rowsCleared}) catch {
            fail_to_null(ctx);
            return;
        };

        if (this.score.rowsCleared > this.level_at and this.score.level < 9) {
            this.score.level += 1;
            this.level_at += 10;
        }

        // Turn off down input when new piece is made
        this.inputs.down = .Released;
    }

    if (this.score.score != prev_score.score) {
        ctx.allocator.free(this.score_text);
        this.score_text = std.fmt.allocPrint(ctx.allocator, "{}", .{this.score.score}) catch {
            fail_to_null(ctx);
            return;
        };
    }

    this.piece_drop_pos = this.piece_pos;
    while (!this.piece.collides_with(this.piece_drop_pos.add(0, 1), &this.grid)) : (this.piece_drop_pos.y += 1) {}

    // Update input state
    if (this.inputs.hardDrop == .JustPressed) this.inputs.hardDrop = .Pressed;
    if (this.inputs.down == .JustPressed) this.inputs.down = .Pressed;
    if (this.inputs.left == .JustPressed) {
        this.inputs.left = .Pressed;
        this.move_left_timer = REPEAT_TIME * 2.0;
    }
    if (this.inputs.right == .JustPressed) {
        this.inputs.right = .Pressed;
        this.move_left_timer = REPEAT_TIME * 2.0;
    }
    if (this.inputs.rot_ws == .JustPressed) this.inputs.rot_ws = .Pressed;
    if (this.inputs.rot_cw == .JustPressed) this.inputs.rot_cw = .Pressed;
    if (this.inputs.hold == .JustPressed) this.inputs.hold = .Pressed;
}

pub fn render(this: *@This(), alpha: f64) !void {
    _ = alpha;
    const ctx = this.ctx;

    const screen_size = seizer.getScreenSize();
    const grid_offset = vec(
        @intCast(usize, @divTrunc(screen_size.x, 2)) - @divTrunc(this.grid.size.x * 16, 2),
        0,
    ).intCast(isize);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size);

    // Draw grid
    draw_grid_offset_bg(ctx, grid_offset, this.grid.size, this.grid.items);
    draw_grid_offset(ctx, grid_offset, this.grid.size, this.grid.items, 1);

    // Draw current piece
    draw_grid_offset(ctx, grid_offset.addv(this.piece_pos.scale(16)), this.piece.size, &this.piece.items, 1);

    // Draw drop indicator
    draw_grid_offset(ctx, grid_offset.addv(this.piece_drop_pos.scale(16)), this.piece.size, &this.piece.items, 0.3);

    // Draw placed blocks
    var y: isize = 0;
    while (y < this.grid.size.y) : (y += 1) {
        draw_tile(ctx, 0, grid_offset.add(-16, y * 16), 1);
        draw_tile(ctx, 0, grid_offset.add(@intCast(isize, this.grid.size.x) * 16, y * 16), 1);
    }

    // Draw held piece
    if (this.held_piece) |*held| {
        draw_grid_offset(ctx, veci(2 * 16, 0), held.size, &held.items, 1);
    }

    // Draw upcoming piece
    draw_grid_offset(ctx, veci(screen_size.x - 8 * 16, 0), this.next_piece.size, &this.next_piece.items, 1);

    ctx.font.drawText(&ctx.flat, "SCORE:", vec(0, 128).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, this.score_text, vec(0, 160).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LEVEL:", vec(0, 192).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, this.level_text, vec(0, 224).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.font.drawText(&ctx.flat, "LINES:", vec(0, 256).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
    ctx.font.drawText(&ctx.flat, this.lines_text, vec(0, 288).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

    ctx.flat.flush();
}

/// Internal functions
fn grab_next_piece(this: *@This()) void {
    const ctx = this.ctx;
    var next = this.bag[this.grab];
    this.piece_pos = this.piece.set_type(next);
    this.grab += 1;
    switch (this.grab) {
        7 => this.bag[0..7].* = shuffled_bag(ctx),
        14 => {
            this.grab = 0;
            this.bag[7..14].* = shuffled_bag(ctx);
        },
        else => {},
    }
    if (this.grab >= this.bag.len) {
        std.log.debug("Grab out of bounds", .{});
        this.grab = 0;
    }
    _ = this.next_piece.set_type(this.bag[this.grab]);
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
