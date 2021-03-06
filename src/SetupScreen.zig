const std = @import("std");
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
// const GameScreen = @import("game.zig").GameScreen;
const Texture = seizer.Texture;
const Patch = @import("context.zig").Patch;

// ====== Setup screen =======

ctx: *Context,
stage: seizer.ui.Stage,
level_int: seizer.ui.store.Ref,
btn_start: usize = 0,
btn_dec: usize = 0,
btn_inc: usize = 0,
btn_back: usize = 0,

pub fn init(ctx: *Context) !@This() {
    var this = @This(){
        .ctx = ctx,
        .stage = try seizer.ui.Stage.init(ctx.allocator, &ctx.font, &ctx.flat, &Patch.transitions),
        .level_int = undefined,
    };
    this.stage.painter.scale = 2;
    try Patch.addStyles(&this.stage, this.ctx.ui_tex);

    const namelbl = try this.stage.store.new(.{ .Bytes = "Setup" });
    const startlbl = try this.stage.store.new(.{ .Bytes = "Start Game" });
    const increment = try this.stage.store.new(.{ .Bytes = ">" });
    const decrement = try this.stage.store.new(.{ .Bytes = "<" });
    const levellbl = try this.stage.store.new(.{ .Bytes = "Level:" });
    this.level_int = try this.stage.store.new(.{ .Int = this.ctx.setup.level });
    const backlbl = try this.stage.store.new(.{ .Bytes = "Back" });

    const center = try this.stage.layout.insert(null, Patch.frame(.None).container(.Center));
    const frame = try this.stage.layout.insert(center, Patch.frame(.Frame).container(.VList));
    const center_name = try this.stage.layout.insert(frame, Patch.frame(.None).container(.Center));
    _ = try this.stage.layout.insert(center_name, Patch.frame(.Nameplate).dataValue(namelbl));
    this.btn_start = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(startlbl));
    const spinner = try this.stage.layout.insert(frame, Patch.frame(.None).container(.HList));
    {
        this.btn_dec = try this.stage.layout.insert(spinner, Patch.frame(.Keyrest).dataValue(decrement));
        const label_center = try this.stage.layout.insert(spinner, Patch.frame(.None).container(.Center));
        const label = try this.stage.layout.insert(label_center, Patch.frame(.Label).container(.HList));
        _ = try this.stage.layout.insert(label, Patch.frame(.None).dataValue(levellbl));
        _ = try this.stage.layout.insert(label, Patch.frame(.None).dataValue(this.level_int));
        this.btn_inc = try this.stage.layout.insert(spinner, Patch.frame(.Keyrest).dataValue(increment));
    }
    this.btn_back = try this.stage.layout.insert(frame, Patch.frame(.Keyrest).dataValue(backlbl));

    this.stage.sizeAll();

    return this;
}

pub fn deinit(this: *@This()) void {
    this.stage.deinit();
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    _ = this;
    _ = current_time;
    _ = delta;
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    const Action = enum { None, Start, Inc, Dec, Back };
    var do = Action.None;
    if (this.stage.event(evt)) |action| {
        if (action.emit == 1) {
            if (action.node) |node| {
                if (node.handle == this.btn_start) {
                    do = .Start;
                } else if (node.handle == this.btn_inc) {
                    do = .Inc;
                } else if (node.handle == this.btn_dec) {
                    do = .Dec;
                } else if (node.handle == this.btn_back) {
                    do = .Back;
                }
            }
        }
    }
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .X, .ESCAPE => do = .Back,
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .START, .B => do = .Back,
            else => {},
        },
        else => {},
    }
    switch (do) {
        .None => {},
        .Start => {
            var level = this.stage.store.get(this.level_int);
            this.ctx.setup.level = @intCast(u8, @truncate(i8, level.Int));

            try this.ctx.scene.replace(.Game);
        },
        .Inc => {
            var level = this.stage.store.get(this.level_int);
            if (level.Int < 9) {
                level.Int += 1;
                try this.stage.store.set(.Int, this.level_int, level.Int);
            }
        },
        .Dec => {
            var level = this.stage.store.get(this.level_int);
            if (level.Int > 0) {
                level.Int -= 1;
                try this.stage.store.set(.Int, this.level_int, level.Int);
            }
        },
        .Back => {
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
