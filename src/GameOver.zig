const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const Context = @import("context.zig").Context;
const Patch = @import("context.zig").Patch;

ctx: *Context,
stage: seizer.ui.Stage,
btn_restart: usize = 0,
btn_setup: usize = 0,
btn_mainmenu: usize = 0,

pub fn init(ctx: *Context) !@This() {
    var this = @This(){
        .ctx = ctx,
        .stage = try seizer.ui.Stage.init(ctx.allocator, &ctx.font, &ctx.flat, &Patch.transitions),
    };
    this.stage.painter.scale = 2;
    try Patch.addStyles(&this.stage, this.ctx.ui_tex);

    const namelbl = try this.stage.store.new(.{ .Bytes = "Game Over!" });
    const restartlbl = try this.stage.store.new(.{ .Bytes = "Restart" });
    const setuplbl = try this.stage.store.new(.{ .Bytes = "Setup" });
    const mainmenulbl = try this.stage.store.new(.{ .Bytes = "Main Menu" });

    const center = try this.stage.layout.insert(null, Patch.frame(.None).container(.Center));
    const frame = try this.stage.layout.insert(center, Patch.frame(.Frame).container(.VList));
    _ = try this.stage.layout.insert(frame, Patch.frame(.Nameplate).dataValue(namelbl));
    this.btn_restart = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(restartlbl));
    this.btn_setup = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(setuplbl));
    this.btn_mainmenu = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(mainmenulbl));

    this.stage.sizeAll();

    return this;
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    _ = current_time;
    _ = delta;
    _ = this;
}

pub fn deinit(this: *@This()) void {
    this.stage.deinit();
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    // go_menu.event(ctx, evt);
    if (this.stage.event(evt)) |action| {
        if (action.emit == 1) {
            if (action.node) |node| {
                if (node.handle == this.btn_restart) {
                    try this.ctx.scene.replace(.Game);
                } else if (node.handle == this.btn_setup) {
                    try this.ctx.scene.replace(.SetupScreen);
                } else if (node.handle == this.btn_mainmenu) {
                    this.ctx.scene.pop();
                }
            }
        }
    }
    if (evt == .Quit) {
        seizer.quit();
    }
}

pub fn render(this: *@This(), alpha: f64) !void {
    _ = alpha;
    const screen_size = seizer.getScreenSize();

    gl.viewport(0, 0, screen_size.x, screen_size.y);
    this.ctx.flat.setSize(screen_size);

    this.stage.paintAll(.{ 0, 0, screen_size.x, screen_size.y });

    this.ctx.flat.flush();
}
