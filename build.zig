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

    const examples_step = b.step("run-examples", "Run all the examples");

    inline for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_source_file = b.path(ex.path),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("zigcv", zigcv_module);
        const exe_step = &exe.step;

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-" ++ ex.name, ex.desc);
        const artifact_step = &b.addInstallArtifact(exe, .{}).step;
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run_step.dependOn(artifact_step);
        run_step.dependOn(&run_cmd.step);
        examples_step.dependOn(exe_step);
        examples_step.dependOn(artifact_step);
        examples_step.dependOn(&run_cmd.step);
    }
}

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
    fstage1: bool = false,
};
