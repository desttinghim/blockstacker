const std = @import("std");
const builtin = @import("builtin");
const blockstacker = @import("./main.zig");

/// Score given for number of lines cleared.
/// 1 = 40
/// 2 = 100
/// 3 = 300
/// 4 = 1200
const scoring_table: [5]usize = .{ 0, 40, 100, 300, 1200 };

pub fn get_score(lines: usize, level: usize) usize {
    return scoring_table[lines] * (level + 1);
}

/// At 60 FPS, how many frames to wait before dropping the tetromino down another row at each level.
/// Table pulled from https://harddrop.com/wiki/Tetris_(Game_Boy)
// 0 	53
// 1 	49
// 2 	45
// 3 	41
// 4 	37
// 5 	33
// 6 	28
// 7 	22
// 8 	17
// 9 	11
// 10 	10
// 11 	9
// 12 	8
// 13 	7
// 14 	6
// 15 	6
// 16 	5
// 17 	5
// 18 	4
// 19 	4
// 20 	3
const level_table: [10]usize = .{ 53, 49, 45, 41, 37, 33, 28, 22, 17, 11 };

pub fn get_drop_delta(level: usize) f32 {
    return 1.0 / (60.0 / @intToFloat(f32, level_table[level]));
}

pub fn get_soft_drop_delta() f32 {
    return 1.0 / (60.0 / 3.0);
}

pub const ScoreEntry = packed struct {
    timestamp: i64,
    score: u64,
    startingLevel: u8,
    playTime: u64,
    rowsCleared: u32,
    level: u8,
    singles: u32,
    doubles: u32,
    triples: u32,
    tetrises: u32,

    pub fn lessThan(ctx: void, lhs: @This(), rhs: @This()) bool {
        _ = ctx;
        return lhs.score < rhs.score;
    }
};

const MAGIC_BYTES = "BLKSTK00";

const Header = struct {
    magic: [8]u8 = MAGIC_BYTES.*,
    scores_len: u32,

    pub fn endianLittleToNative(this: @This()) @This() {
        return @This(){
            .magic = this.magic,
            .scores_len = std.mem.littleToNative(u32, this.scores_len),
        };
    }

    pub fn endianNativeToLittle(this: @This()) @This() {
        return @This(){
            .magic = this.magic,
            .scores_len = std.mem.nativeToLittle(u32, this.scores_len),
        };
    }
};

const HEADER_END = @sizeOf(Header);

pub fn Read(comptime StoreImpl: type) type {
    const Storage = blockstacker.storage.Storage(StoreImpl);

    return struct {
        allocator: std.mem.Allocator,
        storage: Storage,
        header: *Header,

        state: State,

        scores: std.ArrayListUnmanaged(ScoreEntry),

        const State = union(enum) {
            reading_header: Storage.ReadHandle,
            reading_scores: Storage.ReadHandle,
            done,
            failed: anyerror,
        };

        pub fn init(allocator: std.mem.Allocator, storage: Storage) !@This() {
            const header = try allocator.create(Header);

            var this = @This(){
                .allocator = allocator,
                .storage = storage,
                .header = header,
                .scores = .{},
                .state = undefined,
            };

            const header_read = storage.read(0, std.mem.asBytes(this.header)) catch |e| {
                this.state = .{ .failed = e };
                return this;
            };

            this.state = .{ .reading_header = header_read };

            return this;
        }

        pub fn deinit(this: *@This()) void {
            switch (this.state) {
                .reading_header => |header_read| this.storage.freeRead(header_read),
                .reading_scores => |scores_read| this.storage.freeRead(scores_read),
                .done, .failed => {},
            }
            this.scores.deinit(this.allocator);
            this.allocator.destroy(this.header);
        }

        pub fn update(this: *@This()) !void {
            while (true) {
                switch (this.state) {
                    .reading_header => |header_read| if (try this.storage.readIsComplete(header_read)) |header_bytes_read| {
                        this.header.* = this.header.endianLittleToNative();

                        if (header_bytes_read < @sizeOf(Header) or !std.mem.eql(u8, &this.header.magic, MAGIC_BYTES)) {
                            this.state = .done;
                            return;
                        }

                        try this.scores.ensureTotalCapacity(this.allocator, this.header.scores_len);

                        const scores_read = try this.storage.read(HEADER_END, std.mem.sliceAsBytes(this.scores.items.ptr[0..this.header.scores_len]));
                        this.state = .{ .reading_scores = scores_read };
                    } else {
                        break;
                    },

                    .reading_scores => |scores_read| if (try this.storage.readIsComplete(scores_read)) |scores_bytes_read| {
                        if (scores_bytes_read != this.header.scores_len * @sizeOf(ScoreEntry)) {
                            this.state = .{ .failed = error.UnexpectedEOF };
                            break;
                        }

                        if (builtin.target.cpu.arch.endian() == .Big) {
                            for (this.scores.items.ptr[0..this.header.scores_len]) |*score| {
                                std.mem.byteSwapAllFields(ScoreEntry, score);
                            }
                        }

                        // Put scores in reverse order, most recent score first
                        std.mem.reverse(ScoreEntry, this.scores.items.ptr[0..this.header.scores_len]);

                        this.scores.items.len = this.header.scores_len;
                        this.state = .done;
                    } else {
                        break;
                    },

                    .done, .failed => break,
                }
            }
        }
    };
}

