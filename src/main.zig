const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;

pub fn main() void {
    seizer.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .render = render,
        .update = update,
        .window = .{
            .title = "Blockstacker",
        },
    });
}

// Global variables

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = (std.builtin.os.tag != .freestanding) }){};
const allocator = &gpa.allocator;

pub fn onInit() !void {}

pub fn onDeinit() void {}

pub fn onEvent(event: seizer.event.Event) !void {
    switch (event) {
        .Quit => seizer.quit(),
        else => {},
    }
}

pub fn render(alpha: f64) !void {
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn update(currentTime: f64, delta: f64) anyerror!void {}
