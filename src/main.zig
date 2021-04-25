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
const audio = seizer.audio;

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
var audioEngine: audio.Engine = undefined;

pub fn onInit() !void {
    var seed: u64 = undefined;
    seizer.randomBytes(std.mem.asBytes(&seed));
    rng = std.rand.DefaultPrng.init(seed);

    var allocator = &gpa.allocator;
    try audioEngine.init(allocator);
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png");
    var load_font = async FontRenderer.initFromFile(allocator, "assets/PressStart2P_8.fnt");
    var load_hello_sound = async audioEngine.load(allocator, "assets/slideswitch.wav", 2 * 1024 * 1024);
    var load_clock0_sound = async audioEngine.load(allocator, "assets/clock0.wav", 2 * 1024 * 1024);
    var load_clock1_sound = async audioEngine.load(allocator, "assets/clock1.wav", 2 * 1024 * 1024);
    var load_clock2_sound = async audioEngine.load(allocator, "assets/clock2.wav", 2 * 1024 * 1024);
    var load_clock3_sound = async audioEngine.load(allocator, "assets/clock3.wav", 2 * 1024 * 1024);
    var load_clock4_sound = async audioEngine.load(allocator, "assets/clock4.wav", 2 * 1024 * 1024);
    var load_clock5_sound = async audioEngine.load(allocator, "assets/clock5.wav", 2 * 1024 * 1024);
    var load_clock6_sound = async audioEngine.load(allocator, "assets/clock6.wav", 2 * 1024 * 1024);
    var load_clock7_sound = async audioEngine.load(allocator, "assets/clock7.wav", 2 * 1024 * 1024);

    ctx = .{
        .tileset_tex = try await load_tileset,
        .flat = try FlatRenderer.init(ctx.allocator, seizer.getScreenSize().intToFloat(f32)),
        .font = try await load_font,
        .allocator = allocator,
        .rand = &rng.random,
        .screens = std.ArrayList(Screen).init(allocator),
        .scores = std.ArrayList(ScoreEntry).init(allocator),
        .setup = .{},
        .audioEngine = &audioEngine,
        .clips = .{
            .rotate = try await load_hello_sound,
            .move = .{
                try await load_clock0_sound,
                try await load_clock1_sound,
                try await load_clock2_sound,
                try await load_clock3_sound,
                try await load_clock4_sound,
                try await load_clock5_sound,
                try await load_clock6_sound,
                try await load_clock7_sound,
            },
        },
        .sounds = undefined,
    };

    ctx.sounds.rotate = audioEngine.createSoundNode(ctx.clips.rotate);
    audioEngine.connectToOutput(ctx.sounds.rotate);

    const delay1_sec = 0.011111;
    const delay1_freq = 90;
    const delay2_sec = 0.009091;
    const delay2_freq = 110;
    const sample_rate = @intToFloat(f32, ctx.audioEngine.spec.freq);

    for (ctx.clips.move) |clip, i| {
        ctx.sounds.move[i] = audioEngine.createSoundNode(clip);
    }
    const mixer_node = try audioEngine.createMixerNode(&[_]audio.NodeInput{
        .{ .handle = ctx.sounds.move[0] },
        .{ .handle = ctx.sounds.move[1] },
        .{ .handle = ctx.sounds.move[2] },
        .{ .handle = ctx.sounds.move[3] },
        .{ .handle = ctx.sounds.move[4] },
        .{ .handle = ctx.sounds.move[5] },
        .{ .handle = ctx.sounds.move[6] },
        .{ .handle = ctx.sounds.move[7] },
    });
    const delay1_output_node = try audioEngine.createDelayOutputNode(@floatToInt(u32, delay1_sec * sample_rate));
    const delay2_output_node = try audioEngine.createDelayOutputNode(@floatToInt(u32, delay2_sec * sample_rate));
    const filter1_node = audioEngine.createBiquadNode(delay1_output_node, audio.Biquad.bandpass(delay1_freq / sample_rate, 3));
    const filter2_node = audioEngine.createBiquadNode(delay2_output_node, audio.Biquad.bandpass(delay2_freq / sample_rate, 3));

    const volume1_node = try audioEngine.createMixerNode(&[_]audio.NodeInput{
        .{ .handle = mixer_node, .volume = 1.0 },
        .{ .handle = filter1_node, .volume = 0.3 },
    });
    const volume2_node = try audioEngine.createMixerNode(&[_]audio.NodeInput{
        .{ .handle = mixer_node, .volume = 1.0 },
        .{ .handle = filter1_node, .volume = 0.3 },
        .{ .handle = filter2_node, .volume = 0.3 },
    });
    const delay1_input_node = try audioEngine.createDelayInputNode(volume1_node, delay1_output_node);
    const delay2_input_node = try audioEngine.createDelayInputNode(volume2_node, delay2_output_node);

    audioEngine.connectToOutput(mixer_node);
    audioEngine.connectToOutput(filter1_node);
    audioEngine.connectToOutput(filter2_node);

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

    audioEngine.freeSound(ctx.clips.rotate);
    for (ctx.clips.move) |clip| {
        audioEngine.freeSound(clip);
    }

    audioEngine.deinit();

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
