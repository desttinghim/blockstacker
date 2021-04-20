const std = @import("std");
const seizer = @import("seizer");
const FlatRenderer = @import("flat_render.zig").FlatRenderer;
const FontRenderer = @import("font_render.zig").BitmapFontRenderer;
const Texture = @import("texture.zig").Texture;
const Context = @import("context.zig").Context;
const Screen = @import("context.zig").Screen;
const MainMenuScreen = @import("main_menu.zig").MainMenuScreen;
const GameScreen = @import("game.zig").GameScreen;
const ScoreEntry = @import("score.zig").ScoreEntry;

pub fn main() void {
    seizer.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .render = render,
        .update = update,
        .window = .{
            .title = "Blockstacker",
            .width = 480,
            .height = 320,
        },
        .sdlControllerDBPath = "sdl_controllers.txt",
    });
}

var ctx: Context = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var rng: std.rand.DefaultPrng = undefined;

pub fn onInit() !void {
    rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
    var allocator = &gpa.allocator;
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png");
    var load_font = async FontRenderer.initFromFile(allocator, "assets/PressStart2P_8.fnt");

    ctx = .{
        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(ctx.allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
        .allocator = allocator,
        .rand = &rng.random,
        .screens = std.ArrayList(Screen).init(allocator),
        .scores = std.ArrayList(ScoreEntry).init(allocator),
        .setup = .{},
    };

    try ctx.push_screen(MainMenuScreen);
}

pub fn onDeinit() void {
    for (ctx.screens.items) |screen| {
        screen.deinit(&ctx);
    }
    ctx.screens.deinit();
    ctx.scores.deinit();
    ctx.font.deinit();
    ctx.flat.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    ctx.current_screen().event(&ctx, event);
}

pub fn render(alpha: f64) !void {
    for (ctx.screens.items) |screen| {
        screen.render(&ctx, alpha);
    }
}

pub fn update(current_time: f64, delta: f64) anyerror!void {
    ctx.current_screen().update(&ctx, current_time, delta);
}
