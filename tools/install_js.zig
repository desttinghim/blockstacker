const std = @import("std");
const seizer = @import("seizer");
const crossdb = @import("crossdb");
const chrono = @import("chrono");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cwd = std.fs.cwd();
    const dir = try cwd.makeOpenPath(args[1], .{});

    try seizer.generateWebFiles(dir, .{});
    try crossdb.installJS(dir);
    try chrono.installJS(dir);
}