pub fn Write(comptime StoreImpl: type) type {
    const Storage = blockstacker.storage.Storage(StoreImpl);

    return struct {
        allocator: std.mem.Allocator,
        storage: Storage,
        state: State,

        scores_to_append: []ScoreEntry,
        // Two headers, first for reading, second for writing
        headers: *[2]Header,

        const State = union(enum) {
            reading_header: Storage.ReadHandle,
            appending_scores: Storage.WriteHandle,
            writing_header: Storage.WriteHandle,
            done,
            failed: anyerror,
        };

        pub fn init(allocator: std.mem.Allocator, storage: Storage, scores_to_append: []const ScoreEntry) !@This() {
            const headers = try allocator.create([2]Header);
            errdefer allocator.destroy(headers);

            const scores = try allocator.dupe(ScoreEntry, scores_to_append);
            errdefer allocator.free(scores);

            if (builtin.target.cpu.arch.endian() == .Big) {
                for (scores) |*score| {
                    std.mem.byteSwapAllFields(ScoreEntry, score);
                }
            }

            var this = @This(){
                .allocator = allocator,
                .storage = storage,
                .headers = headers,
                .scores_to_append = scores,
                .state = undefined,
            };

            const header_read = storage.read(0, std.mem.asBytes(&this.headers[0])) catch |e| {
                this.state = .{ .failed = e };
                return this;
            };

            this.state = .{ .reading_header = header_read };

            return this;
        }

        pub fn deinit(this: @This()) void {
            switch (this.state) {
                .reading_header => |header_read| this.storage.freeRead(header_read),
                .appending_scores => |score_write| this.storage.freeWrite(score_write),
                .writing_header => |header_write| this.storage.freeWrite(header_write),
                .done, .failed => {},
            }
            this.allocator.free(this.scores_to_append);
            this.allocator.destroy(this.headers);
        }

        pub fn update(this: *@This()) !void {
            while (true) {
                switch (this.state) {
                    .reading_header => |header_read| if (try this.storage.readIsComplete(header_read)) |header_bytes_read| {
                        this.headers[0] = this.headers[0].endianLittleToNative();

                        if (header_bytes_read < @sizeOf(Header) or !std.mem.eql(u8, &this.headers[0].magic, MAGIC_BYTES)) {
                            this.headers[0] = .{ .scores_len = 0 };
                        }
                        const end_of_list = HEADER_END + this.headers[0].scores_len * @sizeOf(ScoreEntry);

                        const scores_append = try this.storage.write(end_of_list, std.mem.sliceAsBytes(this.scores_to_append));

                        this.state = .{ .appending_scores = scores_append };
                    } else {
                        break;
                    },

                    .appending_scores => |scores_appended| if (try this.storage.readIsComplete(scores_appended)) |scores_bytes_written| {
                        if (scores_bytes_written != std.mem.sliceAsBytes(this.scores_to_append).len) {
                            this.state = .{ .failed = error.UnexpectedEOF };
                            break;
                        }

                        this.headers[1] = this.headers[0];
                        this.headers[1].scores_len += @intCast(u32, this.scores_to_append.len);
                        this.headers[1] = this.headers[1].endianNativeToLittle();

                        const header_write = try this.storage.write(0, std.mem.asBytes(&this.headers[1]));

                        this.state = .{ .writing_header = header_write };
                    } else {
                        break;
                    },

                    .writing_header => |header_write| if (try this.storage.readIsComplete(header_write)) |header_bytes_written| {
                        if (header_bytes_written != std.mem.asBytes(&this.headers[1]).len) {
                            this.state = .{ .failed = error.UnexpectedEOF };
                            break;
                        }

                        this.state = .done;
                    } else {
                        break;
                    },

                    .done, .failed => break,
                }
            }
        }
    };
}
