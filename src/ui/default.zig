const std = @import("std");
const ui = @import("../ui.zig");
const geom = @import("../geometry.zig");
const seizer = @import("seizer");
const Context = @import("../context.zig").Context;
const NineSlice = @import("../nineslice.zig").NineSlice;

pub const DefaultStage = ui.Stage(NodeData, Painter);
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
    /// Button
    Button: Text,
};

const Texture = seizer.Texture;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const Vec2 = seizer.math.Vec(2, i32);
const vec2 = Vec2.init;
fn pixelToTex(tex: *Texture, pixel: Vec2) Vec2f {
    return vec2f(
        @intToFloat(f32, pixel.x) / @intToFloat(f32, tex.size.x),
        @intToFloat(f32, pixel.y) / @intToFloat(f32, tex.size.y),
    );
}

pub const Painter = struct {
    ctx: *Context,
    nineslice: NineSlice,

    pub fn init(ctx: *Context) @This() {
        return @This(){
            .ctx = ctx,
        };
    }

    pub fn initAlloc(ctx: *Context) !*@This() {
        const this = try ctx.allocator.create(@This());
        this.* = .{
            .ctx = ctx,
            .nineslice = NineSlice.init(
                pixelToTex(&ctx.tileset_tex, vec2(0, 48)),
                pixelToTex(&ctx.tileset_tex, vec2(48, 96)),
                vec2f(16, 16),
            ),
        };
        return this;
    }

    pub fn deinit(this: *@This()) void {
        this.ctx.allocator.destroy(this);
    }

    pub fn size(this: *@This(), data: NodeData) geom.Vec2 {
        switch (data) {
            .Label, .Button => |label| {
                const line_height = this.ctx.font.lineHeight * label.size;
                const line_width = this.ctx.font.calcTextWidth(label.text, label.size);
                return .{
                    @floatToInt(i32, line_width),
                    @floatToInt(i32, line_height),
                };
            },
        }
    }

    pub fn paint(this: *@This(), node: DefaultNode) void {
        var left = geom.rect.left(node.bounds);
        var right = geom.rect.right(node.bounds);
        var top = geom.rect.top(node.bounds);
        var bottom = geom.rect.bottom(node.bounds);
        _ = left;
        _ = right;
        _ = top;
        _ = bottom;

        _ = this;

        const rect_size = geom.rect.size(node.bounds);
        // Make sure we are at least the minimum size to prevent crashing
        var sizex = @intCast(u32, if (rect_size[0] < node.min_size[0])
            node.min_size[0]
        else
            rect_size[0]);
        var sizey = @intCast(u32, if (rect_size[1] < node.min_size[1])
            node.min_size[1]
        else
            rect_size[1]);

        if (node.has_background) {
            _ = sizex;
            _ = sizey;
            // Draw background
            this.nineslice.draw(&this.ctx.flat, this.ctx.tileset_tex, geom.rect.itof(node.bounds));
        }
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    const pos = seizer.math.Vec(2, f32).init(@intToFloat(f32, left), @intToFloat(f32, top));
                    this.ctx.font.drawText(&this.ctx.flat, label.text, pos, .{ .scale = label.size, .textBaseline = .Top });
                },
                .Button => |btn_label| {
                    _ = btn_label;
                    // Clear background
                    switch (node.pointer_state) {
                        .Open, .Hover, .Drag => {},
                        .Press => {},
                        .Click => {},
                    }
                },
            }
        }
    }
};
