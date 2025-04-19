const std = @import("std");

pub var make_step: ?std.Build.Step = undefined;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const bundle_opt = b.option(bool, "bundle", "Bundle OpenCV to your binary (default - MacOS/false Linux/true") orelse if (target.result.os.tag == .linux) true else false;
    const dnn_opt = b.option(bool, "dnn", "Build with dnn (default - true)") orelse true;

    const zigcv_module = b.addModule("zigcv", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
        .link_libcpp = true,
    });
    var zigcv_step = try makeCvModule(b, zigcv_module, target, .{ .dnn = dnn_opt, .bundle = bundle_opt });
    if (zigcv_step != null) b.default_step.dependOn(&zigcv_step.?);
    make_step = zigcv_step;

    const dep_gocv = b.dependency("gocv", .{});
    zigcv_module.addCSourceFiles(.{
        .files = &.{ "asyncarray.cpp", "calib3d.cpp", "core.cpp", "features2d.cpp", "highgui.cpp", "imgcodecs.cpp", "imgproc.cpp", "objdetect.cpp", "photo.cpp", "svd.cpp", "version.cpp", "video.cpp", "videoio.cpp", "contrib/facemarkLBF.cpp" },
        .root = dep_gocv.path(""),
    });
    if (dnn_opt) zigcv_module.addCSourceFiles(.{ .files = &.{"dnn.cpp"}, .root = dep_gocv.path("") });

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
            .name = "face_mark",
            .path = "examples/facemark/main.zig",
            .desc = "Face Landmarking Demo",
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

        if (zigcv_step != null) {
            exe.step.dependOn(&zigcv_step.?);
        }

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

pub fn makeCvModule(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget, opt: BuildOpt) !?std.Build.Step {
    var link_module_step: ?std.Build.Step = null;

    if (opt.bundle) {
        link_module_step = try makeCv(b, module, target, opt);
    } else {
        switch (target.result.os.tag) {
            .linux => {
                std.log.err("Builds on Linux requires bundling of an libc++ build of OpenCV\nFor more inforation, please see https://github.com/zig-nominated-compat/zigcv/issues/2\n", .{});
                std.process.exit(1);
            },
            else => {
                module.linkSystemLibrary("opencv4", .{});
            },
        }
    }

    return link_module_step;
}

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
};

const BuildOpt = struct { bundle: bool, dnn: bool };

fn makeCv(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget, options: BuildOpt) !?std.Build.Step {
    const opencv_dep = b.dependency("opencv", .{});
    const opencv_contrib_dep = b.dependency("opencv_contrib", .{});

    const cmake_bin = b.findProgram(&.{"cmake"}, &.{}) catch @panic("CMake is required for bundling OpenCV, please install CMake.\nFor more information on why bundling is happening, please see https://github.com/zig-nominated-compat/zigcv/issues/2");

    const configure_cmd = b.addSystemCommand(&.{ cmake_bin, "-B" });
    configure_cmd.setName("Configuring OpenCV build with cmake");
    const build_work_dir = configure_cmd.addOutputDirectoryArg("build_work");

    configure_cmd.addArgs(&.{
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
        "-DCMAKE_C_COMPILER='zig;cc'",
        "-DCMAKE_CXX_COMPILER='zig;c++'",
        "-DCMAKE_ASM_COMPILER='zig;cc'",
        "-DCMAKE_BUILD_TYPE=RELEASE",
        "-DCMAKE_EXE_LINKER_FLAGS=-std=c++11",
        "-D",
    });

    const opencv4_build_dir = configure_cmd.addPrefixedOutputDirectoryArg("CMAKE_INSTALL_PREFIX=", "zig_opencv4_build");
    configure_cmd.addArgs(&.{
        "-D",
    });
    configure_cmd.addPrefixedDirectoryArg("OPENCV_EXTRA_MODULES_PATH=", opencv_contrib_dep.path("modules"));
    if (!options.dnn) {
        configure_cmd.addArgs(&.{ "-D", "OPENCV_DNN_OPENCL=OFF" });
    }
    configure_cmd.addArgs(&.{
        "-DOPENCV_ENABLE_NONFREE=ON",
        "-DWITH_JASPER=OFF",
        // "-DWITH_TBB=OFF",
        "-DBUILD_DOCS=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_PERF_TESTS=OFF",
        "-DBUILD_opencv_java=OFF",
        "-DBUILD_opencv_python2=OFF",
        "-DBUILD_opencv_python3=OFF",
        "-DWITH_OPENEXR=OFF",
        "-DBUILD_OPENEXR=OFF",
        "-DBUILD_PNG=ON",
        "-DBUILD_JPEG=ON",
        "-DBUILD_TIFF=ON",
        "-DBUILD_WEBP=ON",
        "-DWITH_FFMPEG=ON",
        "-DWITH_GSTREAMER=OFF",
        "-DWITH_LIBV4L=ON",
        "-DWITH_OPENGL=ON",
        "-DENABLE_FAST_MATH=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DOPENCV_GENERATE_PKGCONFIG=OFF",
        "-Wno-dev",
    });
    if (target.result.os.tag == .linux) {
        configure_cmd.addArgs(&.{
            "-DWITH_V4L=ON",
        });
    }
    configure_cmd.addDirectoryArg(opencv_dep.path(""));
    configure_cmd.expectExitCode(0);

    const build_cmd = b.addSystemCommand(&.{ cmake_bin, "--build" });
    build_cmd.setName("Compiling OpenCV");
    build_cmd.addDirectoryArg(build_work_dir);
    var buf: [4]u8 = undefined;
    build_cmd.addArgs(&.{ "-j", try std.fmt.bufPrint(&buf, "{}", .{try std.Thread.getCpuCount()}) });
    build_cmd.step.dependOn(&configure_cmd.step);
    build_cmd.expectExitCode(0);

    const install_cmd = b.addSystemCommand(&.{ cmake_bin, "--install" });
    install_cmd.addDirectoryArg(build_work_dir);
    install_cmd.step.dependOn(&build_cmd.step);
    install_cmd.expectExitCode(0);

    const link_module = LinkModuleStep.create(b, module, opencv4_build_dir, target, options);
    link_module.step.dependOn(&install_cmd.step);

    b.default_step.dependOn(&link_module.step);

    return link_module.step;
}

