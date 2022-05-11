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

pub const Setup = struct {
    level: u8 = 0,
};

pub const Context = struct {
    flat: SpriteBatch,
    font: BitmapFont,
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
