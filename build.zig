const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "opencv",
        .target = target,
        .optimize = optimize,
    });

    link(b, target, lib, false);

    const zigcv = b.addModule("zigcv", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    link(b, target, zigcv, true);

    const examples = [_]Program{
        .{
            .name = "hello",
            .path = "examples/hello/main.zig",
            .desc = "Show Webcam",
        },
        .{
            .name = "version",
            .path = "examples/version/main.zig",
            .desc = "Print OpenCV Version",
        },
        .{
            .name = "show_image",
            .path = "examples/showimage/main.zig",
            .desc = "Show Image Demo",
        },
        .{
            .name = "face_detection",
            .path = "examples/facedetect/main.zig",
            .desc = "Face Detection Demo",
        },
        .{
            .name = "face_blur",
            .path = "examples/faceblur/main.zig",
            .desc = "Face Detection and Blur Demo",
        },
        .{
            .name = "dnn_detection",
            .path = "examples/dnndetection/main.zig",
            .desc = "DNN Detection Demo",
        },
        .{
            .name = "saveimage",
            .path = "examples/saveimage/main.zig",
            .desc = "Save Image Demo",
        },
        .{
            .name = "detail_enhance",
            .path = "examples/detail_enhance/main.zig",
            .desc = "Detail Enhanced Image Demo",
        },
    };

    const examples_step = b.step("examples", "Run all the examples");

    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_source_file = b.path(ex.path),
            .target = target,
            .optimize = optimize,
        });

        link(b, target, exe, false);

        exe.root_module.addImport("zigcv", zigcv);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        var run_step = b.step(ex.name, ex.desc);
        run_step.dependOn(&run_cmd.step);

        examples_step.dependOn(run_step);
    }

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter") orelse null;
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .filter = test_filter,
    });
    link(b, target, unit_tests, false);
    unit_tests.root_module.addImport("zigcv", &lib.root_module);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&unit_tests.step);
}

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
    fstage1: bool = false,
};

inline fn link(b: *std.Build, target: std.Build.ResolvedTarget, exe: anytype, isModule: bool) void {
    const go_src = "libs/gocv/";
    const zig_src = "src/";

    switch (target.result.os.tag) {
        .windows => {
            exe.addIncludePath(b.path("c:/msys64/mingw64/include"));
            exe.addIncludePath(b.path("c:/msys64/mingw64/include/c++/12.2.0"));
            exe.addIncludePath(b.path("c:/msys64/mingw64/include/c++/12.2.0/x86_64-w64-mingw32"));
            exe.addLibraryPath(b.path("c:/msys64/mingw64/lib"));
            exe.addIncludePath(b.path("c:/opencv/build/install/include"));
            exe.addLibraryPath(b.path("c:/opencv/build/install/x64/mingw/staticlib"));

            if (isModule) exe.linkSystemLibrary("stdc++.dll", .{}) else exe.linkSystemLibrary("stdc++.dll");
        },
        else => {
            if (!isModule) exe.linkLibCpp();
        },
    }
    if (isModule) exe.linkSystemLibrary("opencv4", .{}) else exe.linkSystemLibrary("opencv4");
    if (isModule) exe.linkSystemLibrary("unwind", .{}) else exe.linkSystemLibrary("unwind");
    if (isModule) exe.linkSystemLibrary("m", .{}) else exe.linkSystemLibrary("unwind");
    if (isModule) exe.linkSystemLibrary("c", .{}) else exe.linkSystemLibrary("unwind");

    exe.addIncludePath(b.path(go_src));
    if (!isModule) exe.addCSourceFiles(.{
        .files = &.{ "asyncarray.cpp", "calib3d.cpp", "core.cpp", "dnn.cpp", "features2d.cpp", "highgui.cpp", "imgcodecs.cpp", "imgproc.cpp", "objdetect.cpp", "photo.cpp", "svd.cpp", "version.cpp", "video.cpp", "videoio.cpp" },
        .root = b.path(go_src),
    });

    exe.addIncludePath(b.path(zig_src));
}
