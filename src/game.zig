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
    var bag: [7]PieceType = undefined;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        bag[i] = @intToEnum(PieceType, i);
    }
    return bag;
}

fn shuffled_bag(ctx: *Context) [7]PieceType {
    var bag = @This().get_bag();
    var i: usize = 0;
    while (i < bag.len) : (i += 1) {
        var a = ctx.rand.intRangeLessThanBiased(usize, 0, bag.len);
        const current = bag[i];
        bag[i] = bag[a];
        bag[a] = current;
    }
    return bag;
}

pub const Stacking = struct {
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

    score_text: []u8,
    level_text: []u8,
    lines_text: []u8,

    pub fn init(ctx: *Context, level: usize) !@This() {
        var this = @This(){
            .grid = try Grid.init(ctx.allocator, vec(10, 20)),
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
            .bag = shuffled_bag(ctx),
            .grab = 0,
            .cleared_rows = 0,
            .score = 0,
            .level = level,
            .level_at = level * 10,

            .score_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
            .level_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
            .lines_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{0}),
        };

        this.grab_next_piece(ctx);
        return this;
    }

    pub fn deinit(this: *@This(), ctx: *Context) void {
        ctx.allocator.free(this.score_text);
        ctx.allocator.free(this.level_text);
        ctx.allocator.free(this.lines_text);
        this.grid.deinit();
    }

    pub fn onEvent(self: *@This(), ctx: *Context, event: seizer.event.Event) !void {
        switch (event) {
            .KeyDown => |e| switch (e.scancode) {
                .Z, .COMMA => self.inputs.rot_ws = .JustPressed,
                .X, .PERIOD => self.inputs.rot_cw = .JustPressed,
                .A, .LEFT => self.inputs.left = .JustPressed,
                .D, .RIGHT => self.inputs.right = .JustPressed,
                .S, .DOWN => self.inputs.down = .JustPressed,

                .ESCAPE => seizer.quit(),
                else => {},
            },
            .KeyUp => |e| switch (e.scancode) {
                .Z, .COMMA => self.inputs.rot_ws = .Released,
                .X, .PERIOD => self.inputs.rot_cw = .Released,
                .A, .LEFT => self.inputs.left = .Released,
                .D, .RIGHT => self.inputs.right = .Released,
                .S, .DOWN => self.inputs.down = .Released,

                else => {},
            },
            .ControllerButtonDown => |cbutton| switch (cbutton.button) {
                .DPAD_DOWN => self.inputs.down = .JustPressed,
                .DPAD_LEFT => self.inputs.left = .JustPressed,
                .DPAD_RIGHT => self.inputs.right = .JustPressed,
                // .START => toggle_menu = true,
                .A => self.inputs.rot_ws = .JustPressed,
                .B => self.inputs.rot_cw = .JustPressed,
                else => |num| {},
            },
            .Quit => seizer.quit(),
            else => {},
        }
    }

    pub fn update(self: *@This(), ctx: *Context, current_time: f64, delta: f64) anyerror!void {
        {
            var new_piece = self.piece;
            var new_pos = self.piece_pos;
            if (self.inputs.right == .JustPressed) new_pos = new_pos.add(1, 0);
            if (self.inputs.left == .JustPressed) new_pos = new_pos.sub(1, 0);
            if (self.inputs.rot_ws == .JustPressed) new_piece.rotate_ws();
            if (self.inputs.rot_cw == .JustPressed) new_piece.rotate_cw();

            if (!new_piece.collides_with(new_pos, &self.grid)) {
                self.piece = new_piece;
                self.piece_pos = new_pos;
            }
        }

        if ((self.inputs.down == .Pressed and self.last_time > get_soft_drop_delta()) or
            self.inputs.down == .JustPressed or current_time - self.last_time > get_drop_delta(self.level))
        {
            var new_pos = self.piece_pos;
            new_pos = new_pos.add(0, 1);
            if (self.piece.collides_with(new_pos, &self.grid)) {
                // Integrate
                self.piece.integrate_with(self.piece_pos, &self.grid);
                self.grab_next_piece(ctx);
                var lines = try self.grid.clear_rows();
                self.cleared_rows += lines;
                self.score += get_score(lines, self.level);

                ctx.allocator.free(self.score_text);
                self.score_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{self.score});
                ctx.allocator.free(self.level_text);
                self.level_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{self.level});
                ctx.allocator.free(self.lines_text);
                self.lines_text = try std.fmt.allocPrint(ctx.allocator, "{}", .{self.cleared_rows});

                if (self.cleared_rows > self.level_at and self.level < 9) {
                    self.level += 1;
                    self.level_at += 10;
                }

                // Turn off down input when new piece is made
                self.inputs.down = .Released;
            } else {
                self.piece_pos = new_pos;
            }
            self.last_time = current_time;
        }

        // Update input state
        if (self.inputs.down == .JustPressed) self.inputs.down = .Pressed;
        if (self.inputs.left == .JustPressed) self.inputs.left = .Pressed;
        if (self.inputs.right == .JustPressed) self.inputs.right = .Pressed;
        if (self.inputs.rot_ws == .JustPressed) self.inputs.rot_ws = .Pressed;
        if (self.inputs.rot_cw == .JustPressed) self.inputs.rot_cw = .Pressed;
    }

    pub fn render(self: *@This(), ctx: *Context, alpha: f64) !void {
        const screen_size = seizer.getScreenSize();
        const screen_size_f = screen_size.intToFloat(f32);
        const grid_offset = vec(
            @intCast(usize, @divTrunc(screen_size.x, 2)) - @divTrunc(self.grid.size.x * 16, 2),
            0,
        ).intCast(isize);

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.viewport(0, 0, screen_size.x, screen_size.y);

        ctx.flat.setSize(screen_size_f);

        draw_grid_offset_bg(ctx, grid_offset, self.grid.size, self.grid.items);
        draw_grid_offset(ctx, grid_offset, self.grid.size, self.grid.items);
        draw_grid_offset(ctx, grid_offset.addv(self.piece_pos.scale(16)), self.piece.size, &self.piece.items);
        var y: isize = 0;
        while (y < self.grid.size.y) : (y += 1) {
            draw_tile(ctx, 0, grid_offset.add(-16, y * 16));
            draw_tile(ctx, 0, grid_offset.add(@intCast(isize, self.grid.size.x) * 16, y * 16));
        }

        ctx.font.drawText(&ctx.flat, "SCORE:", vec(0, 0).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
        ctx.font.drawText(&ctx.flat, self.score_text, vec(0, 32).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

        ctx.font.drawText(&ctx.flat, "LEVEL:", vec(0, 64).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
        ctx.font.drawText(&ctx.flat, self.level_text, vec(0, 96).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

        ctx.font.drawText(&ctx.flat, "LINES:", vec(0, 128).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });
        ctx.font.drawText(&ctx.flat, self.lines_text, vec(0, 160).intToFloat(f32), .{ .scale = 2, .textBaseline = .Top });

        ctx.flat.flush();
    }

    /// Internal functions
    fn grab_next_piece(self: *@This(), ctx: *Context) void {
        var next = self.bag[self.grab];
        self.piece_pos = self.piece.set_type(next);
        self.grab += 1;
        if (self.grab >= self.bag.len) {
            self.grab = 0;
            self.bag = shuffled_bag(ctx);
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

    fn draw_grid_offset(ctx: *Context, offset: Veci, size: Vec, grid: []Block) void {
        for (grid) |block, i| {
            if (block == .some) {
                if (util.i2vec(size, i)) |pos| {
                    draw_tile(ctx, block.some, offset.addv(pos.scale(16)));
                }
            }
        }
    }

    fn draw_grid_offset_bg(ctx: *Context, offset: Veci, size: Vec, grid: []Block) void {
        for (grid) |block, i| {
            if (block == .none) {
                if (util.i2vec(size, i)) |pos| {
                    draw_tile(ctx, 8, offset.addv(pos.scale(16)));
                }
            }
        }
    }
};
