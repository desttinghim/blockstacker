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
const GameScreen = @import("game.zig").GameScreen;
const ScoreScreen = @import("score_screen.zig").ScoreScreen;
const NineSlice = @import("nineslice.zig").NineSlice;
const Texture = seizer.Texture;
const ui = @import("ui/default.zig");

// ====== Setup screen =======

setup_menu: Menu,
level_label: usize,

fn setup_init(ctx: *Context) @This() {
    const level_txt = std.fmt.allocPrint(ctx.allocator, "Level: {}", .{ctx.setup.level}) catch @panic("Couldn't format label");
    var setup_menu = Menu.init(ctx, "Setup") catch @panic("Couldn't set up menu");
    var this = @This(){
        .setup_menu = setup_menu,
        .level_label = setup_menu.add_menu_item(.{
            .label = level_txt,
            .ondeinit = setup_spin_deinit,
            ._type = .{ .spinner = .{ .increase = setup_spin_up, .decrease = setup_spin_down } },
        }) catch @panic("Couldn't set up menu"),
    };
    _ = setup_menu.add_menu_item(.{ .label = "Start Game", ._type = .{ .action = setup_action_start_game } }) catch @panic("Couldn't set up menu");
    return this;
}

fn setup_update(this: *@This(), current_time: f64, delta: f64) void {
    _ = current_time;
    _ = delta;
    const screenSize = seizer.getScreenSize();
    this.setup_menu.stage.layout(.{ 0, 0, screenSize.x, screenSize.y });
}

fn setup_deinit(this: *@This()) void {
    this.setup_menu.deinit(this.ctx);
}

fn setup_action_start_game(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.push_screen(GameScreen) catch @panic("Switching screen somehow caused allocation");
}

fn setup_spin_up(menu_ptr: *Menu, _: ui.EventData) void {
    if (menu_ptr.ctx.setup.level < 9) {
        menu_ptr.ctx.setup.level += 1;
    }
    if (menu_ptr.stage.get_node(level_label)) |*node| {
        if (node.data == null) return;
        if (node.data.? != .Label) return;
        menu_ptr.ctx.allocator.free(node.data.?.Label.text);
        node.data.?.Label.text = std.fmt.allocPrint(menu_ptr.ctx.allocator, "Level: {}", .{menu_ptr.ctx.setup.level}) catch @panic("Couldn't format label");
        _ = menu_ptr.stage.set_node(node.*);
    }
}

fn setup_spin_down(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.setup.level -|= 1;
    if (menu_ptr.stage.get_node(level_label)) |*node| {
        if (node.data == null) return;
        if (node.data.? != .Label) return;
        menu_ptr.ctx.allocator.free(node.data.?.Label.text);
        node.data.?.Label.text = std.fmt.allocPrint(menu_ptr.ctx.allocator, "Level: {}", .{menu_ptr.ctx.setup.level}) catch @panic("Couldn't format label");
        _ = menu_ptr.stage.set_node(node.*);
    }
}

fn setup_spin_deinit(menu_ptr: *Menu) void {
    if (menu_ptr.stage.get_node(level_label)) |*node| {
        if (node.data == null) return;
        if (node.data.? != .Label) return;
        menu_ptr.ctx.allocator.free(node.data.?.Label.text);
    }
}

fn setup_event(this: *@This(), evt: seizer.event.Event) void {
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

fn setup_render(this: *@This(), alpha: f64) void {
    const ctx = this.ctx;
    const screen_size = seizer.getScreenSize();
    const screen_size_f = screen_size.intToFloat(f32);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    ctx.flat.setSize(screen_size);

    ctx.font.drawText(&ctx.flat, "SETUP", vec2f(screen_size_f.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = setup_menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    setup_menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
