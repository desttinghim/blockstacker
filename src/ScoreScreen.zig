const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const GameScreen = @import("game.zig").GameScreen;
const ScoreEntry = @import("./score.zig").ScoreEntry;
const Decoder = @import("proto_structs").Decoder;
const chrono = @import("chrono");

pub const ScoreScreen: Screen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .render = render,
};

var scores_list: std.ArrayList(ScoreEntry) = undefined;
var scores_done_loading = false;

fn init(ctx: *Context) void {
    scores_list = std.ArrayList(ScoreEntry).init(ctx.allocator);
    scores_done_loading = false;
    seizer.execute(ctx.allocator, load_scores, .{ ctx, &scores_list, &scores_done_loading }) catch unreachable;
}

fn deinit(_: *Context) void {
    scores_list.deinit();
}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .X, .ESCAPE => ctx.pop_screen(),
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .START, .B => ctx.pop_screen(),
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }
}

fn render(ctx: *Context, _: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size);

    if (scores_done_loading) {
        var y: f32 = (screen_size_f.y - ctx.font.lineHeight * @intToFloat(f32, scores_list.items.len)) / 2;
        for (scores_list.items) |entry| {
            var buf: [50]u8 = undefined;
            {
                const naivedt = chrono.datetime.NaiveDateTime.from_timestamp(entry.timestamp, 0) catch @panic("chrono");
                const dt = chrono.datetime.DateTime.utc(naivedt, ctx.timezone);
                const naive_dt = dt.toNaiveDateTime() catch @panic("chrono2: electric boogaloo");
                const dt_fmt = naive_dt.formatted("%Y-%m-%d");
                const text = std.fmt.bufPrint(&buf, "{}", .{dt_fmt}) catch continue;
                ctx.font.drawText(&ctx.flat, text, vec2f(screen_size_f.x * 1 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const minutes = @floor(entry.playTime / std.time.s_per_min);
                const seconds = @floor(entry.playTime - minutes * std.time.s_per_min);
                const text = std.fmt.bufPrint(&buf, "{d}:{d:0>2}", .{ minutes, seconds }) catch continue;
                ctx.font.drawText(&ctx.flat, text, vec2f(screen_size_f.x * 2 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.score}) catch continue;
                ctx.font.drawText(&ctx.flat, text, vec2f(screen_size_f.x * 3 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.startingLevel}) catch continue;
                ctx.font.drawText(&ctx.flat, text, vec2f(screen_size_f.x * 4 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            {
                const text = std.fmt.bufPrint(&buf, "{}", .{entry.rowsCleared}) catch continue;
                ctx.font.drawText(&ctx.flat, text, vec2f(screen_size_f.x * 5 / 6, y), .{ .scale = 1, .textAlign = .Right, .textBaseline = .Top });
            }
            y += ctx.font.lineHeight;
        }
    }

    ctx.flat.flush();
}

fn load_scores(ctx: *Context, scores: *std.ArrayList(ScoreEntry), done: *bool) void {
    var txn = ctx.db.begin(&.{"scores"}, .{ .readonly = true }) catch unreachable;
    defer txn.deinit();

    var store = txn.store("scores") catch unreachable;
    defer store.release();

    var cursor = store.cursor(.{}) catch unreachable;
    defer cursor.deinit();
    while (cursor.next() catch unreachable) |entry| {
        var arena = std.heap.ArenaAllocator.init(ctx.allocator);
        defer arena.deinit();

        const score_decoder = Decoder(ScoreEntry).fromBytes(entry.val) catch continue;
        const score = score_decoder.decode(arena.allocator()) catch continue;

        scores.append(score) catch unreachable;
    }

    done.* = true;
}
