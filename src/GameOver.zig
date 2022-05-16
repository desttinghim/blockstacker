/// Game Over Screen
pub const GameOverScreen = .{
    .init = go_init,
    .deinit = go_deinit,
    .update = go_update,
    .event = go_event,
    .render = go_render,
};

var go_menu: Menu = undefined;

pub fn init(ctx: *Context) void {
    score.timestamp = @divTrunc(seizer.now(), 1000);
    go_menu = Menu.init(ctx, "Game Over!") catch @panic("Couldn't setup menu");
    _ = go_menu.add_menu_item(.{ .label = "Restart", ._type = .{ .action = go_action_restart } }) catch @panic("add menu item");
    _ = go_menu.add_menu_item(.{ .label = "Setup", ._type = .{ .action = go_action_setup } }) catch @panic("add menu item");
    _ = go_menu.add_menu_item(.{ .label = "Main Menu", ._type = .{ .action = go_action_main_menu } }) catch @panic("add menu item");
}

pub fn update(ctx: *Context, current_time: f64, delta: f64) void {
    _ = ctx;
    _ = current_time;
    _ = delta;
    const screenSize = seizer.getScreenSize();
    go_menu.stage.layout(.{ 0, 0, screenSize.x, screenSize.y });
}

pub fn deinit(ctx: *Context) void {
    go_menu.deinit(ctx);
}

fn go_action_restart(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(GameScreen) catch @panic("Couldn't set screen");
}

fn go_action_setup(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
    menu_ptr.ctx.push_screen(SetupScreen) catch @panic("Couldn't push screen");
}

fn go_action_main_menu(menu_ptr: *Menu, _: ui.EventData) void {
    menu_ptr.ctx.add_score(score) catch @panic("Couldn't add score to high score list");
    menu_ptr.ctx.set_screen(MainMenuScreen) catch @panic("Couldn't set screen");
}

pub fn event(ctx: *Context, evt: seizer.event.Event) void {
    go_menu.event(ctx, evt);
    if (evt == .Quit) {
        seizer.quit();
    }
}

pub fn render(ctx: *Context, alpha: f64) void {
    const menu_size = go_menu.getMinSize(ctx);
    go_menu.render(ctx, alpha, menu_size);

    ctx.flat.flush();
}
