const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;

pub const PauseScreen: Screen = .{
    .init = init,
    .event = event,
    .render = render,
};

var selection: usize = undefined;
const SELECTIONS = [_]Selection{
    .{ .label = "Resume", .action = action_resume },
    .{ .label = "Main Menu", .action = action_main_menu },
    .{ .label = "Quit", .action = action_quit },
};

fn init(ctx: *Context) void {
    selection = 0;
}

fn action_resume(ctx: *Context) void {
    ctx.pop_screen();
}

fn action_main_menu(ctx: *Context) void {
    //ctx.switch_screen() catch @panic("Switching screen somehow caused allocation");
}

fn action_quit(_ctx: *Context) void {
    seizer.quit();
}

fn event(ctx: *Context, evt: seizer.event.Event) void {
    var up = false;
    var down = false;
    var select = false;
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .Z, .RETURN => select = true,
            .W, .UP => up = true,
            .S, .DOWN => down = true,

            .ESCAPE => ctx.pop_screen(),
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .A => select = true,
            .DPAD_DOWN => down = true,
            .DPAD_UP => up = true,

            .START, .B => ctx.pop_screen(),
            else => {},
        },
        .Quit => seizer.quit(),
        else => {},
    }

    if (down) {
        selection += 1;
        selection %= SELECTIONS.len;
    }
    if (up) {
        var new_selection: usize = 0;
        if (@subWithOverflow(usize, selection, 1, &new_selection)) {
            selection = SELECTIONS.len - 1;
        } else {
            selection = new_selection;
        }
    }
    if (select) {
        SELECTIONS[selection].action(ctx);
    }
}

fn render(ctx: *Context, alpha: f64) void {
    const screen_size_f = seizer.getScreenSize().intToFloat(f32);
    
    const selection_scale = 2;

    var menu_width: f32 = 0;
    for (SELECTIONS) |sel| {
        const width = ctx.font.calcTextWidth(sel.label, selection_scale);
        menu_width = std.math.max(menu_width, width);
    }

    const selection_height = ctx.font.lineHeight * selection_scale;
    const menu_height = selection_height * @intToFloat(f32, SELECTIONS.len);

    const start_pos = screen_size_f.sub(menu_width, menu_height).scaleDiv(2);
    for (SELECTIONS) |sel, idx| {
        const pos = start_pos.add(0, @intToFloat(f32, idx) * selection_height);

        ctx.font.drawText(&ctx.flat, sel.label, pos, .{ .scale = selection_scale, .textBaseline = .Top });
        if (selection == idx) {
            ctx.font.drawText(&ctx.flat, ">", pos, .{ .textAlign = .Right, .scale = selection_scale, .textBaseline = .Top });
        }
    }
    
    ctx.flat.flush();
}

const Selection = struct {
    label: []const u8,
    action: fn (*Context) void,
};
