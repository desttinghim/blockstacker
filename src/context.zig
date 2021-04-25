const std = @import("std");
const seizer = @import("seizer");
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;
const ScoreEntry = @import("score.zig").ScoreEntry;
const Setup = @import("game.zig").Setup;

pub const Context = struct {
    flat: FlatRenderer,
    font: FontRenderer,
    tileset_tex: Texture,
    allocator: *std.mem.Allocator,
    rand: *std.rand.Random,
    screens: std.ArrayList(Screen),
    scores: std.ArrayList(ScoreEntry),
    setup: Setup,
    sounds: struct {
        rotate: seizer.audio.SoundHandle,
        move: [8]seizer.audio.SoundHandle,
    },

    pub fn add_score(self: *@This(), name: []const u8, score: usize) !void {
        try self.scores.append(.{ .name = name, .score = score });
        std.sort.sort(ScoreEntry, self.scores.items, {}, ScoreEntry.lessThan);
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
