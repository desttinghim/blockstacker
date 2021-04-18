/// Score given for number of lines cleared.
/// 1 = 40
/// 2 = 100
/// 3 = 300
/// 4 = 1200
const scoring_table: [5]usize = .{ 0, 40, 100, 300, 1200 };

pub fn get_score(lines: usize, level: usize) usize {
    return scoring_table[lines] * (level + 1);
}
