const std = @import("std");
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;

// Global variables, initialized in main.zig
pub const Context = struct {
    flat: FlatRenderer,
    font: FontRenderer,
    tileset_tex: Texture,
    allocator: *std.mem.Allocator,
    rand: *std.rand.Random,
};
