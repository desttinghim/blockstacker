const std = @import("std");
const ui = @import("../ui.zig");
const geom = @import("../geometry.zig");
const seizer = @import("seizer");
const Context = @import("../context.zig").Context;
const NineSlice = @import("../nineslice.zig").NineSlice;
const util = @import("../util.zig");

pub const DefaultStage = ui.Stage(NodeStyle, Painter, NodeData);
pub const DefaultNode = DefaultStage.Node;

pub fn init(ctx: *Context) !DefaultStage {
    const painter = try Painter.initAlloc(ctx);
    return DefaultStage.init(ctx.allocator, painter);
}

/// A simple default UI
pub const NodeData = union(enum) {
    const Text = struct { size: f32, text: []const u8 };
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: Text,
};

pub const NodeStyle = enum {
    none,
    frame,
    nameplate,
};

pub const Painter = struct {
    ctx: *Context,
    frame9p: NineSlice,
    nameplate9p: NineSlice,
    scale: i32,
    scalef: f32,

    pub fn init(ctx: *Context) @This() {
        const vec2 = seizer.math.Vec(2, i32).init;
        const vec2f = seizer.math.Vec(2, f32).init;
        return @This(){
            .ctx = ctx,
            .frame9p = NineSlice.init(util.pixelToTex(&ctx.tileset_tex, vec2(0, 48)), util.pixelToTex(&ctx.tileset_tex, vec2(48, 96)), vec2f(16, 16), 2),
            .nameplate9p = NineSlice.init(util.pixelToTex(&ctx.tileset_tex, vec2(0, 96)), util.pixelToTex(&ctx.tileset_tex, vec2(48, 144)), vec2f(16, 16), 2),
            .scale = 2,
            .scalef = 2,
        };
    }

    pub fn initAlloc(ctx: *Context) !*@This() {
        const this = try ctx.allocator.create(@This());
        this.* = @This().init(ctx);
        return this;
    }

    pub fn deinit(this: *@This()) void {
        this.ctx.allocator.destroy(this);
    }

    pub fn padding(this: *@This(), node: DefaultNode) geom.Rect {
        const pad: geom.Rect = switch (node.style) {
            .none => .{ 0, 0, 0, 0 },
            .frame => @splat(4, 16  * this.scale),
            .nameplate => @splat(4, 16  * this.scale),
        };
        return pad;
    }

    pub fn size(this: *@This(), node: DefaultNode) geom.Vec2 {
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    const line_height = this.ctx.font.lineHeight * label.size;
                    const line_width = this.ctx.font.calcTextWidth(label.text, label.size);
                    return geom.Vec2{
                        @floatToInt(i32, line_width),
                        @floatToInt(i32, line_height),
                    };
                },
            }
        }
        return .{ 0, 0 };
    }

    pub fn paint(this: *@This(), node: DefaultNode) void {
        switch (node.style) {
            .none => {},
            .nameplate => {
                this.nameplate9p.draw(&this.ctx.flat, this.ctx.tileset_tex, geom.rect.itof(node.bounds));
            },
            .frame => {
                this.frame9p.draw(&this.ctx.flat, this.ctx.tileset_tex, geom.rect.itof(node.bounds));
            },
        }
        const area = node.bounds + (geom.Rect{1,1, -1, -1} * node.padding);
        var left = geom.rect.left(area);
        var top = geom.rect.top(area);
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    const pos = seizer.math.Vec(2, f32).init(@intToFloat(f32, left), @intToFloat(f32, top));
                    this.ctx.font.drawText(&this.ctx.flat, label.text, pos, .{ .scale = label.size, .textBaseline = .Top });
                },
            }
        }
    }
};
