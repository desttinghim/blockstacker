const App = struct {
    gpa: std.mem.Allocator,
    prng: std.rand.DefaultPrng,

    window: *seizer.backend.glfw.c.GLFWwindow,
    canvas: seizer.Canvas,
    blocks_tileset: seizer.Texture,
    ui_tileset: seizer.Texture,
    tilemap: util.Tilemap,
    stage: *seizer.ui.Stage,

    main_menu: *seizer.ui.Element,
    setup_screen: *@import("./SetupScreen.zig"),

    pub fn new(gpa: std.mem.Allocator) !*App {
        var app = try gpa.create(App);
        errdefer gpa.destroy(app);

        var seed: u64 = undefined;
        std.crypto.random.bytes(std.mem.asBytes(&seed));
        var prng = std.rand.DefaultPrng.init(seed);

        seizer.backend.glfw.c.glfwWindowHint(seizer.backend.glfw.c.GLFW_OPENGL_DEBUG_CONTEXT, seizer.backend.glfw.c.GLFW_TRUE);
        seizer.backend.glfw.c.glfwWindowHint(seizer.backend.glfw.c.GLFW_CLIENT_API, seizer.backend.glfw.c.GLFW_OPENGL_ES_API);
        seizer.backend.glfw.c.glfwWindowHint(seizer.backend.glfw.c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        seizer.backend.glfw.c.glfwWindowHint(seizer.backend.glfw.c.GLFW_CONTEXT_VERSION_MINOR, 0);

        //  Open window
        const window = seizer.backend.glfw.c.glfwCreateWindow(320, 240, "UI - Seizer", null, null) orelse return error.GlfwCreateWindow;
        errdefer seizer.backend.glfw.c.glfwDestroyWindow(window);

        seizer.backend.glfw.c.glfwMakeContextCurrent(window);

        gl_binding.init(seizer.backend.glfw.GlBindingLoader);
        gl.makeBindingCurrent(&gl_binding);

        // set up canvas for rendering
        var canvas = try seizer.Canvas.init(gpa, .{});
        errdefer canvas.deinit(gpa);

        // texture containing ui elements
        var blocks_tileset = try seizer.Texture.initFromMemory(gpa, @embedFile("assets/blocks.png"), .{});
        errdefer blocks_tileset.deinit();

        var ui_tileset = try seizer.Texture.initFromMemory(gpa, @embedFile("assets/ui.png"), .{});
        errdefer ui_tileset.deinit();

        var tilemap = try util.Tilemap.fromMemory(gpa, @embedFile("assets/blocks.json"));
        errdefer tilemap.deinit(gpa);

        // NinePatches from the above texture
        const ninepatch_frame = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 0, 0 }, .size = .{ 48, 48 } }, .{ 16, 16 }); //, geom.Rect{ 16, 16, 16, 16 });
        const ninepatch_nameplate = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 48, 0 }, .size = .{ 48, 48 } }, .{ 16, 16 }); //, geom.Rect{ 16, 16, 16, 16 });
        const ninepatch_label = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 96, 24 }, .size = .{ 12, 12 } }, .{ 4, 4 }); //, geom.Rect{ 4, 4, 4, 4 });
        // const ninepatch_input = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 96, 24 }, .size = .{ 12, 12 } }, .{ 4, 4 }); //, geom.Rect{ 4, 4, 4, 4 });
        // const ninepatch_inputEdit = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 96, 24 }, .size = .{ 12, 12 } }, .{ 4, 4 }); //, geom.Rect{ 4, 4, 4, 4 });
        const ninepatch_keyrest = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 96, 0 }, .size = .{ 24, 24 } }, .{ 8, 8 }); //, geom.Rect{ 8, 7, 8, 9 });
        const ninepatch_keyup = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 120, 24 }, .size = .{ 24, 24 } }, .{ 8, 8 }); //, geom.Rect{ 8, 8, 8, 8 });
        const ninepatch_keydown = seizer.NinePatch.initv(ui_tileset, .{ .pos = .{ 120, 0 }, .size = .{ 24, 24 } }, .{ 8, 8 }); //, geom.Rect{ 8, 9, 8, 7 });

        const stage = try seizer.ui.Stage.init(gpa, seizer.ui.Style{
            .padding = .{ .min = .{ 0, 0 }, .max = .{ 0, 0 } },
            .text_font = &app.canvas.font,
            .text_scale = 2,
            .text_color = [4]u8{ 0, 0, 0, 0xFF },
            .background_image = seizer.NinePatch.initStretched(.{ .glTexture = canvas.blank_texture, .size = .{ 1, 1 } }, .{ .pos = .{ 0, 0 }, .size = .{ 1, 1 } }),
            .background_color = [4]u8{ 0xFF, 0xFF, 0xFF, 0xFF },
        });
        errdefer stage.destroy();

        const frame_style = stage.default_style.with(.{
            .padding = .{ .min = .{ 16, 16 }, .max = .{ 16, 16 } },
            .background_image = ninepatch_frame,
        });
        const label_style = stage.default_style.with(.{
            .padding = .{ .min = .{ 4, 4 }, .max = .{ 4, 4 } },
            .background_image = ninepatch_label,
        });
        const button_default_style = stage.default_style.with(.{
            .padding = .{ .min = .{ 8, 9 }, .max = .{ 8, 7 } },
            .background_image = ninepatch_keyrest,
        });
        const button_hovered_style = stage.default_style.with(.{
            .padding = .{ .min = .{ 8, 8 }, .max = .{ 8, 8 } },
            .background_image = ninepatch_keyup,
        });
        const button_clicked_style = stage.default_style.with(.{
            .padding = .{ .min = .{ 8, 10 }, .max = .{ 8, 5 } },
            .background_image = ninepatch_keydown,
        });

        const centered = try seizer.ui.FlexBox.new(stage);
        defer centered.element.release();
        centered.justification = .center;
        centered.cross_align = .center;
        stage.setRoot(&centered.element);

        const frame = try seizer.ui.Frame.new(stage);
        defer frame.element.release();
        frame.style = frame_style;
        try centered.appendChild(&frame.element);

        const flexbox = try seizer.ui.FlexBox.new(stage);
        defer flexbox.element.release();
        flexbox.justification = .center;
        flexbox.cross_align = .center;
        flexbox.direction = .column;
        frame.setChild(&flexbox.element);

        // +---------------+
        // | Hello, world! |
        // +---------------+
        const nameplate = try seizer.ui.Label.new(stage, "BlockStacker");
        defer nameplate.element.release();
        nameplate.style = stage.default_style.with(.{
            .padding = .{ .min = .{ 16, 16 }, .max = .{ 16, 16 } },
            .background_image = ninepatch_nameplate,
        });
        try flexbox.appendChild(&nameplate.element);

        // +---+ +----+ +---+
        // | < | | 00 | | > |
        // +---+ +----+ +---+
        const start_game_button = try seizer.ui.Button.new(stage, "Start Game");
        defer start_game_button.element.release();
        start_game_button.on_click = .{ .userdata = app, .callback = onStartGamePressed };
        start_game_button.default_style = button_default_style;
        start_game_button.hovered_style = button_hovered_style;
        start_game_button.clicked_style = button_clicked_style;
        try flexbox.appendChild(&start_game_button.element);

        const scores_button = try seizer.ui.Button.new(stage, "Scores");
        defer scores_button.element.release();
        scores_button.on_click = .{ .userdata = app, .callback = onScoresPressed };
        scores_button.default_style = button_default_style;
        scores_button.hovered_style = button_hovered_style;
        scores_button.clicked_style = button_clicked_style;
        try flexbox.appendChild(&scores_button.element);

        const quit_button = try seizer.ui.Button.new(stage, "Quit");
        defer quit_button.element.release();
        quit_button.on_click = .{ .userdata = app, .callback = onQuitPressed };
        quit_button.default_style = button_default_style;
        quit_button.hovered_style = button_hovered_style;
        quit_button.clicked_style = button_clicked_style;
        try flexbox.appendChild(&quit_button.element);

        const setup_screen = try @import("./SetupScreen.zig").new(stage, .{
            .frame_style = frame_style,
            .label_style = label_style,
            .button_default_style = button_default_style,
            .button_hovered_style = button_hovered_style,
            .button_clicked_style = button_clicked_style,
        });
        defer setup_screen.element.release();
        setup_screen.on_back = .{ .userdata = app, .callback = gotoMainMenu };

        centered.element.acquire();
        setup_screen.element.acquire();
        app.* = .{
            .gpa = gpa,
            .prng = prng,

            .window = window,
            .blocks_tileset = blocks_tileset,
            .ui_tileset = ui_tileset,
            .tilemap = tilemap,
            .canvas = canvas,
            .stage = stage,

            .main_menu = &centered.element,
            .setup_screen = setup_screen,
        };

        // Set up input callbacks
        seizer.backend.glfw.c.glfwSetWindowUserPointer(window, app);

        _ = seizer.backend.glfw.c.glfwSetKeyCallback(window, &glfw_key_callback);
        _ = seizer.backend.glfw.c.glfwSetMouseButtonCallback(window, &glfw_mousebutton_callback);
        _ = seizer.backend.glfw.c.glfwSetCursorPosCallback(window, &glfw_cursor_pos_callback);
        _ = seizer.backend.glfw.c.glfwSetCharCallback(window, &glfw_char_callback);
        _ = seizer.backend.glfw.c.glfwSetScrollCallback(window, &glfw_scroll_callback);
        _ = seizer.backend.glfw.c.glfwSetWindowSizeCallback(window, &glfw_window_size_callback);
        _ = seizer.backend.glfw.c.glfwSetFramebufferSizeCallback(window, &glfw_framebuffer_size_callback);

        app.stage.needs_layout = true;

        return app;
    }

    pub fn destroy(app: *App) void {
        app.stage.destroy();

        app.tilemap.deinit(app.gpa);
        app.blocks_tileset.deinit();
        app.ui_tileset.deinit();

        app.canvas.deinit(app.gpa);
        seizer.backend.glfw.c.glfwDestroyWindow(app.window);
        app.gpa.destroy(app);
    }

    fn onStartGamePressed(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
        _ = button;
        const app: *App = @ptrCast(@alignCast(userdata.?));
        app.stage.setRoot(&app.setup_screen.element);
    }

    fn onScoresPressed(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
        _ = button;
        const app: *App = @ptrCast(@alignCast(userdata.?));
        _ = app;
    }

    fn onQuitPressed(userdata: ?*anyopaque, button: *seizer.ui.Button) void {
        _ = button;
        const app: *App = @ptrCast(@alignCast(userdata.?));

        seizer.backend.glfw.c.glfwSetWindowShouldClose(app.window, seizer.backend.glfw.c.GLFW_TRUE);
    }

    fn gotoMainMenu(userdata: ?*anyopaque, _: void) void {
        const app: *App = @ptrCast(@alignCast(userdata.?));
        app.stage.setRoot(app.main_menu);
    }
};

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
var gl_binding: gl.Binding = undefined;