const LinkModuleStep = struct {
    const Self = @This();

    var selfPtrInt: usize = 0;

    t: []const u8,
    step: std.Build.Step,
    owner: *std.Build,
    module: *std.Build.Module,
    dir: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    options: BuildOpt,

    pub fn create(owner: *std.Build, module: *std.Build.Module, dir: std.Build.LazyPath, target: std.Build.ResolvedTarget, options: BuildOpt) *Self {
        const self = owner.allocator.create(LinkModuleStep) catch unreachable;
        selfPtrInt = @intFromPtr(self);
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "Linking module to OpenCV",
                .owner = owner,
                .makeFn = make,
            }),
            .t = "yes",
            .owner = owner,
            .module = module,
            .dir = dir,
            .target = target,
            .options = options,
        };

        return self;
    }

    pub fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const b = step.owner;
        const self: *LinkModuleStep = @ptrFromInt(selfPtrInt);
        const m = self.module;
        const dir = self.dir;
        const target = self.target;
        const options = self.options;

        m.addIncludePath(dir.path(b, "include/opencv4"));

        inline for (&.{ "aruco", "bgsegm", "bioinspired", "calib3d", "ccalib", "core", "datasets", "dnn_objdetect", "dnn_superres", "dpm", "face", "features2d", "flann", "fuzzy", "gapi", "hfs", "highgui", "img_hash", "imgcodecs", "imgproc", "intensity_transform", "line_descriptor", "mcc", "ml", "objdetect", "optflow", "phase_unwrapping", "photo", "plot", "quality", "rapid", "reg", "rgbd", "saliency", "shape", "signal", "stereo", "stitching", "structured_light", "superres", "surface_matching", "text", "tracking", "video", "videoio" }) |lib_file| {
            m.addObjectFile(dir.path(b, "lib/libopencv_" ++ lib_file ++ ".a"));
        }

        if (options.dnn) m.addObjectFile(dir.path(b, "lib/libopencv_dnn.a"));

        //
        inline for (&.{ "ade", "ittnotify", "libopenjp2", "libprotobuf", "tegra_hal", "libjpeg-turbo", "libtiff", "libwebp", "libpng" }) |lib_file| {
            m.addObjectFile(dir.path(b, "lib/opencv4/3rdparty/lib" ++ lib_file ++ ".a"));
        }
        inline for (&.{ "avcodec", "avformat", "avutil", "swscale" }) |library_dep| {
            m.linkSystemLibrary(library_dep, .{});
        }

        switch (target.result.os.tag) {
            .macos => {
                inline for (&.{ "alphamat", "freetype", "hdf", "sfm" }) |lib_file| {
                    m.addObjectFile(dir.path(b, "lib/libopencv_" ++ lib_file ++ ".a"));
                }
                inline for (&.{ "openvino", "avif", "gstreamer-1.0", "gstreamer-sdp-1.0", "gstreamer-app-1.0", "gstreamer-video-1.0", "gstriff-1.0", "gstpbutils-1.0" }) |library_dep| {
                    m.linkSystemLibrary(library_dep, .{});
                }
                inline for (&.{ "opencv.sfm.correspondence", "opencv.sfm.multiview", "opencv.sfm.numeric", "opencv.sfm.simple_pipeline", "zlib" }) |lib_file| {
                    m.addObjectFile(dir.path(b, "lib/opencv4/3rdparty/lib" ++ lib_file ++ ".a"));
                }
                inline for (&.{ "OpenCL", "Cocoa", "Accelerate", "AVFoundation", "CoreMedia", "CoreVideo" }) |framework_dep| {
                    m.linkFramework(framework_dep, .{});
                }
            },
            .linux => {
                inline for (&.{"zlib"}) |library_dep| {
                    m.linkSystemLibrary(library_dep, .{});
                }
            },
            else => {},
        }
    }
};
