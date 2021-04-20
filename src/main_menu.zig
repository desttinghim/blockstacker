const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const GameScreen = @import("game.zig").GameScreen;

pub const MainMenuScreen: Screen = .{
    .init = init,
    .event = event,
    .render = render,
};

var menu: Menu = undefined;

fn init(ctx: *Context) void {
    // TODO: Add settings screen for settings that don't affect gameplay
    menu = Menu.init(&.{
        .{ .Action = .{ .label = "Start Game", .onaction = action_setup_game } },
        .{ .Action = .{ .label = "Quit", .onaction = action_quit } },
    });
}

fn action_setup_game(ctx: *Context) void {
    // TODO: Go to setup screen instead of directly to game
    ctx.push_screen(SetupScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_quit(_ctx: *Context) void {
    seizer.quit();
}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    menu.event(ctx, evt);
    if (evt == .Quit) {
        seizer.quit();
    }
}

fn render(ctx: *Context, alpha: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size_f);

    ctx.font.drawText(&ctx.flat, "BLOCKSTACKER", vec2f(screen_size_f.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}

// ====== Setup screen =======

pub const SetupScreen: Screen = .{
    .init = setup_init,
    .event = setup_event,
    .render = setup_render,
};

var setup_menu: Menu = undefined;

fn setup_init(ctx: *Context) void {
    // TODO: Add settings screen for settings that don't affect gameplay
    setup_menu = Menu.init(&.{
        .{ .Action = .{ .label = "Start Game", .onaction = setup_action_start_game } },
    });
}

fn setup_action_start_game(ctx: *Context) void {
    // TODO: Go to setup screen instead of directly to game
    ctx.set_screen(GameScreen) catch @panic("Switching screen somehow caused allocation");
}

fn setup_event(ctx: *Context, evt: seizer.event.Event) void {
    setup_menu.event(ctx, evt);
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

fn setup_render(ctx: *Context, alpha: f64) void {
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size_f);

    ctx.font.drawText(&ctx.flat, "SETUP", vec2f(screen_size_f.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = setup_menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    setup_menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
