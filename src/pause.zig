const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;

pub const PauseScreen: Screen = .{
    .init = init,
    .event = event,
    .render = render,
};

var menu: Menu = undefined;

fn init(ctx: *Context) void {
    menu = Menu.init(&.{
        .{ .Action = .{ .label = "Resume", .onaction = action_resume } },
        .{ .Action = .{ .label = "Main Menu", .onaction = action_main_menu } },
        .{ .Action = .{ .label = "Quit", .onaction = action_quit } },
    });
}

fn action_resume(ctx: *Context) void {
    ctx.pop_screen();
}

fn action_main_menu(ctx: *Context) void {
    //ctx.switch_screen() catch @panic("Switching screen somehow caused allocation");
}

fn action_quit(_ctx: *Context) void {
    seizer.quit();
}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    menu.event(ctx, evt);
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .ESCAPE => ctx.pop_screen(),
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

    const menu_size = menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
