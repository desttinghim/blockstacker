const std = @import("std");
const seizer = @import("seizer");
const Context = @import("context.zig").Context;
const GameScreen = @import("game.zig").GameScreen;

pub const GameOverScreen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .update = update,
    .render = render,
};

var button_pressed = false;

fn init(ctx: *Context) void {}

fn deinit(ctx: *Context) void {}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            else => button_pressed = true,
        },
        else => {},
    }
}

fn update(ctx: *Context, current_time: f64, delta: f64) void {
    if (button_pressed) {
        ctx.pop_screen();
        ctx.switch_screen(GameScreen) catch |e| @panic("Couldn't switch screen");
    }
}

fn render(ctx: *Context, alpha: f64) void {}
