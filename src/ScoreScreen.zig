const std = @import("std");
const Screen = @import("context.zig").Screen;
const Context = @import("context.zig").Context;
const Patch = @import("context.zig").Patch;
const seizer = @import("seizer");
const gl = seizer.gl;
const Vec2f = seizer.math.Vec(2, f32);
const vec2f = Vec2f.init;
const ScoreEntry = @import("./score.zig").ScoreEntry;
const Decoder = @import("proto_structs").Decoder;
const chrono = @import("chrono");

ctx: *Context,
stage: seizer.ui.Stage,
scores_list: std.ArrayList(ScoreEntry),
scores_done_loading: bool = false,
scores_done_displaying: bool = false,
score_container: usize = 0,
score_list: usize = 0,
page_start: usize = 0,
page_size: usize = 10,
page: seizer.ui.store.Ref,
page_total: seizer.ui.store.Ref,
btn_back: usize = 0,
btn_prev: usize = 0,
btn_next: usize = 0,

pub fn init(ctx: *Context) !@This() {
    var this = @This(){
        .ctx = ctx,
        .scores_list = std.ArrayList(ScoreEntry).init(ctx.allocator),
        .stage = try seizer.ui.Stage.init(ctx.allocator, &ctx.font, &ctx.flat, &Patch.transitions),
        .page = undefined,
        .page_total = undefined,
    };
    this.stage.painter.scale = 2;
    try Patch.addStyles(&this.stage, this.ctx.ui_tex);

    const namelbl = try this.stage.store.new(.{ .Bytes = "Scores" });
    const backlbl = try this.stage.store.new(.{ .Bytes = "Back" });
    const prevlbl = try this.stage.store.new(.{ .Bytes = "Prev." });
    const nextlbl = try this.stage.store.new(.{ .Bytes = "Next" });
    const loadlbl = try this.stage.store.new(.{ .Bytes = "Loading..." });
    this.page = try this.stage.store.new(.{ .Int = 0 });
    const divider = try this.stage.store.new(.{ .Bytes = "/" });
    this.page_total = try this.stage.store.new(.{ .Int = 0 });

    const center = try this.stage.layout.insert(null, Patch.frame(.None).container(.Center));
    const frame = try this.stage.layout.insert(center, Patch.frame(.Frame).container(.VList));
    const center_name = try this.stage.layout.insert(frame, Patch.frame(.None).container(.Center));
    _ = try this.stage.layout.insert(center_name, Patch.frame(.Nameplate).dataValue(namelbl));
    // Buttons "Toolbar"
    const hlist = try this.stage.layout.insert(frame, Patch.frame(.None).container(.HDiv));
    this.btn_back = try this.stage.layout.insert(hlist, Patch.frame(.Keyrest).dataValue(backlbl));
    this.btn_prev = try this.stage.layout.insert(hlist, Patch.frame(.Keyrest).dataValue(prevlbl));
    const page_center = try this.stage.layout.insert(hlist, Patch.frame(.None).container(.Center));
    const page_container = try this.stage.layout.insert(page_center, Patch.frame(.Label).container(.HList));
    _ = try this.stage.layout.insert(page_container, Patch.frame(.None).dataValue(this.page));
    _ = try this.stage.layout.insert(page_container, Patch.frame(.None).dataValue(divider));
    _ = try this.stage.layout.insert(page_container, Patch.frame(.None).dataValue(this.page_total));
    this.btn_next = try this.stage.layout.insert(hlist, Patch.frame(.Keyrest).dataValue(nextlbl));

    this.score_container = try this.stage.layout.insert(frame, Patch.frame(.None).container(.Center));
    this.score_list = try this.stage.layout.insert(this.score_container, Patch.frame(.Label).dataValue(loadlbl));

    this.stage.sizeAll();

    try seizer.execute(ctx.allocator, load_scores, .{&this});

    return this;
}

pub fn deinit(this: *@This()) void {
    this.stage.deinit();
    this.scores_list.deinit();
}