pub fn main() !void {
    const gpa = general_purpose_allocator.allocator();

    // GLFW setup
    try seizer.backend.glfw.loadDynamicLibraries(gpa);

    _ = seizer.backend.glfw.c.glfwSetErrorCallback(&seizer.backend.glfw.defaultErrorCallback);

    const glfw_init_res = seizer.backend.glfw.c.glfwInit();
    if (glfw_init_res != 1) {
        std.debug.print("glfw init error: {}\n", .{glfw_init_res});
        std.process.exit(1);
    }
    defer seizer.backend.glfw.c.glfwTerminate();

    const app = try App.new(gpa);
    defer app.destroy();

    while (seizer.backend.glfw.c.glfwWindowShouldClose(app.window) != seizer.backend.glfw.c.GLFW_TRUE) {
        seizer.backend.glfw.c.glfwPollEvents();

        gl.clearColor(0.7, 0.5, 0.5, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        var window_size: [2]c_int = undefined;
        seizer.backend.glfw.c.glfwGetWindowSize(app.window, &window_size[0], &window_size[1]);

        var framebuffer_size: [2]c_int = undefined;
        seizer.backend.glfw.c.glfwGetFramebufferSize(app.window, &framebuffer_size[0], &framebuffer_size[1]);

        app.canvas.begin(.{
            .window_size = [2]f32{
                @floatFromInt(window_size[0]),
                @floatFromInt(window_size[1]),
            },
            .framebuffer_size = [2]f32{
                @floatFromInt(framebuffer_size[0]),
                @floatFromInt(framebuffer_size[1]),
            },
        });
        app.stage.render(&app.canvas, [2]f32{
            @floatFromInt(window_size[0]),
            @floatFromInt(window_size[1]),
        });
        app.canvas.end();

        seizer.backend.glfw.c.glfwSwapBuffers(app.window);
    }
}

fn glfw_key_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const app = @as(*App, @ptrCast(@alignCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));

    const key_event = seizer.ui.event.Key{
        .key = @enumFromInt(key),
        .scancode = scancode,
        .action = @enumFromInt(action),
        .mods = .{
            .shift = seizer.backend.glfw.c.GLFW_MOD_SHIFT == seizer.backend.glfw.c.GLFW_MOD_SHIFT & mods,
            .control = seizer.backend.glfw.c.GLFW_MOD_CONTROL == seizer.backend.glfw.c.GLFW_MOD_CONTROL & mods,
            .alt = seizer.backend.glfw.c.GLFW_MOD_ALT == seizer.backend.glfw.c.GLFW_MOD_ALT & mods,
            .super = seizer.backend.glfw.c.GLFW_MOD_SUPER == seizer.backend.glfw.c.GLFW_MOD_SUPER & mods,
            .caps_lock = seizer.backend.glfw.c.GLFW_MOD_CAPS_LOCK == seizer.backend.glfw.c.GLFW_MOD_CAPS_LOCK & mods,
            .num_lock = seizer.backend.glfw.c.GLFW_MOD_NUM_LOCK == seizer.backend.glfw.c.GLFW_MOD_NUM_LOCK & mods,
        },
    };

    if (app.stage.onKey(key_event)) {
        return;
    }
}

