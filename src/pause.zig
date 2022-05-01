const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const MainMenuScreen = @import("main_menu.zig").MainMenuScreen;
const GameScreen = @import("game.zig").GameScreen;

pub const PauseScreen: Screen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .render = render,
};

var menu: Menu = undefined;

fn init(ctx: *Context) void {
    menu = Menu.init(ctx, &.{
        .{ .label = "Continue", .onaction = action_continue },
        .{ .label = "Restart", .onaction = action_restart },
        .{ .label = "Main Menu", .onaction = action_main_menu },
    }) catch @panic("Couldn't set up menu");
}

fn deinit(ctx: *Context) void {
    menu.deinit(ctx);
}

fn action_continue(ctx: *Context, _: *MenuItem) void {
    ctx.pop_screen();
}

fn action_restart(ctx: *Context, _: *MenuItem) void {
    ctx.set_screen(GameScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_main_menu(ctx: *Context, _: *MenuItem) void {
    ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    menu.event(ctx, evt);
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

fn render(ctx: *Context, alpha: f64) void {
    const screen_size_f = seizer.getScreenSize().intToFloat(f32);

    gl.clear(gl.COLOR_BUFFER_BIT);

    const menu_size = menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
