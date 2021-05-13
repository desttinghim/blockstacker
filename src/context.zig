const std = @import("std");
const seizer = @import("seizer");
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;
const ScoreEntry = @import("score.zig").ScoreEntry;
const Setup = @import("game.zig").Setup;
const audio = seizer.audio;
const crossdb = @import("crossdb");
const encode = @import("proto-structs").encode;
const chrono = @import("chrono");

pub const Context = struct {
    flat: FlatRenderer,
    font: FontRenderer,
    tileset_tex: Texture,
    allocator: *std.mem.Allocator,
    rand: *std.rand.Random,
    screens: std.ArrayList(Screen),
    scores: std.ArrayList(ScoreEntry),
    setup: Setup,
    audioEngine: *audio.Engine,
    clips: struct {
        rotate: seizer.audio.SoundHandle,
        move: [8]seizer.audio.SoundHandle,
    },
    sounds: struct {
        rotate: seizer.audio.NodeHandle,
        move: seizer.audio.NodeHandle,
    },
    db: crossdb.Database,
    timezone: *const chrono.timezone.TimeZone,

    pub fn add_score(self: *@This(), score: ScoreEntry) !void {
        try seizer.execute(self.allocator, add_score_async, .{ self, score });
    }

    pub fn add_score_async(self: *@This(), score: ScoreEntry) void {
        var txn = self.db.begin(&.{"scores"}, .{}) catch @panic("Failed to add score");
        errdefer txn.deinit();

        {
            var scores = txn.store("scores") catch @panic("Failed to add score");
            defer scores.release();

            var key: [8]u8 = undefined;

            std.mem.writeIntBig(i64, &key, score.timestamp);

            const val = encode(self.allocator, score) catch unreachable;
            defer self.allocator.free(val);

            scores.put(&key, val) catch @panic("Failed to add score");
        }

        txn.commit() catch @panic("Failed to add score");
    }

    pub fn current_screen(self: *@This()) Screen {
        return if (self.screens.items.len > 0) self.screens.items[self.screens.items.len - 1] else NullScreen;
    }

    pub fn switch_screen(self: *@This(), screen: Screen) !void {
        self.pop_screen();
        try self.push_screen(screen);
    }

    pub fn push_screen(self: *@This(), screen: Screen) !void {
        try self.screens.append(screen);
        screen.init(self);
    }

    pub fn pop_screen(self: *@This()) void {
        if (self.screens.items.len > 0) {
            var screen = self.screens.pop();
            screen.deinit(self);
        }
    }

    pub fn set_screen(self: *@This(), new_screen: Screen) !void {
        for (self.screens.items) |screen| {
            screen.deinit(self);
        }
        self.screens.shrinkRetainingCapacity(0);
        try self.push_screen(new_screen);
    }
};

pub const Screen = struct {
    init: fn (ctx: *Context) void = init,
    deinit: fn (ctx: *Context) void = deinit,
    event: fn (ctx: *Context, evt: seizer.event.Event) void = event,
    update: fn (ctx: *Context, current_time: f64, delta: f64) void = update,
    render: fn (ctx: *Context, alpha: f64) void = render,
};

pub const Transition = union(enum) {
    Switch: Screen,
    Push: Screen,
    Pop,
};

pub const NullScreen: Screen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .update = update,
    .render = render,
};
fn init(ctx: *Context) void {}
fn deinit(ctx: *Context) void {}
fn event(ctx: *Context, evt: seizer.event.Event) void {
    switch (evt) {
        .Quit => seizer.quit(),
        else => {},
    }
}
fn update(ctx: *Context, current_time: f64, delta: f64) void {}
fn render(ctx: *Context, alpha: f64) void {}
