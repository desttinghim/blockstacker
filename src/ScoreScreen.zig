const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
// const Menu = @import("menu.zig").Menu;
// const MenuItem = @import("menu.zig").MenuItem;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
// const GameScreen = @import("game.zig").GameScreen;
const ScoreEntry = @import("./score.zig").ScoreEntry;
const Decoder = @import("proto_structs").Decoder;
const chrono = @import("chrono");

ctx: *Context,
scores_list: std.ArrayList(ScoreEntry),
scores_done_loading: bool = false,

pub fn init(ctx: *Context) !@This() {
    var this = @This() {
        .ctx = ctx,
        .scores_list = std.ArrayList(ScoreEntry).init(ctx.allocator),
        .scores_done_loading = false,
    };
    try seizer.execute(ctx.allocator, load_scores, .{ &this });
    return this;
}

pub fn deinit(this: *@This()) !void {
    this.scores_list.deinit();
    this.stage.deinit();
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .X, .ESCAPE => this.ctx.scene.pop(),
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .START, .B => this.ctx.scene.pop(),
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn render(this: *@This(), _: f64) !void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    this.ctx.flat.setSize(screen_size);

    if (this.scores_done_loading) {
        var y: f32 = (screen_size_f.y - this.ctx.font.lineHeight * @intToFloat(f32, this.scores_list.items.len)) / 2;
        for (this.scores_list.items) |entry| {
            var buf: [50]u8 = undefined;
            {
                const naivedt = chrono.datetime.NaiveDateTime.from_timestamp(entry.timestamp, 0) catch @panic("chrono");
                const dt = chrono.datetime.DateTime.utc(naivedt, this.ctx.timezone);
                const naive_dt = dt.toNaiveDateTime() catch @panic("chrono2: electric boogaloo");
                const dt_fmt = naive_dt.formatted("%Y-%m-%d");
                const text = std.fmt.bufPrint(&buf, "{}", .{dt_fmt}) catch continue;
                this.ctx.font.drawText(&this.ctx.flat, text, vec2f(screen_size_f.x * 1 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const minutes = @floor(entry.playTime / std.time.s_per_min);
                const seconds = @floor(entry.playTime - minutes * std.time.s_per_min);
                const text = std.fmt.bufPrint(&buf, "{d}:{d:0>2}", .{ minutes, seconds }) catch continue;
                this.ctx.font.drawText(&this.ctx.flat, text, vec2f(screen_size_f.x * 2 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.score}) catch continue;
                this.ctx.font.drawText(&this.ctx.flat, text, vec2f(screen_size_f.x * 3 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.startingLevel}) catch continue;
                this.ctx.font.drawText(&this.ctx.flat, text, vec2f(screen_size_f.x * 4 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.rowsCleared}) catch continue;
                this.ctx.font.drawText(&this.ctx.flat, text, vec2f(screen_size_f.x * 5 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            y += this.ctx.font.lineHeight;
        }
    }

    this.ctx.flat.flush();
}

fn load_scores(this: *@This()) void {
    var txn = this.ctx.db.begin(&.{"scores"}, .{ .readonly = true }) catch unreachable;
    defer txn.deinit();

    var store = txn.store("scores") catch unreachable;
    defer store.release();

    var cursor = store.cursor(.{}) catch unreachable;
    defer cursor.deinit();
    while (cursor.next() catch unreachable) |entry| {
        var arena = std.heap.ArenaAllocator.init(this.ctx.allocator);
        defer arena.deinit();

        const score_decoder = Decoder(ScoreEntry).fromBytes(entry.val) catch continue;
        const score = score_decoder.decode(arena.allocator()) catch continue;

        this.scores_list.append(score) catch unreachable;
    }

    this.scores_done_loading = true;
}