fn glfw_mousebutton_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = mods;
    const app = @as(*App, @ptrCast(@alignCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));

    check_ui: {
        var mouse_pos_f64: [2]f64 = undefined;
        seizer.backend.glfw.c.glfwGetCursorPos(window, &mouse_pos_f64[0], &mouse_pos_f64[1]);
        const mouse_pos = [2]f32{
            @floatCast(mouse_pos_f64[0]),
            @floatCast(mouse_pos_f64[1]),
        };

        const click_event = seizer.ui.event.Click{
            .pos = mouse_pos,
            .button = switch (button) {
                seizer.backend.glfw.c.GLFW_MOUSE_BUTTON_LEFT => .left,
                seizer.backend.glfw.c.GLFW_MOUSE_BUTTON_RIGHT => .right,
                seizer.backend.glfw.c.GLFW_MOUSE_BUTTON_MIDDLE => .middle,
                else => break :check_ui,
            },
            .pressed = action == seizer.backend.glfw.c.GLFW_PRESS,
        };

        if (app.stage.onClick(click_event)) {
            return;
        }
    }
}

fn glfw_cursor_pos_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const app = @as(*App, @ptrCast(@alignCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));

    const mouse_pos = [2]f32{ @floatCast(xpos), @floatCast(ypos) };

    if (app.stage.onHover(mouse_pos)) {
        return;
    }
}

