const std = @import("std");
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Texture = seizer.Texture;
const Patch = @import("context.zig").Patch;

ctx: *Context,
stage: seizer.ui.Stage,
btn_continue: usize = 0,
btn_restart: usize = 0,
btn_menu: usize = 0,

pub fn init(ctx: *Context) !@This() {
    var this = @This(){
        .ctx = ctx,
        .stage = try seizer.ui.Stage.init(ctx.allocator, &ctx.font, &ctx.flat, &Patch.transitions),
    };
    this.stage.painter.scale = 2;
    try Patch.addStyles(&this.stage, this.ctx.ui_tex);

    const namelbl = try this.stage.store.new(.{ .Bytes = "Paused" });
    const continuelbl = try this.stage.store.new(.{ .Bytes = "Continue" });
    const restartlbl = try this.stage.store.new(.{ .Bytes = "Restart" });
    const menulbl = try this.stage.store.new(.{ .Bytes = "Main Menu" });

    const center = try this.stage.layout.insert(null, Patch.frame(.None).container(.Center));
    const frame = try this.stage.layout.insert(center, Patch.frame(.Frame).container(.VList));
    _ = try this.stage.layout.insert(frame, Patch.frame(.Nameplate).dataValue(namelbl));
    this.btn_continue = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(continuelbl));
    this.btn_restart = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(restartlbl));
    this.btn_menu = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(menulbl));

    this.stage.sizeAll();

    return this;
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    _ = current_time;
    _ = delta;
    _ = this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("deinit {}", .{@ptrToInt(this)});
    this.stage.deinit();
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    const Action = enum { None, Restart, Continue, Menu };
    var do = Action.None;
    if (this.stage.event(evt)) |action| {
        if (action.emit == 1) {
            if (action.node) |node| {
                if (node.handle == this.btn_continue) {
                    do = .Continue;
                } else if (node.handle == this.btn_restart) {
                    do = .Restart;
                } else if (node.handle == this.btn_menu) {
                    do = .Menu;
                }
            }
        }
    }
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .X, .ESCAPE => do = .Continue,
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .START, .B => do = .Continue,
            else => {},
        },
        else => {},
    }
    switch (do) {
        .None => {},
        .Restart => {
            // Store ctx so we can refer to it after we've popped the current
            // scene
            const ctx = this.ctx;
            // Remove pause screen
            ctx.scene.pop();
            // Replace game with itself
            try ctx.scene.replace(.Game);
        },
        .Menu => {
            // Store ctx so we can refer to it after we've popped the current
            // scene
            const ctx = this.ctx;
            // Remove the pause screen
            ctx.scene.pop();
            // Remove the game screen
            ctx.scene.pop();
        },
        .Continue  => {
            // @breakpoint();
            this.ctx.scene.pop();
        },
    }
}

pub fn render(this: *@This(), alpha: f64) !void {
    _ = alpha;
    const screen_size = seizer.getScreenSize();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    this.ctx.flat.setSize(screen_size);

    this.stage.paintAll(.{ 0, 0, screen_size.x, screen_size.y });

    this.ctx.flat.flush();
}
