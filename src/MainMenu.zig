const std = @import("std");
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
const Texture = seizer.Texture;
const Patch = @import("context.zig").Patch;

ctx: *Context,
stage: seizer.ui.Stage,
btn_start: usize = 0,
btn_scores: usize = 0,
btn_quit: usize = 0,

pub fn init(ctx: *Context) !@This() {
    // TODO: Add settings screen for settings that don't affect gameplay
    var this = @This(){
        .ctx = ctx,
        .stage = try seizer.ui.Stage.init(ctx.allocator, &ctx.font, &ctx.flat, &Patch.transitions),
    };
    this.stage.painter.scale = 2;
    try Patch.addStyles(&this.stage, this.ctx.ui_tex);

    const namelbl = try this.stage.store.new(.{ .Bytes = "BlockStacker" });
    const startlbl = try this.stage.store.new(.{ .Bytes = "Start Game" });
    const scorelbl = try this.stage.store.new(.{ .Bytes = "Scores" });
    const quitlbl = try this.stage.store.new(.{ .Bytes = "Quit" });

    const center = try this.stage.layout.insert(null, Patch.frame(.None).container(.Center));
    const frame = try this.stage.layout.insert(center, Patch.frame(.Frame).container(.VList));
    _ = try this.stage.layout.insert(frame, Patch.frame(.Nameplate).dataValue(namelbl));
    this.btn_start = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(startlbl));
    this.btn_scores = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(scorelbl));
    this.btn_quit = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(quitlbl));

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
    if (this.stage.event(evt)) |action| {
        if (action.emit == 1) {
            if (action.node) |node| {
                if (node.handle == this.btn_start) {
                    return this.ctx.scene.push(.SetupScreen);
                } else if (node.handle == this.btn_scores) {
                    return this.ctx.scene.push(.ScoreScreen);
                } else if (node.handle == this.btn_quit) {
                    seizer.quit();
                }
            }
        }
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
