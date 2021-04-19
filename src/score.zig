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

pub const ScoreEntry = struct {
    name: []const u8,
    score: usize,
};
