const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigcv_module = b.addModule("zigcv", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
        .link_libcpp = true,
    });
    zigcv_module.linkSystemLibrary("opencv4", .{});
    const dep_gocv = b.dependency("gocv", .{});
    zigcv_module.addCSourceFiles(.{
        .files = &.{ "asyncarray.cpp", "calib3d.cpp", "core.cpp", "dnn.cpp", "features2d.cpp", "highgui.cpp", "imgcodecs.cpp", "imgproc.cpp", "objdetect.cpp", "photo.cpp", "svd.cpp", "version.cpp", "video.cpp", "videoio.cpp" },
        .root = dep_gocv.path(""),
    });
    zigcv_module.addIncludePath(dep_gocv.path(""));

    const lib = b.addStaticLibrary(.{
        .name = "zigcv",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    lib.addIncludePath(dep_gocv.path(""));
    b.installArtifact(lib);
}
