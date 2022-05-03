const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
const MenuAndItem = @import("menu.zig").MenuAndItem;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const MainMenuScreen = @import("main_menu.zig").MainMenuScreen;
const GameScreen = @import("game.zig").GameScreen;
const ui = @import("ui/default.zig");

pub const PauseScreen: Screen = .{
    .init = init,
    .deinit = deinit,
    .update = update,
    .event = event,
    .render = render,
};

var menu: Menu = undefined;

fn init(ctx: *Context) void {
    menu = Menu.init(ctx, "Pause") catch @panic("Couldn't set up menu");
    _ = menu.add_menu_item(.{ .label = "Continue", ._type = .{ .action = action_continue } }) catch @panic("add item");
    _ = menu.add_menu_item(.{ .label = "Restart", ._type = .{ .action = action_restart } }) catch @panic("add item");
    _ = menu.add_menu_item(.{ .label = "Main Menu", ._type = .{ .action = action_main_menu } }) catch @panic("add item");
}

fn update(ctx: *Context, current_time: f64, delta: f64) void {
    _ = ctx;
    _ = current_time;
    _ = delta;
    const screenSize = seizer.getScreenSize();
    menu.stage.layout(.{ 0, 0, screenSize.x, screenSize.y });
}

fn deinit(ctx: *Context) void {
    menu.deinit(ctx);
}

fn action_continue(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.pop_screen();
}

fn action_restart(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.set_screen(GameScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_main_menu(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
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
