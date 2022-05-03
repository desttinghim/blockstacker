const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const ui = @import("ui/default.zig");
const geom = @import("geometry.zig");

pub const Menu = struct {
    ctx: *Context,
    stage: ui.DefaultStage,
    audience: ui.Audience(MenuAndItem),
    menuItems: std.ArrayList(MenuItem),
    selected: usize,
    textSize: f32 = 2,

    pub fn init(ctx: *Context, items: []const MenuItem) !@This() {
        var stage = try ui.init(ctx);
        var audience = ui.Audience(MenuAndItem).init(ctx.allocator);

        const Node = ui.DefaultNode;
        var center = try stage.insert(null, Node.center(.none));
        var frame = try stage.insert(center, Node.vlist(.frame));
        // _ = try stage.insert(frame, .{ .style = .nameplate, .data = .{ .Label = .{ .size = 2, .text = "Hello World" } } });
        // const buttons = try stage.insert(frame, Node.vlist(.none));

        for (items) |item| {
            switch (item._type) {
                .action => |action| {
                    const btn = try stage.insert(frame, Node.relative(.key).dataValue(.{ .Label = .{ .size = 2, .text = item.label } }));
                    try audience.add(btn, .PointerClick, action);
                },
                .spinner => |spin| {
                    const div = try stage.insert(frame, Node.hlist(.none));

                    const dec = try stage.insert(div, Node.relative(.key).dataValue(.{ .Label = .{ .size = 2, .text = "<" } }));
                    try audience.add(dec, .PointerClick, spin.decrease);

                    _ = try stage.insert(div, Node.relative(.nameplate).dataValue(.{ .Label = .{ .size = 2, .text = item.label } }));

                    const inc = try stage.insert(div, Node.relative(.key).dataValue(.{ .Label = .{ .size = 2, .text = ">" } }));
                    try audience.add(inc, .PointerClick, spin.increase);
                },
            }
        }

        var menuItems = std.ArrayList(MenuItem).init(ctx.allocator);
        try menuItems.appendSlice(items);
        errdefer menuItems.deinit();
        return @This(){
            .ctx = ctx,
            .menuItems = menuItems,
            .selected = 0,
            .stage = stage,
            .audience = audience,
        };
    }

    pub fn deinit(this: *@This(), ctx: *Context) void {
        this.audience.deinit();
        this.stage.painter.deinit();
        this.stage.deinit();
        for (this.menuItems.items) |*item| {
            item.ondeinit(ctx, item);
        }
        this.menuItems.deinit();
    }

    pub fn event(this: *@This(), _: *Context, evt: seizer.event.Event) void {
        var up = false;
        var down = false;
        var left = false;
        var right = false;
        var activate = false;
        var mouse_left = false;
        var mousepos = geom.Vec2{ 0, 0 };
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
            .MouseMotion => |mouse| {
                mousepos = .{ mouse.pos.x, mouse.pos.y };
            },
            .MouseButtonDown => |mouse| {
                mouse_left = mouse.button == .Left;
                mousepos = .{ mouse.pos.x, mouse.pos.y };
            },
            .MouseButtonUp => |mouse| {
                mousepos = .{ mouse.pos.x, mouse.pos.y };
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
        // if (activate) {
        //     this.menuItems.items[this.selected].onaction(ctx, &this.menuItems.items[this.selected]);
        // }
        // if (left or right) {
        //     this.menuItems.items[this.selected].onspin(ctx, &this.menuItems.items[this.selected], right);
        // }

        var iter = this.stage.poll(.{
            .pointer = .{
                .left = mouse_left,
                .right = false,
                .middle = false,
                .pos = mousepos,
            },
            .keys = .{
                .up = false,
                .down = false,
                .left = false,
                .right = false,
                .accept = false,
                .reject = false,
            },
        });
        while (iter.next()) |uievent| {
            std.log.info("{} {} {}", .{ uievent._type, uievent.target, uievent.current });
            const mai = MenuAndItem{ .menu = this, .item = &this.menuItems.items[0] };
            this.audience.dispatch(mai, uievent);
        }
        const screenSize = seizer.getScreenSize();
        this.stage.layout(.{ 0, 0, screenSize.x, screenSize.y });
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
        this.stage.paint();

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

// pub const MenuItem = struct {
//     label: []const u8,
//     onaction: fn (*Context, *MenuItem) void = null_action,
//     onspin: fn (*Context, *MenuItem, bool) void = null_spin,
//     ondeinit: fn (*Context, *MenuItem) void = null_deinit,

//     fn null_action(ctx: *Context, menuItem: *MenuItem) void {
//         _ = ctx;
//         _ = menuItem;
//     }
//     fn null_spin(ctx: *Context, menuItem: *MenuItem, increase: bool) void {
//         _ = ctx;
//         _ = menuItem;
//         _ = increase;
//     }
//     fn null_deinit(ctx: *Context, menuItem: *MenuItem) void {
//         _ = ctx;
//         _ = menuItem;
//     }
// };

pub const MenuAndItem = struct {
    menu: *Menu,
    item: *MenuItem,
};

pub const MenuItem = struct {
    label: []const u8,
    _type: union(enum) {
        action: fn (MenuAndItem, ui.EventData) void,
        spinner: struct {
            increase: fn (MenuAndItem, ui.EventData) void,
            decrease: fn (MenuAndItem, ui.EventData) void,
        },
    } = .{ .action = null_action },
    ondeinit: fn (*Context, *MenuItem) void = null_deinit,

    fn null_action(_: MenuAndItem, _: ui.EventData) void {}
    fn null_deinit(ctx: *Context, menuItem: *MenuItem) void {
        _ = ctx;
        _ = menuItem;
    }
};
