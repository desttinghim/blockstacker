element: seizer.ui.Element,
root: *seizer.ui.Element,

level: u32 = 0,
level_label: *seizer.ui.Label,

on_start_game: ?seizer.ui.Callable(fn (level: u32) void) = null,
on_back: ?seizer.ui.Callable(fn (void) void) = null,

const INTERFACE = seizer.ui.Element.Interface{
    .destroy_fn = destroy,
    .get_min_size_fn = getMinSize,
    .layout_fn = layout,
    .render_fn = render,
    .on_hover_fn = onHover,
    .on_click_fn = onClick,
};

pub fn new(stage: *seizer.ui.Stage, options: struct {
    frame_style: seizer.ui.Style,
    label_style: seizer.ui.Style,
    button_default_style: seizer.ui.Style,
    button_hovered_style: seizer.ui.Style,
    button_clicked_style: seizer.ui.Style,
}) !*@This() {
    const this = try stage.gpa.create(@This());
    errdefer stage.gpa.destroy(this);

    const root = try seizer.ui.FlexBox.new(stage);
    defer root.element.release();
    root.justification = .center;
    root.cross_align = .center;

    const frame = try seizer.ui.Frame.new(stage);
    defer frame.element.release();
    frame.style = options.frame_style;
    try root.appendChild(&frame.element);

    const flexbox = try seizer.ui.FlexBox.new(stage);
    defer flexbox.element.release();
    flexbox.justification = .center;
    flexbox.cross_align = .center;
    flexbox.direction = .column;
    frame.setChild(&flexbox.element);

    // +------------+
    // | Start Game |
    // +------------+
    const start_game_button = try seizer.ui.Button.new(stage, "Start Game");
    defer start_game_button.element.release();
    start_game_button.on_click = .{ .userdata = this, .callback = triggerStartGame };
    start_game_button.default_style = options.button_default_style;
    start_game_button.hovered_style = options.button_hovered_style;
    start_game_button.clicked_style = options.button_clicked_style;
    try flexbox.appendChild(&start_game_button.element);

    // +---+ +----+ +---+
    // | < | | 00 | | > |
    // +---+ +----+ +---+
    const level_flexbox = try seizer.ui.FlexBox.new(stage);
    defer level_flexbox.element.release();
    level_flexbox.justification = .center;
    level_flexbox.cross_align = .center;
    level_flexbox.direction = .row;
    try flexbox.appendChild(&level_flexbox.element);

    const decrement_button = try seizer.ui.Button.new(stage, "<");
    defer decrement_button.element.release();
    decrement_button.on_click = .{ .userdata = this, .callback = decrementLevel };
    decrement_button.default_style = options.button_default_style;
    decrement_button.hovered_style = options.button_hovered_style;
    decrement_button.clicked_style = options.button_clicked_style;
    try level_flexbox.appendChild(&decrement_button.element);

    const level_text = try stage.gpa.dupe(u8, "Level: 0");
    const level_label = try seizer.ui.Label.new(stage, level_text);
    defer level_label.element.release();
    level_label.style = options.label_style;
    try level_flexbox.appendChild(&level_label.element);

    const increment_button = try seizer.ui.Button.new(stage, ">");
    defer increment_button.element.release();
    increment_button.on_click = .{ .userdata = this, .callback = incrementLevel };
    increment_button.default_style = options.button_default_style;
    increment_button.hovered_style = options.button_hovered_style;
    increment_button.clicked_style = options.button_clicked_style;
    try level_flexbox.appendChild(&increment_button.element);

    // +------+
    // | Back |
    // +------+
    const back_button = try seizer.ui.Button.new(stage, "Back");
    defer back_button.element.release();
    back_button.on_click = .{ .userdata = this, .callback = triggerBack };
    back_button.default_style = options.button_default_style;
    back_button.hovered_style = options.button_hovered_style;
    back_button.clicked_style = options.button_clicked_style;
    try flexbox.appendChild(&back_button.element);

    root.element.acquire();
    level_label.element.acquire();
    this.* = .{
        .element = .{
            .stage = stage,
            .interface = &INTERFACE,
        },
        .root = &root.element,
        .level_label = level_label,
    };

    return this;
}

pub fn destroy(element: *seizer.ui.Element) void {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);
    this.root.release();
    this.element.stage.gpa.destroy(this);
}

pub fn getMinSize(element: *seizer.ui.Element) [2]f32 {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);

    return this.root.getMinSize();
}

pub fn layout(element: *seizer.ui.Element, min_size: [2]f32, max_size: [2]f32) [2]f32 {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);
    this.root.rect.pos = .{ 0, 0 };
    this.root.rect.size = this.root.layout(min_size, max_size);
    return this.root.rect.size;
}

fn render(element: *seizer.ui.Element, canvas: *seizer.Canvas, rect: seizer.geometry.Rect(f32)) void {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);

    return this.root.render(canvas, rect);
}

fn onHover(element: *seizer.ui.Element, pos_parent: [2]f32) ?*seizer.ui.Element {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);
    const pos = .{
        pos_parent[0] - this.element.rect.pos[0],
        pos_parent[1] - this.element.rect.pos[1],
    };

    if (this.root.rect.contains(pos)) {
        if (this.root.onHover(pos)) |hovered| {
            return hovered;
        }
    }

    return null;
}

fn onClick(element: *seizer.ui.Element, event_parent: seizer.ui.event.Click) bool {
    const this: *@This() = @fieldParentPtr(@This(), "element", element);

    const event = event_parent.translate(.{ -this.element.rect.pos[0], -this.element.rect.pos[1] });

    if (this.root.rect.contains(event.pos)) {
        if (this.root.onClick(event)) {
            return true;
        }
    }

    return false;
}

fn triggerStartGame(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
    const this: *@This() = @ptrCast(@alignCast(userdata.?));
    _ = button;

    if (this.on_start_game) |start_game| {
        start_game.call(.{this.level});
    }
}

fn decrementLevel(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
    const this: *@This() = @ptrCast(@alignCast(userdata.?));
    _ = button;

    if (this.level == 0) {
        this.level = 10;
    }
    this.level -= 1;
    this.updateLevelLabel();
}

fn incrementLevel(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
    const this: *@This() = @ptrCast(@alignCast(userdata.?));
    _ = button;

    this.level +|= 1;
    this.level %= 10;
    this.updateLevelLabel();
}

fn updateLevelLabel(this: *@This()) void {
    const old_text = this.level_label.text;
    const new_text = std.fmt.allocPrint(this.element.stage.gpa, "Level: {}", .{this.level}) catch return;

    this.level_label.text = new_text;
    this.element.stage.gpa.free(old_text);
}

fn triggerBack(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
    const this: *@This() = @ptrCast(@alignCast(userdata.?));
    _ = button;

    if (this.on_back) |back| {
        back.call(.{{}});
    }
}

const std = @import("std");
const seizer = @import("seizer");
