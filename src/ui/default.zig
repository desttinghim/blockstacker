const std = @import("std");
const ui = @import("../ui.zig");
const geom = @import("../geometry.zig");
const seizer = @import("seizer");
const Context = @import("../context.zig").Context;

pub const DefaultStage = ui.Stage(NodeData, Painter);
pub const DefaultNode = DefaultStage.Node;

pub fn init(ctx: *Context) !DefaultStage {
    const painter = try Painter.initAlloc(ctx);
    return DefaultStage.init(ctx.allocator, painter);
}

// pub fn update(ui_ctx: *UIContext) void {
//     ui_ctx.update(.{
//         .pointer = .{
//             .left = input.mouse(.left),
//             .right = input.mouse(.right),
//             .middle = input.mouse(.middle),
//             .pos = input.mousepos(),
//         },
//         .keys = .{
//             .up = input.btn(.one, .up),
//             .down = input.btn(.one, .down),
//             .left = input.btn(.one, .left),
//             .right = input.btn(.one, .right),
//             .accept = input.btn(.one, .x),
//             .reject = input.btn(.one, .z),
//         },
//     });
//     ui_ctx.layout(.{ 0, 0, 160, 160 });
//     ui_ctx.paint();
//     input.update();
// }

/// A simple default UI
pub const NodeData = union(enum) {
    const Text = struct { size: f32, text: []const u8 };
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: Text,
    /// Button
    Button: Text,
};

pub const Painter = struct {
    ctx: *Context,

    pub fn init(ctx: *Context) @This() {
        return @This(){
            .ctx = ctx,
        };
    }

    pub fn initAlloc(ctx: *Context) !*@This() {
        const this = try ctx.allocator.create(@This());
        this.* = .{
            .ctx = ctx,
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
        }
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    _ = label;
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
