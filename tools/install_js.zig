const std = @import("std");
const seizer = @import("seizer");
const crossdb = @import("crossdb");
const chrono = @import("chrono");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(&gpa.allocator);
    defer std.process.argsFree(&gpa.allocator, args);

    const cwd = std.fs.cwd();
    const dir = try cwd.makeOpenPath(args[1], .{});

    try seizer.generateWebFiles(dir, .{});
    try crossdb.installJS(dir);
    try chrono.installJS(dir);
}
