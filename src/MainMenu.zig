const std = @import("std");
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
const MenuAndItem = @import("menu.zig").MenuAndItem;
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
// const GameScreen = @import("game.zig").GameScreen;
const NineSlice = @import("nineslice.zig").NineSlice;
const Texture = seizer.Texture;
const ui = @import("ui/default.zig");

ctx: *Context,
menu: Menu,

pub fn init(ctx: *Context) !@This() {
    // TODO: Add settings screen for settings that don't affect gameplay
    var this = .{
        .ctx = ctx,
        .menu = Menu.init(ctx, "BlockStacker") catch @panic("menu"),
    };
    _ = this.menu.add_menu_item(.{ .label = "Start Game", ._type = .{ .action = action_setup_game } }) catch @panic("Couldn't set up menu");
    _ = this.menu.add_menu_item(.{ .label = "Scores", ._type = .{ .action = action_score } }) catch @panic("Couldn't set up menu");
    _ = this.menu.add_menu_item(.{ .label = "Quit", ._type = .{ .action = action_quit } }) catch @panic("Couldn't set up menu");

    std.log.info("init main menu", .{});

    const screen_size = seizer.getScreenSize();
    this.menu.stage.layout(.{ 0, 0, screen_size.x, screen_size.y });
    return this;
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    _ = current_time;
    _ = delta;
    _ = this;
    const screenSize = seizer.getScreenSize();
    this.menu.stage.layout(.{ 0, 0, screenSize.x, screenSize.y });
}

pub fn deinit(this: *@This()) void {
    this.menu.deinit(this.ctx);
}

fn action_setup_game(menu_ptr: *Menu, _: ui.EventData) void {
    _ = menu_ptr;
    // menu_ptr.ctx.scene.push(SetupScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_quit(_: *Menu, _: ui.EventData) void {
    seizer.quit();
}

fn action_score(menu_ptr: *Menu, _: ui.EventData) void {
    _ = menu_ptr;
    // menu_ptr.ctx.push_screen(ScoreScreen) catch @panic("Switching screen somehow caused allocation");
}

fn event(this: *@This(), evt: seizer.event.Event) void {
    _ = this;
    this.menu.event(this.ctx, evt);
    if (evt == .Quit) {
        seizer.quit();
    }
}

pub fn render(this: *@This(), alpha: f64) !void {
    const screen_size = seizer.getScreenSize();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    this.ctx.flat.setSize(screen_size);

    const menu_size = this.menu.getMinSize(this.ctx);
    this.menu.render(this.ctx, alpha, menu_size);

    this.ctx.flat.flush();
}

