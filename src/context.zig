const std = @import("std");
const seizer = @import("seizer");
const Texture = seizer.Texture;
const SpriteBatch = seizer.batch.SpriteBatch;
const BitmapFont = seizer.font.Bitmap;
const ScoreEntry = @import("score.zig").ScoreEntry;
const audio = seizer.audio;
const crossdb = @import("crossdb");
const encode = @import("proto_structs").encode;
const chrono = @import("chrono");
const Tilemap = @import("util.zig").Tilemap;
const NinePatch = seizer.ninepatch.NinePatch;
const Observer = seizer.ui.Observer;
const geom = seizer.geometry;

pub const Context = struct {
    flat: SpriteBatch,
    font: BitmapFont,
    ui_tex: Texture,
    tileset_tex: Texture,
    tilemap: Tilemap,
    allocator: std.mem.Allocator,
    rand: std.rand.Random,
    scene: @import("main.zig").SceneManager,
    scores: std.ArrayList(ScoreEntry),
    setup: Setup,
    audioEngine: *audio.Engine,
    clips: struct {
        rotate: seizer.audio.SoundHandle,
        move: [8]seizer.audio.SoundHandle,
    },
    sounds: struct {
        rotate: seizer.audio.NodeHandle,
        move: seizer.audio.NodeHandle,
    },
    db: crossdb.Database,
    timezone: *const chrono.timezone.TimeZone,

    pub fn add_score(self: *@This(), score: ScoreEntry) !void {
        try seizer.execute(self.allocator, add_score_async, .{ self, score });
    }

    pub fn add_score_async(self: *@This(), score: ScoreEntry) void {
        var txn = self.db.begin(&.{"scores"}, .{}) catch @panic("Failed to add score");
        errdefer txn.deinit();

        {
            var scores = txn.store("scores") catch @panic("Failed to add score");
            defer scores.release();

            var key: [8]u8 = undefined;

            std.mem.writeIntBig(i64, &key, score.timestamp);

            const val = encode(self.allocator, score) catch unreachable;
            defer self.allocator.free(val);

            scores.put(&key, val) catch @panic("Failed to add score");
        }

        txn.commit() catch @panic("Failed to add score");
    }
};

pub const Setup = struct {
    level: u8 = 0,
};

pub const Patch = enum {
    None,
    Frame,
    Nameplate,
    Label,
    Input,
    InputEdit,
    Keyrest,
    Keyup,
    Keydown,

    pub const transitions = [_]Observer.Transition{
        Observer.Transition{ .begin = @enumToInt(Patch.Keyrest), .event = .enter, .end = @enumToInt(Patch.Keyup) },
        Observer.Transition{ .begin = @enumToInt(Patch.Keyup), .event = .exit, .end = @enumToInt(Patch.Keyrest) },
        Observer.Transition{ .begin = @enumToInt(Patch.Keyup), .event = .press, .end = @enumToInt(Patch.Keydown) },
        Observer.Transition{ .begin = @enumToInt(Patch.Keydown), .event = .exit, .end = @enumToInt(Patch.Keyrest) },
        Observer.Transition{ .begin = @enumToInt(Patch.Keydown), .event = .release, .end = @enumToInt(Patch.Keyup), .emit = 1 },
        Observer.Transition{ .begin = @enumToInt(Patch.Input), .event = .press, .end = @enumToInt(Patch.InputEdit), .emit = 2 },
        Observer.Transition{ .begin = @enumToInt(Patch.InputEdit), .event = .onblur, .end = @enumToInt(Patch.Input), .emit = 3 },
    };

    pub fn asInt(style: Patch) u16 {
        return @enumToInt(style);
    }

    pub fn frame(style: Patch) seizer.ui.Node {
        return seizer.ui.Node{ .style = @enumToInt(style) };
    }

    pub fn addStyles(stage: *seizer.ui.Stage, texture: Texture) !void {
        try stage.painter.addStyle(@enumToInt(Patch.Frame), NinePatch.initv(texture, .{ 0, 0, 48, 48 }, .{ 16, 16 }), geom.Rect{ 16, 16, 16, 16 });
        try stage.painter.addStyle(@enumToInt(Patch.Nameplate), NinePatch.initv(texture, .{ 48, 0, 48, 48 }, .{ 16, 16 }), geom.Rect{ 16, 16, 16, 16 });
        try stage.painter.addStyle(@enumToInt(Patch.Label), NinePatch.initv(texture, .{ 96, 24, 12, 12 }, .{ 4, 4 }), geom.Rect{ 4, 4, 4, 4 });
        try stage.painter.addStyle(@enumToInt(Patch.Input), NinePatch.initv(texture, .{ 96, 24, 12, 12 }, .{ 4, 4 }), geom.Rect{ 4, 4, 4, 4 });
        try stage.painter.addStyle(@enumToInt(Patch.InputEdit), NinePatch.initv(texture, .{ 96, 24, 12, 12 }, .{ 4, 4 }), geom.Rect{ 4, 4, 4, 4 });
        try stage.painter.addStyle(@enumToInt(Patch.Keyrest), NinePatch.initv(texture, .{ 96, 0, 24, 24 }, .{ 8, 8 }), geom.Rect{ 8, 7, 8, 9 });
        try stage.painter.addStyle(@enumToInt(Patch.Keyup), NinePatch.initv(texture, .{ 120, 24, 24, 24 }, .{ 8, 8 }), geom.Rect{ 8, 8, 8, 8 });
        try stage.painter.addStyle(@enumToInt(Patch.Keydown), NinePatch.initv(texture, .{ 120, 0, 24, 24 }, .{ 8, 8 }), geom.Rect{ 8, 9, 8, 7 });
    }
};
