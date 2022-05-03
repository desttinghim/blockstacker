const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const Menu = @import("menu.zig").Menu;
const MenuItem = @import("menu.zig").MenuItem;
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

pub const MainMenuScreen: Screen = .{
    .init = init,
    .deinit = deinit,
    .event = event,
    .render = render,
};

var menu: Menu = undefined;

fn init(ctx: *Context) void {
    // TODO: Add settings screen for settings that don't affect gameplay
    menu = Menu.init(ctx, &.{
        .{ .label = "Start Game", .onaction = action_setup_game },
        .{ .label = "Scores", .onaction = action_scores },
        .{ .label = "Quit", .onaction = action_quit },
    }) catch @panic("Couldn't set up menu");

    // var center = menu.stage.insert(null, .{ .layout = .Center, .style = .none }) catch @panic("insert");
    // const Node = ui.DefaultNode;
    // var frame = menu.stage.insert(center, Node.anchor(.{ 0, 0, 100, 0 }, .{ 64, 32, -64, 112 }, .frame).minSize(.{ 512, 512 })) catch @panic("insert");
    // _ = menu.stage.insert(frame, .{ .style = .nameplate, .data = .{ .Label = .{ .size = 2, .text = "Hello World" } } }) catch @panic("insert");
    // const buttons = menu.stage.insert(frame, Node.vlist(.none)) catch @panic("insert");
    // const btn_start = menu.stage.insert(buttons, Node.relative(.none).dataValue(.{ .Label = .{ .size = 2, .text = "Start Game" } })) catch @panic("insert");
    // menu.audience.add(btn_start, .PointerClick, handle_setup_game) catch @panic("listen");
    // const btn_score = menu.stage.insert(buttons, Node.relative(.none).dataValue(.{ .Label = .{ .size = 2, .text = "Scores" } })) catch @panic("insert");
    // menu.audience.add(btn_score, .PointerClick, handle_score) catch @panic("listen");
    // const btn_quit = menu.stage.insert(buttons, Node.relative(.none).dataValue(.{ .Label = .{ .size = 2, .text = "Quit" } })) catch @panic("insert");
    // menu.audience.add(btn_quit, .PointerClick, handle_quit) catch @panic("listen");

    const screen_size = seizer.getScreenSize();
    menu.stage.layout(.{ 0, 0, screen_size.x, screen_size.y });
}

fn deinit(ctx: *Context) void {
    menu.deinit(ctx);
}

fn handle_setup_game(m: *Menu, _: ui.EventData) void {
    m.ctx.push_screen(SetupScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_setup_game(ctx: *Context, _: *MenuItem) void {
    // TODO: Go to setup screen instead of directly to game
    ctx.push_screen(SetupScreen) catch @panic("Switching screen somehow caused allocation");
}

fn handle_quit(_: *Menu, _: ui.EventData) void {
    seizer.quit();
}

fn action_quit(ctx: *Context, _: *MenuItem) void {
    _ = ctx;
    seizer.quit();
}

fn handle_score(m: *Menu, _: ui.EventData) void {
    m.ctx.push_screen(ScoreScreen) catch @panic("Switching screen somehow caused allocation");
}

fn action_scores(ctx: *Context, _: *MenuItem) void {
    ctx.push_screen(ScoreScreen) catch @panic("Switching screen somehow caused allocation");
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

    ctx.flat.setSize(screen_size);

    ctx.font.drawText(&ctx.flat, "BLOCKSTACKER", vec2f(screen_size_f.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}

// ====== Setup screen =======

pub const SetupScreen: Screen = .{
    .init = setup_init,
    .deinit = setup_deinit,
    .event = setup_event,
    .render = setup_render,
};

var setup_menu: Menu = undefined;

fn setup_init(ctx: *Context) void {
    const level_label = std.fmt.allocPrint(ctx.allocator, "Level: {}", .{ctx.setup.level}) catch @panic("Couldn't format label");
    errdefer ctx.allocator.free(level_label);

    const menu_items = [_]MenuItem{
        .{ .label = "Start Game", .onaction = setup_action_start_game },
        .{ .label = level_label, .onspin = setup_spin_level, .ondeinit = spinner_deinit },
    };
    setup_menu = Menu.init(ctx, &menu_items) catch @panic("Couldn't set up menu");
}

fn setup_deinit(ctx: *Context) void {
    setup_menu.deinit(ctx);
}

fn setup_action_start_game(ctx: *Context, _: *MenuItem) void {
    ctx.set_screen(GameScreen) catch @panic("Switching screen somehow caused allocation");
}

fn setup_spin_level(ctx: *Context, item: *MenuItem, increase: bool) void {
    if (increase and ctx.setup.level < 9) {
        ctx.setup.level += 1;
    } else if (!increase and ctx.setup.level > 0) {
        ctx.setup.level -= 1;
    }
    ctx.allocator.free(item.label);
    item.label = std.fmt.allocPrint(ctx.allocator, "Level: {}", .{ctx.setup.level}) catch @panic("Couldn't format label");
}

fn spinner_deinit(ctx: *Context, item: *MenuItem) void {
    ctx.allocator.free(item.label);
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

    ctx.flat.setSize(screen_size);

    ctx.font.drawText(&ctx.flat, "SETUP", vec2f(screen_size_f.x / 2, 16), .{ .scale = 2, .textAlign = .Center, .textBaseline = .Top });

    const menu_size = setup_menu.getMinSize(ctx);
    const menu_pos = screen_size_f.subv(menu_size).scaleDiv(2);
    setup_menu.render(ctx, alpha, menu_pos);

    ctx.flat.flush();
}
