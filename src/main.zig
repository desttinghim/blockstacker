const std = @import("std");
const seizer = @import("seizer");
const Texture = seizer.Texture;
const SpriteBatch = seizer.batch.SpriteBatch;
const BitmapFont = seizer.font.Bitmap;
const Context = @import("context.zig").Context;
const ScoreEntry = @import("score.zig").ScoreEntry;
const audio = seizer.audio;
const crossdb = @import("crossdb");
const chrono = @import("chrono");
const util = @import("util.zig");
const scene = seizer.scene;

pub const SceneManager = scene.Manager(Context, &[_]type {
    @import("MainMenu.zig"),
    // @import("Game.zig"),
    // @import("ScoreScreen.zig"),
    // @import("SetupScreen.zig"),
});

pub usingnamespace seizer.run(.{
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

var ctx: Context = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var rng: std.rand.DefaultPrng = undefined;
var audioEngine: audio.Engine = undefined;

pub fn onInit() !void {
    var seed: u64 = undefined;
    seizer.randomBytes(std.mem.asBytes(&seed));
    rng = std.rand.DefaultPrng.init(seed);

    var allocator = gpa.allocator();
    try audioEngine.init(allocator);
    var load_tileset = async Texture.initFromFile(allocator, "assets/blocks.png", .{});
    var load_tilemap = async util.load_tilemap_file(allocator, "assets/blocks.json", 4 * 1024);
    var load_font = async BitmapFont.initFromFile(allocator, "assets/PressStart2P_8.fnt");
    var load_hello_sound = async audioEngine.load(allocator, "assets/slideswitch.wav", 2 * 1024 * 1024);
    var load_clock0_sound = async audioEngine.load(allocator, "assets/clock0.wav", 2 * 1024 * 1024);
    var load_clock1_sound = async audioEngine.load(allocator, "assets/clock1.wav", 2 * 1024 * 1024);
    var load_clock2_sound = async audioEngine.load(allocator, "assets/clock2.wav", 2 * 1024 * 1024);
    var load_clock3_sound = async audioEngine.load(allocator, "assets/clock3.wav", 2 * 1024 * 1024);
    var load_clock4_sound = async audioEngine.load(allocator, "assets/clock4.wav", 2 * 1024 * 1024);
    var load_clock5_sound = async audioEngine.load(allocator, "assets/clock5.wav", 2 * 1024 * 1024);
    var load_clock6_sound = async audioEngine.load(allocator, "assets/clock6.wav", 2 * 1024 * 1024);
    var load_clock7_sound = async audioEngine.load(allocator, "assets/clock7.wav", 2 * 1024 * 1024);
    var open_db = async crossdb.Database.open(allocator, "blockstacker", "scores", .{
        .version = 1,
        .onupgrade = upgradeDb,
    });

    // TODO: Make chrono work cross platform
    //var load_timezone = if (std.builtin.os.tag != .freestanding) async chrono.timezone.TimeZone.loadTZif(&gpa.allocator, "/etc/localtime") else undefined;
    const sprite_batch = try SpriteBatch.init(gpa.allocator(), seizer.getScreenSize());

    ctx = .{
        .tileset_tex = try await load_tileset,
        .tilemap = try await load_tilemap,
        .flat = sprite_batch,
        .font = try await load_font,
        .allocator = allocator,
        .rand = rng.random(),
        .scene = try SceneManager.init(allocator, &ctx, .{}),
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
        .db = try await open_db,
        .timezone = try chrono.timezone.getLocalTimeZone(gpa.allocator()),
    };

    ctx.sounds.rotate = audioEngine.createSoundNode();
    audioEngine.connectToOutput(ctx.sounds.rotate);

    ctx.sounds.move = audioEngine.createSoundNode();
    const delay1_output_node = try audioEngine.createDelayOutputNode(0.011111);
    const delay2_output_node = try audioEngine.createDelayOutputNode(0.009091);
    const filter1_node = audioEngine.createBiquadNode(delay1_output_node, .{ .kind = .bandpass, .freq = 90, .q = 3 });
    const filter2_node = audioEngine.createBiquadNode(delay2_output_node, .{ .kind = .bandpass, .freq = 110, .q = 3 });

    const volume1_node = try audioEngine.createMixerNode(&[_]audio.MixerInput{
        .{ .handle = ctx.sounds.move, .gain = 1.0 },
        .{ .handle = filter1_node, .gain = 0.3 },
    });
    const volume2_node = try audioEngine.createMixerNode(&[_]audio.MixerInput{
        .{ .handle = ctx.sounds.move, .gain = 1.0 },
        .{ .handle = filter1_node, .gain = 0.3 },
        .{ .handle = filter2_node, .gain = 0.3 },
    });
    _ = try audioEngine.createDelayInputNode(volume1_node, delay1_output_node);
    _ = try audioEngine.createDelayInputNode(volume2_node, delay2_output_node);

    audioEngine.connectToOutput(ctx.sounds.move);
    audioEngine.connectToOutput(filter1_node);
    audioEngine.connectToOutput(filter2_node);

    try ctx.scene.push(.MainMenu);
}

pub fn onDeinit() void {
    ctx.scene.deinit();
    ctx.scores.deinit();
    ctx.font.deinit();
    ctx.flat.deinit();
    ctx.tilemap.deinit(gpa.allocator());

    audioEngine.freeSound(ctx.clips.rotate);
    for (ctx.clips.move) |clip| {
        audioEngine.freeSound(clip);
    }

    audioEngine.deinit();
    ctx.db.deinit();
    chrono.timezone.deinitLocalTimeZone();

    _ = gpa.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    try ctx.scene.event(event);
    if (event == .Quit) {
        seizer.quit();
    }
}

pub fn render(alpha: f64) !void {
    try ctx.scene.render(alpha);
}

pub fn update(current_time: f64, delta: f64) anyerror!void {
    try ctx.scene.update(current_time, delta);
}

pub fn upgradeDb(db: *crossdb.Database, oldVersion: u32, newVersion: u32) anyerror!void {
    _ = oldVersion;
    _ = newVersion;
    try db.createStore("scores", .{});
}
