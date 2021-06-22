const std = @import("std");
const Builder = std.build.Builder;
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("blockstacker", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.linkLibC();

    const sdl_sdk_path_opt = b.option([]const u8, "sdl-sdk", "The path to the SDL2 sdk") orelse null;
    if (sdl_sdk_path_opt) |sdk_path| {
        exe.linkSystemLibraryName("SDL2");
        exe.addIncludeDir(b.fmt("{s}/include", .{sdk_path}));

        const lib_dir = b.fmt("{s}/lib", .{sdk_path});
        exe.addLibPath(lib_dir);
    } else {
        exe.linkSystemLibrary("SDL2");
    }

    deps.addAllTo(exe);

    const build_native_step = b.step("native", "Build for native");
    build_native_step.dependOn(&exe.step);

    // Install assets alongside binary
    const copy_assets = b.addInstallDirectory(.{
        .source_dir = "assets",
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    exe.step.dependOn(&copy_assets.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    {
        const web = b.addSharedLibrary("blockstacker", "src/main.zig", .unversioned);
        web.setBuildMode(mode);
        web.override_dest_dir = .bin;
        web.setTarget(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        });
        web.install();

        web.addPackage(deps.pkgs.seizer);
        web.addPackage(deps.pkgs.crossdb);
        web.addPackage(deps.pkgs.chrono);
        web.addPackage(deps.pkgs.zigimg);
        web.addPackage(deps.pkgs.proto_structs);

        // Generate JS file and copy it to install dir
        const install_js_exe = b.addExecutable("install_js", "tools/install_js.zig");
        deps.addAllTo(install_js_exe);
        const install_js = install_js_exe.run();
        install_js.addArg(b.getInstallPath(.bin, ""));

        const copy_www = b.addInstallDirectory(.{
            .source_dir = "www",
            .install_dir = .bin,
            .install_subdir = "",
        });

        const build_web = b.step("web", "Build WASM application");
        build_web.dependOn(&web.step);
        build_web.dependOn(&web.install_step.?.step);
        build_web.dependOn(&copy_assets.step);
        build_web.dependOn(&install_js.step);
        build_web.dependOn(&copy_www.step);
    }
}