pub fn display_scores(this: *@This(), begin: usize, end: usize) !void {
    this.stage.layout.remove(this.score_list);
    this.score_list = try this.stage.layout.insert(this.score_container, Patch .frame(.None) .container(.VList));
    {
        var buf: [50]u8 = undefined;
        const text = try std.fmt.bufPrint(&buf, "{s:<12}|{s:^5}|{s:^8}|{s:^3}|{s:^4}", .{ "Date", "Time", "Score", "Lvl", "Rows" });
        const ref = try this.stage.store.new(.{ .Bytes = text });
        _ = try this.stage.layout.insert(this.score_list, Patch.frame(.Label).dataValue(ref));
    }
    const min_size = @Vector(2, i32){ 0, @floatToInt(i32, this.ctx.font.lineHeight * this.stage.painter.scale) * @intCast(i32, this.page_size) };
    const list_box = try this.stage.layout.insert(this.score_list, Patch.frame(.Label).container(.VList).minSize(min_size));
    var i = begin;
    while (i < end) : (i += 1) {
        const entry = this.scores_list.items[i];
        var buf: [50]u8 = undefined;
        var buf_date: [12]u8 = undefined;
        var buf_time: [5]u8 = undefined;
        var buf_score: [10]u8 = undefined;
        var buf_level: [10]u8 = undefined;
        var buf_rows: [10]u8 = undefined;
        const date = date: {
            const naivedt = chrono.datetime.NaiveDateTime.from_timestamp(entry.timestamp, 0) catch @panic("chrono");
            const dt = chrono.datetime.DateTime.utc(naivedt, this.ctx.timezone);
            const naive_dt = dt.toNaiveDateTime() catch @panic("chrono2: electric boogaloo");
            const dt_fmt = naive_dt.formatted("%Y-%m-%d");
            break :date try std.fmt.bufPrint(&buf_date, "{}", .{dt_fmt});
        };
        const time = time: {
            const minutes = @floor(entry.playTime / std.time.s_per_min);
            const seconds = @floor(entry.playTime - minutes * std.time.s_per_min);
            break :time try std.fmt.bufPrint(&buf_time, "{d}:{d:0>2}", .{ minutes, seconds });
        };
        const score = try std.fmt.bufPrint(&buf_score, "{}", .{@intCast(i32, @truncate(u32, entry.score))});
        const level = try std.fmt.bufPrint(&buf_level, "{}", .{entry.startingLevel});
        const rows = try std.fmt.bufPrint(&buf_rows, "{}", .{entry.rowsCleared});
        const text = try std.fmt.bufPrint(&buf, "{s:<12}|{s:>5}|{s:>8}|{s:>3}|{s:>4}", .{ date, time, score, level, rows });
        const ref = try this.stage.store.new(.{ .Bytes = text });
        _ = try this.stage.layout.insert(list_box, Patch.frame(.None).dataValue(ref));
    }

    this.stage.sizeAll();
}

pub fn update(this: *@This(), current_time: f64, delta: f64) !void {
    _ = current_time;
    _ = delta;
    if (this.scores_done_loading and !this.scores_done_displaying) {
        var page = this.stage.store.get(this.page);
        page.Int = 1;
        try this.stage.store.set(.Int, this.page, page.Int);

        var page_total = this.stage.store.get(this.page_total);
        const over: usize = if (this.scores_list.items.len % this.page_size > 0) 1 else 0;
        page_total.Int = @intCast(i32, @divTrunc(this.scores_list.items.len, this.page_size) + over);
        try this.stage.store.set(.Int, this.page_total, page_total.Int);

        const amount = std.math.min(this.page_size, this.scores_list.items.len);
        try this.display_scores(0, amount);
        this.scores_done_displaying = true;
    }
}

pub fn event(this: *@This(), evt: seizer.event.Event) !void {
    if (this.stage.event(evt)) |action| {
        if (action.emit == 1) {
            if (action.node) |node| {
                if (node.handle == this.btn_back) {
                    return this.ctx.scene.pop();
                } else if (node.handle == this.btn_prev) {
                    if (this.scores_done_loading) {
                        this.page_start -|= this.page_size;
                        const amount = std.math.min(this.page_start + this.page_size, this.scores_list.items.len);
                        try this.display_scores(this.page_start, amount);
                        var page = this.stage.store.get(this.page);
                        page.Int -= 1;
                        if (page.Int == 0) page.Int = 1;
                        try this.stage.store.set(.Int, this.page, page.Int);
                    }
                } else if (node.handle == this.btn_next) {
                    if (this.scores_done_loading and this.page_start + this.page_size < this.scores_list.items.len) {
                        this.page_start += this.page_size;
                        const amount = std.math.min(this.page_start + this.page_size, this.scores_list.items.len);
                        try this.display_scores(this.page_start, amount);
                        var page = this.stage.store.get(this.page);
                        page.Int += 1;
                        try this.stage.store.set(.Int, this.page, page.Int);
                    }
                }
            }
        }
    }
    switch (evt) {
        .KeyDown => |e| switch (e.scancode) {
            .X, .ESCAPE => return this.ctx.scene.pop(),
            else => {},
        },
        .ControllerButtonDown => |cbutton| switch (cbutton.button) {
            .START, .B => return this.ctx.scene.pop(),
            else => {},
        },
        else => {},
    }
}

pub fn render(this: *@This(), _: f64) !void {
    const screen_size = seizer.getScreenSize();

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.viewport(0, 0, screen_size.x, screen_size.y);

    this.ctx.flat.setSize(screen_size);

    this.stage.paintAll(.{ 0, 0, screen_size.x, screen_size.y });

    this.ctx.flat.flush();
}

fn load_scores(this: *@This()) void {
    var txn = this.ctx.db.begin(&.{"scores"}, .{ .readonly = true }) catch unreachable;
    defer txn.deinit();

    var store = txn.store("scores") catch unreachable;
    defer store.release();

    var cursor = store.cursor(.{}) catch unreachable;
    defer cursor.deinit();

    var arena = std.heap.ArenaAllocator.init(this.ctx.allocator);
    defer arena.deinit();

    while (cursor.next() catch unreachable) |entry| {
        const score_decoder = Decoder(ScoreEntry).fromBytes(entry.val) catch continue;
        const score = score_decoder.decode(arena.allocator()) catch continue;

        this.scores_list.append(score) catch unreachable;
    }

    std.mem.reverse(ScoreEntry, this.scores_list.items);

    this.scores_done_loading = true;
}
