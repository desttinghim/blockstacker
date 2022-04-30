const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;

pub const Menu = struct {
    menuItems: std.ArrayList(MenuItem),
    selected: usize,
    textSize: f32 = 2,

    pub fn init(allocator: std.mem.Allocator, items: []const MenuItem) !@This() {
        var menuItems = std.ArrayList(MenuItem).init(allocator);
        try menuItems.appendSlice(items);
        errdefer menuItems.deinit();
        return @This(){
            .menuItems = menuItems,
            .selected = 0,
        };
    }

    pub fn deinit(this: *@This(), ctx: *Context) void {
        for (this.menuItems.items) |*item| {
            item.ondeinit(ctx, item);
        }
        this.menuItems.deinit();
    }

    pub fn event(this: *@This(), ctx: *Context, evt: seizer.event.Event) void {
        var up = false;
        var down = false;
        var left = false;
        var right = false;
        var activate = false;
        switch (evt) {
            .KeyDown => |e| switch (e.scancode) {
                .Z, .RETURN => activate = true,
                .W, .UP => up = true,
                .A, .LEFT => left = true,
                .D, .RIGHT => right = true,
                .S, .DOWN => down = true,
                else => {},
            },
            .ControllerButtonDown => |cbutton| switch (cbutton.button) {
                .A => activate = true,
                .DPAD_DOWN => down = true,
                .DPAD_UP => up = true,
                .DPAD_LEFT => left = true,
                .DPAD_RIGHT => right = true,
                else => {},
            },
            else => {},
        }

        if (down) {
            this.selected += 1;
            this.selected %= this.menuItems.items.len;
        }
        if (up) {
            var new_selected: usize = 0;
            if (@subWithOverflow(usize, this.selected, 1, &new_selected)) {
                this.selected = this.menuItems.items.len - 1;
            } else {
                this.selected = new_selected;
            }
        }
        if (activate) {
            this.menuItems.items[this.selected].onaction(ctx, &this.menuItems.items[this.selected]);
        }
        if (left or right) {
            this.menuItems.items[this.selected].onspin(ctx, &this.menuItems.items[this.selected], right);
        }
    }

    pub fn getMinSize(this: @This(), ctx: *Context) Vec2f {
        var menu_width: f32 = 0;
        for (this.menuItems.items) |item| {
            const width = ctx.font.calcTextWidth(item.label, this.textSize);
            menu_width = std.math.max(menu_width, width);
        }

        const item_height = ctx.font.lineHeight * this.textSize;
        const menu_height = item_height * @intToFloat(f32, this.menuItems.items.len);

        return vec2f(menu_width, menu_height);
    }

    pub fn render(this: @This(), ctx: *Context, alpha: f64, start_pos: Vec2f) void {
        _ = alpha;

        const item_height = ctx.font.lineHeight * this.textSize;

        for (this.menuItems.items) |item, idx| {
            const pos = start_pos.add(0, @intToFloat(f32, idx) * item_height);

            ctx.font.drawText(&ctx.flat, item.label, pos, .{ .scale = this.textSize, .textBaseline = .Top });

            if (this.selected == idx) {
                ctx.font.drawText(&ctx.flat, ">", pos, .{ .textAlign = .Right, .scale = this.textSize, .textBaseline = .Top });
            }
        }
    }
};

pub const MenuItem = struct {
    label: []const u8,
    onaction: fn (*Context, *MenuItem) void = null_action,
    onspin: fn (*Context, *MenuItem, bool) void = null_spin,
    ondeinit: fn (*Context, *MenuItem) void = null_deinit,

    fn null_action(ctx: *Context, menuItem: *MenuItem) void {
        _ = ctx;
        _ = menuItem;
    }
    fn null_spin(ctx: *Context, menuItem: *MenuItem, increase: bool) void {
        _ = ctx;
        _ = menuItem;
        _ = increase;
    }
    fn null_deinit(ctx: *Context, menuItem: *MenuItem) void {
        _ = ctx;
        _ = menuItem;
    }
};
