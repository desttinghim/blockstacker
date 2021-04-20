const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;

pub const Menu = struct {
    items: []const MenuItem,
    selected: usize,
    textSize: f32 = 2,

    pub fn init(items: []const MenuItem) @This() {
        return @This(){
            .items = items,
            .selected = 0,
        };
    }

    pub fn event(this: *@This(), ctx: *Context, evt: seizer.event.Event) void {
        var up = false;
        var down = false;
        var activate = false;
        switch (evt) {
            .KeyDown => |e| switch (e.scancode) {
                .Z, .RETURN => activate = true,
                .W, .UP => up = true,
                .S, .DOWN => down = true,
                else => {},
            },
            .ControllerButtonDown => |cbutton| switch (cbutton.button) {
                .A => activate = true,
                .DPAD_DOWN => down = true,
                .DPAD_UP => up = true,
                else => {},
            },
            else => {},
        }

        if (down) {
            this.selected += 1;
            this.selected %= this.items.len;
        }
        if (up) {
            var new_selected: usize = 0;
            if (@subWithOverflow(usize, this.selected, 1, &new_selected)) {
                this.selected = this.items.len - 1;
            } else {
                this.selected = new_selected;
            }
        }
        if (activate) {
            switch (this.items[this.selected]) {
                .Action => |action| action.onaction(ctx),
            }
        }
    }

    pub fn getMinSize(this: @This(), ctx: *Context) Vec2f {
        var menu_width: f32 = 0;
        for (this.items) |item| {
            const width = switch (item) {
                .Action => |action| ctx.font.calcTextWidth(action.label, this.textSize),
            };
            menu_width = std.math.max(menu_width, width);
        }

        const item_height = ctx.font.lineHeight * this.textSize;
        const menu_height = item_height * @intToFloat(f32, this.items.len);

        return vec2f(menu_width, menu_height);
    }

    pub fn render(this: @This(), ctx: *Context, alpha: f64, start_pos: Vec2f) void {
        const item_height = ctx.font.lineHeight * this.textSize;

        for (this.items) |item, idx| {
            const pos = start_pos.add(0, @intToFloat(f32, idx) * item_height);

            switch (item) {
                .Action => |action| {
                    ctx.font.drawText(&ctx.flat, action.label, pos, .{ .scale = this.textSize, .textBaseline = .Top });
                },
            }

            if (this.selected == idx) {
                ctx.font.drawText(&ctx.flat, ">", pos, .{ .textAlign = .Right, .scale = this.textSize, .textBaseline = .Top });
            }
        }
    }
};

pub const MenuItem = union(enum) {
    Action: Action,
};

pub const Action = struct {
    label: []const u8,
    onaction: fn (*Context) void,
};
