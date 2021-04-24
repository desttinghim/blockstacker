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
    var seed: u64 = undefined;
    seizer.randomBytes(std.mem.asBytes(&seed));
    rng = std.rand.DefaultPrng.init(seed);

    var allocator = &gpa.allocator;
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png");
    var load_font = async FontRenderer.initFromFile(allocator, "assets/PressStart2P_8.fnt");
    var load_hello_sound = async seizer.audio.engine.load(allocator, "assets/hello.wav", 2 * 1024 * 1024);

    ctx = .{
        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(ctx.allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
        .allocator = allocator,
        .rand = &rng.random,
        .screens = std.ArrayList(Screen).init(allocator),
        .scores = std.ArrayList(ScoreEntry).init(allocator),
        .setup = .{},
        .sounds = .{
            .move = try await load_hello_sound,
        },
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

pub const log = seizer.log;
pub const panic = seizer.panic;
pub usingnamespace if (std.builtin.os.tag == .freestanding)
    struct {
        pub const os = struct {
            pub const bits = struct {
                pub const fd_t = i32;
                pub const STDOUT_FILENO = 0;
                pub const STDERR_FILENO = 1;
            };
            pub const system = struct {
                pub fn isatty(x: anytype) i32 {
                    return 0;
                }
            };
        };
    }
else
    struct {};