fn glfw_scroll_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
    const app = @as(*App, @ptrCast(@alignCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));

    const scroll_event = seizer.ui.event.Scroll{
        .offset = [2]f32{
            @floatCast(xoffset),
            @floatCast(yoffset),
        },
    };

    if (app.stage.onScroll(scroll_event)) {
        return;
    }
}

fn glfw_char_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    const app = @as(*App, @alignCast(@ptrCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));

    var text_input_event = seizer.ui.event.TextInput{ .text = .{} };
    const codepoint_len = std.unicode.utf8Encode(@as(u21, @intCast(codepoint)), &text_input_event.text.buffer) catch return;
    text_input_event.text.resize(codepoint_len) catch unreachable;

    if (app.stage.onTextInput(text_input_event)) {
        return;
    }
}

fn glfw_window_size_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    const app = @as(*App, @alignCast(@ptrCast(seizer.backend.glfw.c.glfwGetWindowUserPointer(window))));
    _ = width;
    _ = height;
    app.stage.needs_layout = true;
}

fn glfw_framebuffer_size_callback(window: ?*seizer.backend.glfw.c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    gl.viewport(
        0,
        0,
        @intCast(width),
        @intCast(height),
    );
}

const util = @import("./util.zig");
const seizer = @import("seizer");
const gl = seizer.gl;
const std = @import("std");
